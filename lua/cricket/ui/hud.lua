local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local fs = require("infra.fs")
local rifts = require("infra.rifts")

local player = require("cricket.player")
local ropes = require("string.buffer")

local api = vim.api

---@return string[]
local function get_lines()
  local lines = {}

  lines[#lines + 1] = (function()
    local rope = ropes.new()

    local function bi(prop) return player.propi(prop) == 1 and "是" or "否" end

    rope:putf("音量=%d ", assert(player.propi("volume")))
    rope:putf("循环=%s,%s ", bi("loop-file"), bi("loop-playlist"))
    rope:putf("时长=%d", player.propi("duration") or 0)

    --todo: shuffle
    return rope:tostring()
  end)()

  lines[#lines + 1] = (function()
    local path = player.playlist_current()
    if path == nil then return end
    return fs.basename(path)
  end)()

  lines[#lines + 1] = (function()
    local fname = player.prop_filename()
    if fname == nil then return end
    return fs.stem(fname)
  end)()

  return lines
end

---@param lines string[]
---@return table
local function resolve_winopts(lines)
  --NB: it'd be display width instead of byte length
  local llen = assert(fn.max(fn.map(api.nvim_strwidth, lines)))
  local height = #lines
  local width = math.min(llen, vim.go.columns)
  return dictlib.merged({ relative = "editor", focusable = false, zindex = 250 }, rifts.geo.editor(width, height, "right", "top"))
end

local bufnr, winid

---<c-g> like
return function()
  if winid and api.nvim_win_is_valid(winid) then return end

  local lines = get_lines()
  bufnr = Ephemeral({ name = "cricket://hud", handyclose = true }, lines)
  winid = rifts.open.fragment(bufnr, false, resolve_winopts(lines))
  vim.defer_fn(function() api.nvim_win_close(winid, false) end, 3 * 1000)
end
