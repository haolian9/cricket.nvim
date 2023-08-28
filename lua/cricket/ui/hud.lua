local M = {}

local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local rifts = require("infra.rifts")
local fn = require("infra.fn")
local fs = require("infra.fs")

local player = require("cricket.player")

local api = vim.api
local uv = vim.loop

---@return string[]
local function get_lines()
  local lines = {}

  lines[#lines + 1] = (function()
    local parts = {}

    table.insert(parts, string.format("音量=%d", assert(player.propi("volume"))))

    --todo: shuffle

    local loop = player.propi("loop-playlist")
    table.insert(parts, string.format("循环=%s", loop == 1 and "是" or "否"))

    local duration = player.propi("duration")
    table.insert(parts, string.format("时长=%d", fn.nilor(duration, 0)))

    return table.concat(parts, " ")
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
  local llen = assert(fn.max(fn.map(function(l) return api.nvim_strwidth(l) end, lines)))
  local height = #lines
  local width = math.min(llen, vim.go.columns)
  return dictlib.merged({ relative = "editor", focusable = false, zindex = 250 }, rifts.geo.editor(width, height, "right", "top"))
end

local bufnr, winid

do
  local refresher = uv.new_timer()

  uv.timer_start(refresher, 0, 5 * 1000, function()
    vim.schedule(function()
      if not (winid and api.nvim_win_is_valid(winid)) then return uv.timer_stop(refresher) end
      local lines = get_lines()
      ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, lines) end)
      ctx.landwincall(function() api.nvim_win_set_config(winid, resolve_winopts(lines)) end)
    end)
  end)

  ---toggle an unfocusable HUD
  function M.permanent()
    if winid and api.nvim_win_is_valid(winid) then return api.nvim_win_close(winid, false) end

    local lines = get_lines()
    bufnr = Ephemeral({ name = "cricket://hud", handyclose = true }, lines)
    winid = rifts.open.fragment(bufnr, false, resolve_winopts(lines))
    uv.timer_again(refresher)
  end
end

---<c-g> like
function M.transient()
  if winid and api.nvim_win_is_valid(winid) then return end

  local lines = get_lines()
  bufnr = Ephemeral({ name = "cricket://hud", handyclose = true }, lines)
  winid = rifts.open.fragment(bufnr, false, resolve_winopts(lines))
  vim.defer_fn(function() api.nvim_win_close(winid, false) end, 3 * 1000)
end

return M

