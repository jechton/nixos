--!nonstrict
-- Phone Media lyrics bar widget: a small "open the lyrics panel" bar icon,
-- optionally previewing the current synced line. Independent of bar.luau:
-- add both, either, or neither to the bar layout. Player selection and lyrics
-- lookup mirror lyrics_panel.luau exactly (via the shared lyrics.luau), so
-- whichever line shows here is the one the panel would center on too.

local lyrics = require("./lyrics.luau")

-- ── settings ─────────────────────────────────────────────────────────────────

local SHOW_CURRENT_LINE = noctalia.getConfig("show_current_line") ~= false
local MAX_LENGTH = tonumber(noctalia.getConfig("max_length")) or 220
local HIDE_WHEN_NO_LYRICS = noctalia.getConfig("hide_when_no_lyrics") ~= false
local LYRICS_OFFSET_MS = tonumber(noctalia.getConfig("lyrics_offset_ms")) or 0

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

local current = nil -- { name, status, title, artist, album, lengthUs }
local metadataInFlight = false
local positionInFlight = false
local positionUs = 0
local positionAtMs = 0 -- noctalia.nowMs() when positionUs was last sampled
local tick = 0

local lyricsKey = ""
local lyricsFetchToken = 0
local lyricsLoading = false
local lyricsLines = nil
local lyricsSource = nil
local currentLineText = ""

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
  lyricsLoading, lyricsLines, lyricsSource, currentLineText = true, nil, nil, ""
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

-- playerctl is polled about once a second; extrapolate with the wall clock so
-- the previewed line keeps up with fast, closely-spaced lyrics.
local function livePositionUs()
  if current ~= nil and current.status == "Playing" and positionAtMs > 0 then
    return positionUs + math.max(0, noctalia.nowMs() - positionAtMs) * 1000
  end
  return positionUs
end

local function refreshPosition()
  if not SHOW_CURRENT_LINE or positionInFlight or current == nil then
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

    if current == nil or current.name ~= chosen.name or current.title ~= chosen.title then
      positionUs, positionAtMs = 0, noctalia.nowMs()
    end
    current = chosen

    if not SHOW_CURRENT_LINE then
      render()
      return
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

local function glyph()
  return ui.glyph({ key = "glyph", name = "microphone-2", size = 16, color = "on_surface_variant" })
end

-- Builtin bar widgets carry a small inset; plugin widgets render flush unless
-- they add their own. Wrap every emit so this widget keeps a gap from its
-- neighbours without widening the bar-wide widget_spacing.
local WIDGET_PAD = 6

local function emit(node)
  local props = { key = "pad", align = "center" }
  if barWidget.isVertical() then
    props.paddingV = WIDGET_PAD
    barWidget.render(ui.column(props, { node }))
  else
    props.paddingH = WIDGET_PAD
    barWidget.render(ui.row(props, { node }))
  end
end

-- Hide the widget entirely (only honoured when hide_when_no_lyrics is set).
local function hideOrIdle()
  barWidget.setVisible(not HIDE_WHEN_NO_LYRICS)
  if not HIDE_WHEN_NO_LYRICS then
    emit(ui.glyph({ key = "idle", name = "music-off", size = 16, color = "on_surface_variant" }))
  end
end

function render()
  if not SHOW_CURRENT_LINE then
    -- Plain launcher icon: always visible regardless of playback state.
    barWidget.setVisible(true)
    emit(glyph())
    return
  end

  -- Nothing playing, or a track with no lyrics on file at all: hide.
  if current == nil or (not lyricsLoading and lyricsLines == nil) then
    hideOrIdle()
    return
  end

  -- Lyrics exist but aren't synced (or we're still looking): show just the
  -- icon, still clickable to open the full lyrics panel, no line preview.
  if lyricsLoading or lyricsSource ~= "synced" then
    barWidget.setVisible(true)
    emit(glyph())
    return
  end

  local displayPositionMs = math.floor(livePositionUs() / 1000) + LYRICS_OFFSET_MS
  local activeIndex = lyrics.activeLineIndex(lyricsLines, displayPositionMs)
  local line = activeIndex ~= nil and lyricsLines[activeIndex] or nil
  currentLineText = line ~= nil and line.text or ""

  barWidget.setVisible(true)
  emit(ui.row({ key = "content", gap = 6, align = "center" }, {
    glyph(),
    ui.label({
      key = "line",
      text = currentLineText ~= "" and currentLineText or noctalia.tr("ui.lyrics_waiting"),
      maxLines = 1,
      maxWidth = MAX_LENGTH,
      color = "on_surface",
    }),
  }))
end

-- ── wiring ───────────────────────────────────────────────────────────────────

function update()
  -- Redraw 4x a second (so the extrapolated line keeps up with fast lyrics) but
  -- only actually poll playerctl once a second.
  noctalia.setUpdateInterval(250)
  -- Icon-only mode needs no player data at all.
  if not SHOW_CURRENT_LINE then
    return
  end
  tick = tick + 1
  if tick % 4 == 0 then
    refreshPosition()
    refreshMetadata()
  else
    render()
  end
end

function onClick()
  noctalia.togglePanel("jeremiah/phone-media:lyrics")
end

if SHOW_CURRENT_LINE then
  refreshMetadata()
else
  render()
end
