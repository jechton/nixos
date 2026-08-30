--!nonstrict
-- Phone Media: a now-playing bar widget that replaces noctalia's builtin
-- `media` widget. It mirrors that widget's look, settings, and pointer
-- gestures, and additionally routes wheel/touchpad scroll to a volume control:
--   * active player is KDE Connect  -> the phone's volume (MPRIS Volume, which
--     kdeconnect proxies to the device)
--   * any other player              -> the laptop's own volume, same as the
--     builtin volume widget
--
-- The builtin media widget is compiled C++ with no scroll hook, and the plugin
-- API exposes no MPRIS state, so player data comes from `playerctl`:
--   * one `playerctl -a metadata` snapshot a second
--   * one `playerctl position` a second while show_progress is on; the bar
--     advances locally between those polls
--   * the marquee/redraw runs on the fast update tick
--
-- The widget renders no clickable elements of its own. Left opens this plugin's
-- panel; right/back/forward run playerctl directly (see plugin.toml
-- [widget.actions]) so they act on the phone rather than noctalia's idea of the
-- active player; scroll is handled here as a volume control.

-- ── settings ─────────────────────────────────────────────────────────────────

local HIDE_ARTIST = noctalia.getConfig("hide_artist") == true
local ARTIST_FIRST = noctalia.getConfig("artist_first") == true
local ALBUM_ART_ONLY = noctalia.getConfig("album_art_only") == true
local HIDE_ALBUM_ART = noctalia.getConfig("hide_album_art") == true
local SHOW_PROGRESS = noctalia.getConfig("show_progress") == true
local PROGRESS_ABOVE = noctalia.getConfig("progress_above") == true
local HIDE_WHEN_NO_MEDIA = noctalia.getConfig("hide_when_no_media") ~= false
local TITLE_SCROLL = noctalia.getConfig("title_scroll") or "on_hover"
local MAX_LENGTH = tonumber(noctalia.getConfig("max_length")) or 300
local ART_SIZE = tonumber(noctalia.getConfig("art_size")) or 16
-- Clamped to a circle; the default is intentionally huge so the art is round
-- unless the user dials it down.
local ART_RADIUS = math.min(tonumber(noctalia.getConfig("art_radius")) or 999, ART_SIZE / 2)

local PROGRESS_HEIGHT = 2
local ART_SLOT = (ALBUM_ART_ONLY or HIDE_ALBUM_ART) and 0 or (ART_SIZE + 6)
local TITLE_WIDTH = math.max(40, MAX_LENGTH - ART_SLOT)
local TITLE_CHARS = math.max(6, math.floor(TITLE_WIDTH / 7))

local MARQUEE_TICKS = 2
local METADATA_TICKS = 4
-- One playerctl position call a second; between them the bar advances locally
-- (see advanceProgress) so a moving progress bar costs no extra subprocesses.
local POSITION_TICKS = 4
local VOLUME_STEP = "0.05"

local SEP = string.char(31)
-- playerInstance, not playerName: KDE Connect reports every phone app as the
-- same playerName ("kdeconnect"), so a later `playerctl --player=kdeconnect`
-- (position, play-pause, volume) would hit an arbitrary one of them. The
-- instance name (kdeconnect.mpris_<id>) is unique per app.
local FORMAT = table.concat({
  "{{playerInstance}}",
  "{{status}}",
  "{{title}}",
  "{{artist}}",
  "{{mpris:artUrl}}",
  "{{mpris:length}}",
}, SEP)

local dataDir = noctalia.pluginDataDir()
-- Per-VM token so two of this widget (e.g. one bar per monitor) writing into the
-- shared plugin data dir don't clobber each other's cover cache files. The table
-- address is unique per Luau VM, unlike a time-seeded random which collides when
-- two widgets start in the same second.
local COVER_TAG = (tostring({}):match("0x0*(%x+)") or "0") .. ""

-- ── state ────────────────────────────────────────────────────────────────────

local current = nil -- { name, status, title, artist, art, lengthUs }
local hovered = false
local available = false
local requestInFlight = false
local positionInFlight = false

local marqueeOffset = 1
local tick = 0
local lastText = ""

local artUrl = ""
local artPath = nil
local coverRevision = 0
local progressFraction = 0

-- ── helpers ──────────────────────────────────────────────────────────────────

local function isKde(name)
  return name ~= nil and string.find(name, "kdeconnect", 1, true) ~= nil
end

local function displayText(row)
  if row == nil then
    return ""
  end
  if HIDE_ARTIST or row.artist == "" then
    return row.title
  end
  if ARTIST_FIRST then
    return row.artist .. " - " .. row.title
  end
  return row.title .. " - " .. row.artist
end

local function utf8Chars(value)
  local chars = {}
  for _, cp in utf8.codes(value) do
    table.insert(chars, utf8.char(cp))
  end
  return chars
end

