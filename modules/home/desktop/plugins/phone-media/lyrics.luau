--!nonstrict
-- Shared synced-lyrics logic for jeremiah/phone-media: LRC parsing, active-line
-- lookup, and fetching from lrclib.net (free, no API key, matches by title/
-- artist/album/duration). Used by lyrics_bar.luau, lyrics_panel.luau, and the
-- lyrics section embedded in panel.luau, so all three agree on what counts as
-- a match and how a timestamp maps to a line. Needs plugin_api >= 22, where
-- require() arrived.

local M = {}

local BASE_URL = "https://lrclib.net/api"
local HEADERS = { "User-Agent: noctalia-phone-media-plugin (https://github.com/jechton/nixos)" }

-- Parses `[mm:ss.xx]lyric text` lines into a time-sorted array of
-- { timeMs, text }. A line may carry more than one timestamp (a repeated
-- chorus), which expands to one entry per timestamp. Returns nil if nothing
-- parsed, so callers can fall back to plain (unsynced) lyrics.
function M.parseLRC(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local lines = {}
  for rawLine in text:gmatch("[^\r\n]+") do
    local times = {}
    for mins, secs in rawLine:gmatch("%[(%d+):(%d+%.?%d*)%]") do
      times[#times + 1] = math.floor(tonumber(mins) * 60000 + tonumber(secs) * 1000 + 0.5)
    end
    if #times > 0 then
      local lyricText = rawLine:gsub("%[%d+:%d+%.?%d*%]", ""):match("^%s*(.-)%s*$")
      if lyricText ~= "" then
        for _, timeMs in ipairs(times) do
          lines[#lines + 1] = { timeMs = timeMs, text = lyricText }
        end
      end
    end
  end
  if #lines == 0 then
    return nil
  end
  table.sort(lines, function(a, b)
    return a.timeMs < b.timeMs
  end)
  return lines
end

-- Splits plain, unsynced lyrics into display lines. timeMs is -1 throughout:
-- callers treat that as "no line is more current than any other".
local function parsePlain(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local lines = {}
  for rawLine in text:gmatch("[^\r\n]+") do
    local trimmed = rawLine:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      lines[#lines + 1] = { timeMs = -1, text = trimmed }
    end
  end
  if #lines == 0 then
    return nil
  end
  return lines
end

-- Index of the last line whose timestamp has passed, or nil if lines is nil,
-- empty, or unsynced (every timeMs is -1).
function M.activeLineIndex(lines, positionMs)
  if lines == nil then
    return nil
  end
  local index = nil
  for i, line in ipairs(lines) do
    if line.timeMs >= 0 and line.timeMs <= positionMs then
      index = i
    elseif line.timeMs >= 0 then
      break
    end
  end
  return index
end

-- Stable key for "is this still the same track", so consumers can skip
-- refetching when playerctl reports the same metadata again.
function M.trackKey(track)
  if track == nil then
    return ""
  end
  local durationSeconds = math.floor((track.lengthUs or 0) / 1000000)
  return (track.title or "") .. "\30" .. (track.artist or "") .. "\30" .. (track.album or "") .. "\30" .. tostring(
    durationSeconds
  )
end

local function extractLines(entry)
  if type(entry) ~= "table" then
    return nil, nil
  end
  local synced = M.parseLRC(entry.syncedLyrics)
  if synced ~= nil then
    return synced, "synced"
  end
  local plain = parsePlain(entry.plainLyrics)
  if plain ~= nil then
    return plain, "plain"
  end
  return nil, nil
end

local function statusOk(res)
  return res ~= nil and res.ok == true and res.status ~= nil and res.status >= 200 and res.status < 300
end

local function searchFallback(track, callback)
  local query = "track_name=" .. noctalia.string.urlEncode(track.title) .. "&artist_name=" .. noctalia.string.urlEncode(
    track.artist or ""
  )
  local started = noctalia.http({ url = BASE_URL .. "/search?" .. query, headers = HEADERS }, function(res)
    if not statusOk(res) or res.body == nil or res.body == "" then
      callback(nil, nil)
      return
    end
    local data = noctalia.json.decode(res.body)
    if type(data) ~= "table" or data[1] == nil then
      callback(nil, nil)
      return
    end
    local lines, source = extractLines(data[1])
    callback(lines, source)
  end)
  if not started then
    callback(nil, nil)
  end
end

-- track = { title, artist, album, lengthUs }. callback(lines_or_nil, source)
-- where source is "synced", "plain", or nil when nothing was found.
function M.fetchLyrics(track, callback)
  if track == nil or track.title == nil or track.title == "" then
    callback(nil, nil)
    return
  end

  local query = "track_name=" .. noctalia.string.urlEncode(track.title) .. "&artist_name=" .. noctalia.string.urlEncode(
    track.artist or ""
  )
  if track.album ~= nil and track.album ~= "" then
    query = query .. "&album_name=" .. noctalia.string.urlEncode(track.album)
  end
  local durationSeconds = math.floor((track.lengthUs or 0) / 1000000)
  if durationSeconds > 0 then
    query = query .. "&duration=" .. tostring(durationSeconds)
  end

  local started = noctalia.http({ url = BASE_URL .. "/get?" .. query, headers = HEADERS }, function(res)
    if statusOk(res) and res.body ~= nil and res.body ~= "" then
      local data = noctalia.json.decode(res.body)
      local lines, source = extractLines(data)
      if lines ~= nil then
        callback(lines, source)
        return
      end
    end
    -- No exact match (404) or an exact match with no lyrics on file: a fuzzy
    -- search still turns up the right song often enough to be worth trying.
    searchFallback(track, callback)
  end)
  if not started then
    callback(nil, nil)
  end
end

return M
