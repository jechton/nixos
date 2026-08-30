--!nonstrict
-- Phone Media panel: replaces noctalia's builtin control-center media tab.
-- That tab pairs now-playing info with a PipeWire spectrum visualizer, which
-- only reflects locally-rendered audio, staying blank for a KDE Connect
-- player since the phone plays through its own speaker, not this machine's
-- PipeWire graph. The plugin API exposes no spectrum data either, so
-- reproducing it here isn't an option, and it isn't wanted: this panel is a
-- plain now-playing card, art, title, progress, transport controls, and a
-- player switcher when more than one MPRIS player is active.
--
-- Player selection mirrors bar.luau: a playing KDE Connect player wins, then
-- any playing player, then a KDE Connect player with track metadata, then any
-- player with track metadata, unless the switcher has pinned a specific player.
--
--   panel.render(tree)       replace the panel's UI tree
--   panel.close()            ask the host to close this panel
--   panel.setWantsSecondTicks(bool)  call update() once a second while open
--
-- Also embeds a compact synced-lyrics section (see lyrics.luau), the same
-- lookup jeremiah/phone-media:lyrics uses, so the two agree on what's playing
-- and what line is current; "Full lyrics" opens that panel for more room.

local lyrics = require("./lyrics.luau")

-- ── settings ─────────────────────────────────────────────────────────────────

local SHOW_ALBUM_ART = noctalia.getConfig("show_album_art") ~= false
local ALBUM_ART_SIZE = tonumber(noctalia.getConfig("album_art_size")) or 160
local ALBUM_ART_RADIUS = math.min(tonumber(noctalia.getConfig("album_art_radius")) or 16, ALBUM_ART_SIZE / 2)
local HIDE_ARTIST = noctalia.getConfig("hide_artist") == true
local SHOW_ALBUM = noctalia.getConfig("show_album") ~= false
local SHOW_PROGRESS = noctalia.getConfig("show_progress") ~= false
local SHOW_TIME_LABELS = noctalia.getConfig("show_time_labels") ~= false
local SHOW_PLAYBACK_CONTROLS = noctalia.getConfig("show_playback_controls") ~= false
local SHOW_PLAYER_SWITCHER = noctalia.getConfig("show_player_switcher") ~= false
local SHOW_SOURCE_LABEL = noctalia.getConfig("show_source_label") ~= false
local SHOW_LYRICS = noctalia.getConfig("show_lyrics") ~= false
local SHOW_FULL_LYRICS_BUTTON = noctalia.getConfig("show_full_lyrics_button") ~= false
local LYRICS_CONTEXT_LINES = math.max(0, math.floor(tonumber(noctalia.getConfig("lyrics_context_lines")) or 1))
local LYRICS_OFFSET_MS = tonumber(noctalia.getConfig("lyrics_offset_ms")) or 0

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
  "{{album}}",
  "{{mpris:artUrl}}",
  "{{mpris:length}}",
}, SEP)

local dataDir = noctalia.pluginDataDir()

-- ── state ────────────────────────────────────────────────────────────────────

local isOpen = false
local current = nil -- { name, status, title, artist, album, art, lengthUs }
local players = {} -- rows from the last metadata refresh, for the switcher
local switcherRows = {} -- the subset actually shown in the switcher, index-aligned with it
local pinnedBusName = nil

local metadataInFlight = false
local positionInFlight = false

local artUrl = ""
local artPath = nil
local coverRevision = 0

local positionUs = 0
local positionAtMs = 0 -- noctalia.nowMs() when positionUs was last sampled
local seeking = false
local seekIdleTicks = 0
local pendingSeekUs = nil
local frameAccumMs = 0

local lyricsKey = ""
local lyricsFetchToken = 0
local lyricsLoading = false
local lyricsLines = nil
local lyricsSource = nil

local tick = 0

-- ── helpers ──────────────────────────────────────────────────────────────────

local function isKde(name)
  return name ~= nil and string.find(name, "kdeconnect", 1, true) ~= nil