-- Rotates `value` through the visible window one character at a time.
--   none      -> head, truncated with an ellipsis
--   always    -> always scrolling
--   on_hover  -> scrolls only while the pointer is over the widget
local function marquee(value)
  local chars = utf8Chars(value)
  if #chars <= TITLE_CHARS then
    return value
  end
  local scrolling = TITLE_SCROLL == "always" or (TITLE_SCROLL == "on_hover" and hovered)
  if not scrolling then
    return table.concat(chars, "", 1, TITLE_CHARS - 1) .. "\u{2026}"
  end
  local padded = utf8Chars(value .. "   ")
  local n = #padded
  local out = {}
  for i = 0, TITLE_CHARS - 1 do
    out[#out + 1] = padded[((marqueeOffset + i - 1) % n) + 1]
  end
  return table.concat(out)
end

-- ── artwork ──────────────────────────────────────────────────────────────────

local function updateArtwork(url)
  if url == nil or url == "" then
    artUrl, artPath = "", nil
    return
  end
  if url == artUrl then
    return
  end
  artUrl = url

  if string.sub(url, 1, 7) == "file://" then
    artPath = noctalia.string.urlDecode(string.sub(url, 8))
    return
  end
  if not string.match(url, "^https?://") or dataDir == nil then
    artPath = nil
    return
  end

  coverRevision = coverRevision + 1
  local revision = coverRevision
  local destination = dataDir .. "/cover-" .. COVER_TAG .. "-" .. tostring(revision % 2) .. ".jpg"
  noctalia.download(url, destination, function(ok)
    if ok and revision == coverRevision then
      artPath = destination
      render()
    end
  end)
end

-- ── player selection ─────────────────────────────────────────────────────────

-- KDE Connect leaves an MPRIS player on the bus for every media-capable app on
-- the phone, whether or not it has anything queued. Those idle players report
-- Paused/Stopped with no title, so a real "now playing" needs either active
-- playback or actual track metadata.
local function hasMedia(row)
  return row.status == "Playing" or (row.title ~= "" and row.title ~= row.name)
end

local function pick(rows)
  local kdePlaying, playing, kdeMedia, anyMedia
  for _, r in ipairs(rows) do
    if r.status == "Playing" then
      playing = playing or r
      if isKde(r.name) then
        kdePlaying = kdePlaying or r
      end
    end
    if hasMedia(r) then
      anyMedia = anyMedia or r
      if isKde(r.name) then
        kdeMedia = kdeMedia or r
      end
    end
  end
  return kdePlaying or playing or kdeMedia or anyMedia
end

local function refreshPosition()
  if not SHOW_PROGRESS or positionInFlight or current == nil or (current.lengthUs or 0) <= 0 then
    return
  end
  positionInFlight = true
  local name = current.name
  noctalia.runAsync({ "playerctl", "--player=" .. name, "position" }, function(result)
    positionInFlight = false
    if result.exitCode ~= 0 or current == nil or current.name ~= name then
      return
    end
    local seconds = tonumber((result.stdout or ""):match("[%d%.]+"))
    if seconds == nil then
      return
    end
    local fraction = seconds / (current.lengthUs / 1000000)
    progressFraction = math.max(0, math.min(1, fraction))
    render()
  end)
end

-- Nudge the bar forward between position polls so it moves at frame rate
-- without a playerctl call each tick.
local function advanceProgress()
  if not SHOW_PROGRESS or current == nil or current.status ~= "Playing" or (current.lengthUs or 0) <= 0 then
    return
  end
  local perTick = 0.25 / (current.lengthUs / 1000000)
  progressFraction = math.min(1, progressFraction + perTick)
  render()
end

local function refreshMetadata()
  if requestInFlight then
    return
  end
  requestInFlight = true

  noctalia.runAsync({ "playerctl", "-a", "metadata", "--format", FORMAT }, function(result)
    requestInFlight = false

    if result.exitCode ~= 0 then
      current, available = nil, false
      artUrl, artPath, progressFraction = "", nil, 0
      barWidget.setVisible(not HIDE_WHEN_NO_MEDIA)
      render()
      return
    end

    local rows = {}
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local name, status, title, artist, art, lengthUs = line:match(
        "^(.-)" .. SEP .. "(.-)" .. SEP .. "(.-)" .. SEP .. "(.-)" .. SEP .. "(.-)" .. SEP .. "(.*)$"
      )
      if name ~= nil then
        table.insert(rows, {
          name = name,
          status = status,
          title = (title ~= "" and title) or name,
          artist = artist or "",
          art = art or "",
          lengthUs = tonumber(lengthUs) or 0,
        })
      end
    end

    local chosen = pick(rows)
    if chosen == nil then
      current, available, progressFraction = nil, false, 0
      barWidget.setVisible(not HIDE_WHEN_NO_MEDIA)
      render()
      return
    end

    local trackChanged = current == nil or current.name ~= chosen.name or current.title ~= chosen.title
    available = true
    current = chosen
    if trackChanged then
      progressFraction = 0
    end
    barWidget.setVisible(true)
    updateArtwork(chosen.art)
    render()
  end)
end

-- ── rendering ────────────────────────────────────────────────────────────────

-- Builtin bar widgets carry a small horizontal inset; plugin widgets render
-- flush unless they add their own. Wrap every emit so this widget keeps a gap
-- from its neighbours without widening the bar-wide widget_spacing.
local WIDGET_PAD_H = 6

local function emit(node, stretch)
  local props = { key = "pad", align = stretch and "stretch" or "center" }
  if barWidget.isVertical() then
    props.paddingV = WIDGET_PAD_H
    barWidget.render(ui.column(props, { node }))
  else
    props.paddingH = WIDGET_PAD_H
    barWidget.render(ui.row(props, { node }))
  end
end

-- Nothing here registers an onClick, so left/right/back/forward fall through to
-- plugin.toml [widget.actions] (left opens this plugin's panel, the rest run
-- playerctl); scroll is handled by onScroll below.
function render()
  if not available or current == nil then
    if not HIDE_WHEN_NO_MEDIA then
      emit(ui.glyph({ key = "idle", name = "disc-filled", size = 16, color = "on_surface_variant" }))
    end
    return
  end

  local playing = current.status == "Playing"
  local vertical = barWidget.isVertical()

  local cover
  if not HIDE_ALBUM_ART then
    if artPath ~= nil and artPath ~= "" then
      cover = ui.image({
        key = "cover",
        path = artPath,
        width = ART_SIZE,
        height = ART_SIZE,
        radius = ART_RADIUS,
        fit = "cover",
      })
    else
      cover = ui.glyph({
        key = "cover-glyph",
        name = playing and "disc-filled" or "music-off",
        size = math.min(ART_SIZE, 18),
        color = "on_surface_variant",
      })
    end
  end

  if ALBUM_ART_ONLY or vertical then
    emit(cover or ui.glyph({ key = "cover-glyph", name = "disc-filled", size = 16, color = "on_surface_variant" }))
    return
  end

  local children = {}
  if cover ~= nil then
    children[#children + 1] = cover
  end
  children[#children + 1] = ui.label({
    key = "title",
    text = marquee(displayText(current)),
    maxLines = 1,
    maxWidth = TITLE_WIDTH,
    color = playing and "on_surface" or "on_surface_variant",
  })

  local row = ui.row({ key = "content", gap = 6, align = "center" }, children)

  if SHOW_PROGRESS and (current.lengthUs or 0) > 0 then
    -- width = 0: ui.progress and ui.spacer are bare nodes that measure at their
    -- last laid-out size, so in a stretch column they would ratchet the widget
    -- wider on every longer title and never shrink back. Zeroing their measured
    -- width lets the title row alone set the column width; align = "stretch"
    -- still paints the bar across that full width.
    local progress = ui.progress({
      key = "progress",
      progress = progressFraction,
      width = 0,
      height = PROGRESS_HEIGHT,
      radius = 1,
      fill = "primary",
    })
    -- Balance the progress bar with an equal spacer on the row's other edge, so
    -- toggling the setting keeps the text vertically centered instead of shifting.
    local balance = ui.spacer({ key = "progress-balance", width = 0, height = PROGRESS_HEIGHT })
    local stack = PROGRESS_ABOVE and { progress, row, balance } or { balance, row, progress }
    emit(ui.column({ key = "root", gap = 0, align = "stretch" }, stack), true)
  else
    emit(row)
  end
end

-- ── wiring ───────────────────────────────────────────────────────────────────

function update()
  noctalia.setUpdateInterval(250)
  tick = tick + 1

  local text = displayText(current)
  if text ~= lastText then
    lastText, marqueeOffset, tick = text, 1, 0
    render()
  elseif (TITLE_SCROLL == "always" or (TITLE_SCROLL == "on_hover" and hovered)) and tick % MARQUEE_TICKS == 0 then
    marqueeOffset = marqueeOffset + 1
    render()
  end

  if tick % METADATA_TICKS == 0 then
    refreshMetadata()
  end
  if tick % POSITION_TICKS == 0 then
    refreshPosition()
  else
    advanceProgress()
  end
end

function onHover(entered)
  hovered = entered == true
  if not hovered then
    marqueeOffset = 1
  end
  render()
end

-- BTN_RIGHT stays with this widget (plugin.toml binds only left/back/forward),
-- so play-pause can target the exact player the widget is showing.
function onRightClick()
  local name = current ~= nil and current.name or "kdeconnect,%any"
  noctalia.runAsync({ "playerctl", "--player=" .. name, "play-pause" })
end

function onScroll(axis, steps)
  if axis ~= "vertical" or steps == 0 then
    return
  end
  if current ~= nil and isKde(current.name) then
    local delta = steps > 0 and (VOLUME_STEP .. "-") or (VOLUME_STEP .. "+")
    noctalia.runAsync({ "playerctl", "--player=" .. current.name, "volume", delta })
  else
    noctalia.runAsync({ "noctalia", "msg", steps > 0 and "volume-down" or "volume-up" })
  end
end

refreshMetadata()
