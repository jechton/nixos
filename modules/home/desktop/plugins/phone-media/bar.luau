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
--   * one `playerctl -a metadata` snapshot per metadata tick
--   * an extra `playerctl position` per tick only while show_progress is on
--   * the marquee/redraw runs on the fast update tick
--
-- The widget renders no clickable elements of its own, so every pointer gesture
-- (left = open control-center media, right = play/pause, back/forward = skip)
-- goes to noctalia's dispatcher via plugin.toml [widget.actions], identical to
-- the builtin media widget. Only scroll is handled here.

-- ── settings ─────────────────────────────────────────────────────────────────

local HIDE_ARTIST = noctalia.getConfig("hide_artist") == true
local ARTIST_FIRST = noctalia.getConfig("artist_first") == true
local ALBUM_ART_ONLY = noctalia.getConfig("album_art_only") == true
local HIDE_ALBUM_ART = noctalia.getConfig("hide_album_art") == true
local SHOW_PROGRESS = noctalia.getConfig("show_progress") == true
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
local VOLUME_STEP = "0.05"

local SEP = string.char(31)
local FORMAT = table.concat({
  "{{playerName}}",
  "{{status}}",
  "{{title}}",
  "{{artist}}",
  "{{mpris:artUrl}}",
  "{{mpris:length}}",
}, SEP)

local dataDir = noctalia.pluginDataDir()

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
  local destination = dataDir .. "/cover-" .. tostring(revision % 2) .. ".jpg"
  noctalia.download(url, destination, function(ok)
    if ok and revision == coverRevision then
      artPath = destination
      render()
    end
  end)
end

-- ── player selection ─────────────────────────────────────────────────────────

local function pick(rows)
  local kdePlaying, playing, kde, first
  for _, r in ipairs(rows) do
    first = first or r
    if r.status == "Playing" then
      playing = playing or r
      if isKde(r.name) then
        kdePlaying = kdePlaying or r
      end
    end
    if isKde(r.name) then
      kde = kde or r
    end
  end
  return kdePlaying or playing or kde or first
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

    available = true
    current = chosen
    barWidget.setVisible(true)
    updateArtwork(chosen.art)
    render()
  end)
end

-- ── rendering ────────────────────────────────────────────────────────────────

-- Nothing here registers an onClick, so left/right/back/forward/scroll all fall
-- through to the gesture dispatcher (plugin.toml [widget.actions] + onScroll),
-- exactly like the builtin media widget: left opens control-center media.
function render()
  if not available or current == nil then
    if not HIDE_WHEN_NO_MEDIA then
      barWidget.render(ui.glyph({ key = "idle", name = "disc-filled", size = 16, color = "on_surface_variant" }))
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
    barWidget.render(cover or ui.glyph({ key = "cover-glyph", name = "disc-filled", size = 16, color = "on_surface_variant" }))
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
    -- Balance the progress bar with an equal spacer above the row, so toggling
    -- the setting keeps the text vertically centered instead of nudging it up.
    barWidget.render(ui.column({ key = "root", gap = 0, align = "stretch" }, {
      ui.spacer({ key = "progress-balance", height = PROGRESS_HEIGHT }),
      row,
      ui.progress({
        key = "progress",
        progress = progressFraction,
        height = PROGRESS_HEIGHT,
        radius = 1,
        fill = "primary",
      }),
    }))
  else
    barWidget.render(row)
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
  refreshPosition()
end

function onHover(entered)
  hovered = entered == true
  if not hovered then
    marqueeOffset = 1
  end
  render()
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