end

local function formatTime(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local m = math.floor(seconds / 60)
  local s = seconds % 60
  return string.format("%d:%02d", m, s)
end

local function withCurrent(fn)
  if current ~= nil then
    fn(current.name)
  end
end

-- Position advances continuously; playerctl is only polled about once a second.
-- Extrapolate from the last sample with the wall clock so the progress bar and
-- (especially) the lyric highlight stay accurate between polls, even for tracks
-- with lines less than a second apart.
local function livePositionUs()
  if seeking and pendingSeekUs ~= nil then
    return pendingSeekUs
  end
  if current ~= nil and current.status == "Playing" and positionAtMs > 0 then
    return positionUs + math.max(0, noctalia.nowMs() - positionAtMs) * 1000
  end
  return positionUs
end

-- ── artwork (same download/cache path as bar.luau, separate cache files) ───

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
  local destination = dataDir .. "/panel-cover-" .. tostring(revision % 2) .. ".jpg"
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
  if pinnedBusName ~= nil then
    for _, r in ipairs(rows) do
      if r.name == pinnedBusName then
        return r
      end
    end
    pinnedBusName = nil -- the pinned player disappeared, fall back below
  end

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

-- ── lyrics ───────────────────────────────────────────────────────────────────

local function fetchLyricsForCurrent()
  if not SHOW_LYRICS or current == nil then
    return
  end
  lyricsFetchToken = lyricsFetchToken + 1
  local token = lyricsFetchToken
  lyricsLoading, lyricsLines, lyricsSource = true, nil, nil
  lyrics.fetchLyrics(current, function(lines, source)
    if token ~= lyricsFetchToken then
      return
    end
    lyricsLoading, lyricsLines, lyricsSource = false, lines, source
    render()
  end)
end

-- ── data refresh ─────────────────────────────────────────────────────────────

-- Position drives both the progress bar and the synced-lyrics highlight, so
-- poll it whenever either is shown, not just when the progress bar is on. The
-- bar needs a track length to scale against; the lyrics highlight does not.
local function refreshPosition()
  if seeking or positionInFlight or current == nil then
    return
  end
  local wantForProgress = SHOW_PROGRESS and (current.lengthUs or 0) > 0
  if not wantForProgress and not SHOW_LYRICS then
    return
  end
  positionInFlight = true
  local name = current.name
  noctalia.runAsync({ "playerctl", "--player=" .. name, "position" }, function(result)
    positionInFlight = false
    if result.exitCode ~= 0 or seeking or current == nil or current.name ~= name then
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
      current, players = nil, {}
      artUrl, artPath = "", nil
      lyricsKey, lyricsLoading, lyricsLines, lyricsSource = "", false, nil, nil
      render()
      return
    end

    local rows = {}
    for line in (result.stdout or ""):gmatch("[^\n]+") do
      local name, status, title, artist, album, art, lengthUs = line:match(
        "^(.-)"
          .. SEP
          .. "(.-)"
          .. SEP
          .. "(.-)"
          .. SEP
          .. "(.-)"
          .. SEP
          .. "(.-)"
          .. SEP
          .. "(.-)"
          .. SEP
          .. "(.*)$"
      )
      if name ~= nil then
        table.insert(rows, {
          name = name,
          status = status,
          title = (title ~= "" and title) or name,
          artist = artist or "",
          album = album or "",
          art = art or "",
          lengthUs = tonumber(lengthUs) or 0,
        })
      end
    end

    players = rows
    local chosen = pick(rows)
    if chosen == nil then
      current, positionUs = nil, 0
      artUrl, artPath = "", nil
      lyricsKey, lyricsLoading, lyricsLines, lyricsSource = "", false, nil, nil
      render()
      return
    end

    local trackChanged = current == nil or current.name ~= chosen.name or current.title ~= chosen.title
    current = chosen
    if trackChanged then
      positionUs, positionAtMs, seeking, pendingSeekUs = 0, noctalia.nowMs(), false, nil
    end
    updateArtwork(chosen.art)

    local key = SHOW_LYRICS and lyrics.trackKey(chosen) or ""
    if SHOW_LYRICS and key ~= lyricsKey then
      lyricsKey = key
      fetchLyricsForCurrent()
    end

    render()
  end)
end

-- ── seeking ──────────────────────────────────────────────────────────────────

local function commitSeek(valueSeconds)
  local target = math.floor(valueSeconds)
  withCurrent(function(name)
    noctalia.runAsync({ "playerctl", "--player=" .. name, "position", tostring(target) })
  end)
  positionUs, positionAtMs, seeking, pendingSeekUs = target * 1000000, noctalia.nowMs(), false, nil
  render()
end

-- ── rendering ────────────────────────────────────────────────────────────────

local function header()
  return ui.row({ align = "center", justify = "space_between", gap = 8 }, {
    ui.label({
      text = noctalia.tr("ui.now_playing"),
      fontSize = 16,
      fontWeight = "bold",
      color = "on_surface",
      flexGrow = 1,
    }),
    ui.button({ glyph = "close", variant = "ghost", onClick = "onCloseClicked" }),
  })
end

function render()
  if not isOpen then
    return
  end

  if current == nil then
    panel.render(ui.column({ flexGrow = 1, gap = 16, align = "stretch" }, {
      header(),
      ui.column({ flexGrow = 1, align = "center", justify = "center", gap = 8 }, {
        ui.glyph({ name = "music-off", size = 32, color = "on_surface_variant" }),
        ui.label({ text = noctalia.tr("ui.nothing_playing"), color = "on_surface_variant" }),
      }),
    }))
    return
  end

  local body = {}

  if SHOW_ALBUM_ART then
    local cover
    if artPath ~= nil and artPath ~= "" then
      cover = ui.image({
        path = artPath,
        width = ALBUM_ART_SIZE,
        height = ALBUM_ART_SIZE,
        radius = ALBUM_ART_RADIUS,
        fit = "cover",
      })
    else
      cover = ui.glyph({
        name = current.status == "Playing" and "disc-filled" or "music-off",
        size = math.min(ALBUM_ART_SIZE, 48),
        color = "on_surface_variant",
      })
    end
    body[#body + 1] = ui.row({ justify = "center" }, { cover })
  end

  local textLines = {
    ui.label({
      text = current.title,
      fontSize = 16,
      fontWeight = "bold",
      color = "on_surface",
      maxLines = 2,
      textAlign = "center",
    }),
  }
  -- Artist and album share one secondary line, both the same weight.
  local secondary = {}
  if not HIDE_ARTIST and current.artist ~= "" then
    secondary[#secondary + 1] = current.artist
  end
  if SHOW_ALBUM and current.album ~= "" then
    secondary[#secondary + 1] = current.album
  end
  if #secondary > 0 then
    textLines[#textLines + 1] = ui.label({
      text = table.concat(secondary, "  \u{2022}  "),
      fontSize = 12,
      color = "on_surface_variant",
      textAlign = "center",
    })
  end
  if SHOW_SOURCE_LABEL then
    textLines[#textLines + 1] = ui.label({
      text = isKde(current.name) and noctalia.tr("ui.via_phone") or (current.name or ""),
      fontSize = 11,
      color = "secondary",
      textAlign = "center",
    })
  end
  -- Title, seek bar, and transport controls form one block with tight internal
  -- spacing; the slider's own control height already pads it from its
  -- neighbours, so the scroll's 12px gap between them would read as too much.
  local nowPlaying = { ui.column({ gap = 4, align = "stretch" }, textLines) }

  if SHOW_PROGRESS and (current.lengthUs or 0) > 0 then
    local lengthSeconds = current.lengthUs / 1000000
    local displaySeconds = math.min(livePositionUs() / 1000000, lengthSeconds)
    local progressLines = {
      ui.slider({
        min = 0,
        max = lengthSeconds,
        step = 1,
        value = displaySeconds,
        onChange = "onSeekChange",
        onDragEnd = "onSeekEnd",
      }),
    }
    if SHOW_TIME_LABELS then
      progressLines[#progressLines + 1] = ui.row({ justify = "space_between" }, {
        ui.label({ text = formatTime(displaySeconds), fontSize = 11, color = "on_surface_variant" }),
        ui.label({ text = formatTime(lengthSeconds), fontSize = 11, color = "on_surface_variant" }),
      })
    end
    nowPlaying[#nowPlaying + 1] = ui.column({ gap = 2, align = "stretch" }, progressLines)
  end

  if SHOW_PLAYBACK_CONTROLS then
    nowPlaying[#nowPlaying + 1] = ui.row({ justify = "center", gap = 8 }, {
      ui.button({ glyph = "media-prev", variant = "ghost", onClick = "onPrevious" }),
      ui.button({
        glyph = current.status == "Playing" and "media-pause" or "media-play",
        variant = "primary",
        onClick = "onPlayPause",
      }),
      ui.button({ glyph = "media-next", variant = "ghost", onClick = "onNext" }),
    })
  end

  body[#body + 1] = ui.column({ gap = 4, align = "stretch" }, nowPlaying)

  if SHOW_LYRICS then
    local lyricsSection = {}
    if lyricsLoading then
      lyricsSection[1] = ui.label({
        text = noctalia.tr("ui.lyrics_loading"),
        fontSize = 12,
        color = "on_surface_variant",
        textAlign = "center",
      })
    elseif lyricsLines == nil then
      lyricsSection[1] = ui.label({
        text = noctalia.tr("ui.lyrics_not_found"),
        fontSize = 12,
        color = "on_surface_variant",
        textAlign = "center",
      })
    elseif lyricsSource ~= "synced" then
      lyricsSection[1] = ui.label({
        text = noctalia.tr("ui.lyrics_not_synced"),
        fontSize = 12,
        color = "on_surface_variant",
        textAlign = "center",
      })
    else
      local displayPositionMs = math.floor(livePositionUs() / 1000) + LYRICS_OFFSET_MS
      local activeIndex = lyrics.activeLineIndex(lyricsLines, displayPositionMs) or 0
      for i = activeIndex - LYRICS_CONTEXT_LINES, activeIndex + LYRICS_CONTEXT_LINES do
        local ln = lyricsLines[i]
        if ln ~= nil then
          local isCurrent = i == activeIndex
          lyricsSection[#lyricsSection + 1] = ui.label({
            text = ln.text,
            fontSize = isCurrent and 13 or 12,
            fontWeight = isCurrent and "bold" or "normal",
            color = isCurrent and "primary" or "on_surface_variant",
            textAlign = "center",
            maxLines = 2,
          })
        end
      end
    end
    if SHOW_FULL_LYRICS_BUTTON then
      lyricsSection[#lyricsSection + 1] = ui.row({ justify = "center" }, {
        ui.button({ text = noctalia.tr("ui.full_lyrics"), variant = "ghost", onClick = "onOpenLyricsPanel" }),
      })
    end
    body[#body + 1] = ui.column({ gap = 6, align = "stretch" }, lyricsSection)
  end

  -- Only offer players that actually have media, plus the current one, so the
  -- phone's idle MPRIS stubs don't each show up as a nameless "phone" entry.
  switcherRows = {}
  local kdeShown = 0
  for _, p in ipairs(players) do
    if hasMedia(p) or p.name == current.name then
      switcherRows[#switcherRows + 1] = p
      if isKde(p.name) then
        kdeShown = kdeShown + 1
      end
    end
  end

  if SHOW_PLAYER_SWITCHER and #switcherRows > 1 then
    -- Index 0 is "Auto" (follow pick()); indices 1.. map to switcherRows. The
    -- bullet marks whichever player is currently playing, in either mode.
    local options = { noctalia.tr("ui.auto") }
    local selectedIndex = 0
    for i, p in ipairs(switcherRows) do
      local label = isKde(p.name) and noctalia.tr("ui.via_phone") or p.name
      -- Several apps on the phone all report as "phone"; tell them apart by track.
      if isKde(p.name) and kdeShown > 1 and p.title ~= "" and p.title ~= p.name then
        label = label .. " - " .. p.title
      end
      if p.name == current.name then
        label = "\u{2022} " .. label
        if pinnedBusName ~= nil then
          selectedIndex = i
        end
      end
      options[i + 1] = label
    end
    body[#body + 1] = ui.select({ options = options, selectedIndex = selectedIndex, onChange = "onPlayerSelected" })
  end

  panel.render(ui.column({ flexGrow = 1, gap = 16, align = "stretch" }, {
    header(),
    ui.scroll({ flexGrow = 1, gap = 12, align = "stretch" }, body),
  }))
end

-- ── wiring ───────────────────────────────────────────────────────────────────

function onOpen(_context)
  isOpen = true
  panel.setWantsSecondTicks(true)
  -- Frame ticks let the seek bar and lyric highlight redraw between the
  -- once-a-second polls; render() itself is throttled in onFrameTick.
  panel.setNeedsFrameTick(true)
  refreshMetadata()
  render()
end

function onClose()
  isOpen = false
  panel.setWantsSecondTicks(false)
  panel.setNeedsFrameTick(false)
end

function onFrameTick(deltaMs)
  frameAccumMs = frameAccumMs + (tonumber(deltaMs) or 16)
  if frameAccumMs >= 100 then
    frameAccumMs = 0
    render()
  end
end

function update()
  tick = tick + 1
  -- Guard against a drag whose end event never arrives (pointer released off
  -- the slider): without this `seeking` would pin the bar and lyrics forever.
  if seeking then
    seekIdleTicks = seekIdleTicks + 1
    if seekIdleTicks >= 8 then
      seeking, pendingSeekUs, seekIdleTicks = false, nil, 0
    end
  end
  refreshPosition()
  if tick % 3 == 0 then
    refreshMetadata()
  end
end

function onCloseClicked()
  panel.close()
end

function onOpenLyricsPanel()
  -- panel-open, not togglePanel: this button should always open the full lyrics,
  -- never close it if it happens to be open already.
  noctalia.runAsync({ "noctalia", "msg", "panel-open", "jeremiah/phone-media:lyrics" })
end

function onSeekChange(value)
  value = tonumber(value) or 0
  local targetUs = math.floor(value * 1000000)
  -- The host pushes our own rendered value back into the slider on every redraw,
  -- which re-fires onChange. Ignore that echo so it neither starts a phantom
  -- seek nor (mid-drag) keeps resetting the stuck-drag watchdog in update().
  if seeking then
    if pendingSeekUs == nil or math.abs(targetUs - pendingSeekUs) < 500000 then
      return
    end
  elseif math.abs(value - livePositionUs() / 1000000) < 1.5 then
    return
  end
  seeking, seekIdleTicks = true, 0
  pendingSeekUs = targetUs
  render()
end

function onSeekEnd()
  if pendingSeekUs ~= nil then
    commitSeek(pendingSeekUs / 1000000)
  else
    seeking = false
    render()
  end
end

function onPlayPause()
  withCurrent(function(name)
    noctalia.runAsync({ "playerctl", "--player=" .. name, "play-pause" })
  end)
end

function onPrevious()
  withCurrent(function(name)
    noctalia.runAsync({ "playerctl", "--player=" .. name, "previous" })
  end)
end

function onNext()
  withCurrent(function(name)
    noctalia.runAsync({ "playerctl", "--player=" .. name, "next" })
  end)
end

function onPlayerSelected(index)
  local i = tonumber(index) or 0
  if i <= 0 then
    pinnedBusName = nil -- back to automatic selection
  else
    local chosen = switcherRows[i]
    if chosen ~= nil then
      pinnedBusName = chosen.name
    end
  end
  refreshMetadata()
end
