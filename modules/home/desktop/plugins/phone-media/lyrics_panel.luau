--!nonstrict
-- Phone Media lyrics panel: a standalone, full-size synced-lyrics view. Tracks
-- the same player the bar widget and now-playing panel prefer (a playing KDE
-- Connect player wins, then any playing player, then a KDE Connect player with
-- media, then any player with media), fetches lyrics for it via the shared
-- lrclib lookup in lyrics.luau, and renders every line in a scrollable list
-- with the current one highlighted. The panel UI has no scroll-to-line
-- primitive, so the list does not auto-follow playback; scroll it by hand.

local lyrics = require("./lyrics.luau")

-- ── settings ─────────────────────────────────────────────────────────────────

local SHOW_TRACK_INFO = noctalia.getConfig("show_track_info") ~= false
local TEXT_ALIGN = noctalia.getConfig("text_align") or "center"
local LYRICS_OFFSET_MS = tonumber(noctalia.getConfig("lyrics_offset_ms")) or 0

local CURRENT_LINE_FONT_SIZE = 18
local OTHER_LINE_FONT_SIZE = 15

local SEP = string.char(31)
-- playerInstance, not playerName: KDE Connect reports every phone app as the
-- same playerName ("kdeconnect"), so a later `playerctl --player=kdeconnect
-- position` would hit an arbitrary one of them. The instance name
-- (kdeconnect.mpris_<id>) is unique per app.
local FORMAT = table.concat({
  "{{playerInstance}}",
  "{{status}}",
  "{{title}}",
  "{{artist}}",
  "{{album}}",
  "{{mpris:length}}",
}, SEP)

-- ── state ────────────────────────────────────────────────────────────────────

local isOpen = false
local current = nil -- { name, status, title, artist, album, lengthUs }
local metadataInFlight = false
local positionInFlight = false

local positionUs = 0
local positionAtMs = 0 -- noctalia.nowMs() when positionUs was last sampled
local frameAccumMs = 0
local tick = 0

local lyricsKey = ""
local lyricsFetchToken = 0
local lyricsLoading = false
local lyricsLines = nil
local lyricsSource = nil

-- ── helpers ──────────────────────────────────────────────────────────────────

local function isKde(name)
  return name ~= nil and string.find(name, "kdeconnect", 1, true) ~= nil
end

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

-- ── lyrics fetch ─────────────────────────────────────────────────────────────

local function fetchLyricsForCurrent()
  if current == nil then
    return
  end
  lyricsFetchToken = lyricsFetchToken + 1
  local token = lyricsFetchToken
  lyricsLoading, lyricsLines, lyricsSource = true, nil, nil
  render()
  lyrics.fetchLyrics(current, function(lines, source)
    if token ~= lyricsFetchToken then
      return
    end
    lyricsLoading, lyricsLines, lyricsSource = false, lines, source
    render()
  end)
end

-- ── data refresh ─────────────────────────────────────────────────────────────

-- Position is polled about once a second; extrapolate from the last sample with
-- the wall clock so the highlight tracks lines that are less than a second
-- apart instead of jumping several at once.
local function livePositionUs()
  if current ~= nil and current.status == "Playing" and positionAtMs > 0 then
    return positionUs + math.max(0, noctalia.nowMs() - positionAtMs) * 1000
  end
  return positionUs
end

-- The highlight only needs a playback position, not a track length, so this
-- keeps polling even when a KDE Connect player omits mpris:length.
local function refreshPosition()
  if positionInFlight or current == nil then
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
    positionUs = math.floor(seconds * 1000000)
    positionAtMs = noctalia.nowMs()
    render()
  end)
end

local function refreshMetadata()
  if metadataInFlight then
    return
  end
  metadataInFlight = true

  noctalia.runAsync({ "playerctl", "-a", "metadata", "--format", FORMAT }, function(result)
    metadataInFlight = false

    if result.exitCode ~= 0 then
      current, positionUs = nil, 0
      lyricsKey, lyricsLoading, lyricsLines, lyricsSource = "", false, nil, nil
      render()
      return
    end

    local rows = {}
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local name, status, title, artist, album, lengthUs =
        line:match("^(.-)" .. SEP .. "(.-)" .. SEP .. "(.-)" .. SEP .. "(.-)" .. SEP .. "(.-)" .. SEP .. "(.*)$")
      if name ~= nil then
        table.insert(rows, {
          name = name,
          status = status,
          title = (title ~= "" and title) or name,
          artist = artist or "",
          album = album or "",
          lengthUs = tonumber(lengthUs) or 0,
        })
      end
    end

    local chosen = pick(rows)
    if chosen == nil then
      current, positionUs = nil, 0
      lyricsKey, lyricsLoading, lyricsLines, lyricsSource = "", false, nil, nil
      render()
      return
    end

    local trackChanged = current == nil or current.name ~= chosen.name or current.title ~= chosen.title
    current = chosen
    if trackChanged then
      positionUs, positionAtMs = 0, noctalia.nowMs()
    end

    local key = lyrics.trackKey(chosen)
    if key ~= lyricsKey then
      lyricsKey = key
      fetchLyricsForCurrent()
    else
      render()
    end
  end)
end

-- ── rendering ────────────────────────────────────────────────────────────────

local function header()
  return ui.row({ align = "center", justify = "space_between", gap = 8 }, {
    ui.label({
      text = noctalia.tr("ui.lyrics"),
      fontSize = 16,
      fontWeight = "bold",
      color = "on_surface",
      flexGrow = 1,
    }),
    ui.button({ glyph = "refresh", variant = "ghost", onClick = "onRefetch" }),
    ui.button({ glyph = "close", variant = "ghost", onClick = "onCloseClicked" }),
  })
end

local function emptyState(glyph, text)
  return ui.column({ flexGrow = 1, align = "center", justify = "center", gap = 8 }, {
    ui.glyph({ name = glyph, size = 32, color = "on_surface_variant" }),
    ui.label({ text = text, color = "on_surface_variant", textAlign = "center" }),
  })
end

function render()
  if not isOpen then
    return
  end

  if current == nil then
    panel.render(ui.column({ flexGrow = 1, gap = 16, align = "stretch" }, {
      header(),
      emptyState("music-off", noctalia.tr("ui.nothing_playing")),
    }))
    return
  end

  local body = {}

  if SHOW_TRACK_INFO then
    local label = current.artist ~= "" and (current.title .. " - " .. current.artist) or current.title
    body[#body + 1] = ui.label({ text = label, fontSize = 12, color = "on_surface_variant", textAlign = "center" })
  end

  if lyricsLoading then
    body[#body + 1] = emptyState("clock", noctalia.tr("ui.lyrics_loading"))
  elseif lyricsLines == nil then
    body[#body + 1] = emptyState("music-off", noctalia.tr("ui.lyrics_not_found"))
  else
    -- Every line, scrollable. For synced lyrics the line whose timestamp has
    -- most recently passed is highlighted; plain lyrics report timeMs -1, so
    -- activeLineIndex returns nil and nothing is highlighted.
    local activeIndex = nil
    if lyricsSource == "synced" then
      activeIndex = lyrics.activeLineIndex(lyricsLines, math.floor(livePositionUs() / 1000) + LYRICS_OFFSET_MS)
    end
    local rendered = {}
    for i, line in ipairs(lyricsLines) do
      local isCurrent = i == activeIndex
      rendered[#rendered + 1] = ui.label({
        text = line.text,
        fontSize = isCurrent and CURRENT_LINE_FONT_SIZE or OTHER_LINE_FONT_SIZE,
        fontWeight = isCurrent and "bold" or "normal",
        color = isCurrent and "primary" or "on_surface_variant",
        textAlign = TEXT_ALIGN,
      })
    end
    body[#body + 1] = ui.scroll({ key = "lyrics", flexGrow = 1, gap = 8, align = "stretch" }, rendered)
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    header(),
    ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, body),
  }))
end

-- ── wiring ───────────────────────────────────────────────────────────────────

function onOpen(_context)
  isOpen = true
  panel.setWantsSecondTicks(true)
  -- Frame ticks redraw the highlight between the once-a-second polls; render()
  -- is throttled in onFrameTick.
  panel.setNeedsFrameTick(true)
  refreshMetadata()
  render()
end

function onClose()
  isOpen = false
  panel.setWantsSecondTicks(false)
  panel.setNeedsFrameTick(false)
end

function update()
  tick = tick + 1
  refreshPosition()
  if tick % 3 == 0 then
    refreshMetadata()
  end
end

function onFrameTick(deltaMs)
  frameAccumMs = frameAccumMs + (tonumber(deltaMs) or 16)
  if frameAccumMs >= 100 then
    frameAccumMs = 0
    render()
  end
end

function onCloseClicked()
  panel.close()
end

function onRefetch()
  lyricsKey = ""
  refreshMetadata()
end
