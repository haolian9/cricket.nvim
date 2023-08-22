local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local fs = require("infra.fs")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")

local facts = require("cricket.facts")
local player = require("cricket.player")

local api = vim.api
local uv = vim.loop

local get_lines
do
  local function global_status()
    local lines = {}
    do
      local val = assert(player.propi("volume"))
      table.insert(lines, string.format("%dv", val))
    end

    local has_playlist, playlist
    do
      local path = player.playlist_current()
      playlist = path and fs.stem(path) or "n/a"
      has_playlist = path ~= nil
    end

    if has_playlist then
      local val = player.propi("loop-times")
      assert(val == -1 or val == 1)
      if val == -1 then table.insert(lines, "loop") end
    end

    table.insert(lines, playlist)

    return table.concat(lines, " ")
  end

  local function chirp_status()
    local lines = {}

    local has_chirp, chirp
    do
      local prop = player.prop_filename()
      chirp = prop and fs.stem(prop) or "n/a"
      has_chirp = prop ~= nil
    end

    if has_chirp then
      local val = assert(player.propi("duration"))
      table.insert(lines, string.format("%ds", val))
    end

    table.insert(lines, chirp)

    return table.concat(lines, " ")
  end

  function get_lines() return { global_status(), chirp_status() } end
end

---@param lines string[]
---@return table
local function resolve_winopts(lines)
  local llen = assert(fn.max(fn.map(function(l) return #l end, lines)))
  local height = #lines
  local width = math.min(llen, vim.go.columns)
  return dictlib.merged({ relative = "editor" }, popupgeo.editor(width, height, "right", "top"))
end

local refresh
do
  ---@param bufnr integer
  function refresh(bufnr, winid)
    local lines = get_lines()
    ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, lines) end)
    ctx.landwincall(function() api.nvim_win_set_config(winid, resolve_winopts(lines)) end)
  end
end

local function new_buf(lines)
  local bufnr = Ephemeral({ name = "cricket://hud", handyclose = true }, lines)

  local function rhs_refresh() refresh(bufnr, api.nvim_get_current_win()) end
  bufmap(bufnr, "n", "r", rhs_refresh)
  --api.nvim_create_autocmd({ "bufwinenter", "winenter" }, { buffer = bufnr, callback = refresh })

  return bufnr
end

local bufnr, winid, timer

do
  timer = uv.new_timer()
  uv.timer_start(timer, 0, 3 * 1000, function()
    vim.schedule(function()
      if not (bufnr and api.nvim_buf_is_valid(bufnr)) then return uv.timer_stop(timer) end
      if not (winid and api.nvim_win_is_valid(winid)) then return uv.timer_stop(timer) end
      refresh(bufnr, winid)
    end)
  end)
end

return function()
  if not (bufnr and api.nvim_buf_is_valid(bufnr)) then bufnr = new_buf() end

  if not (winid and api.nvim_win_is_valid(winid)) then
    winid = api.nvim_open_win(bufnr, false, resolve_winopts({ "n/a" }))
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  else
    api.nvim_win_set_buf(winid, bufnr)
  end

  refresh(bufnr, winid)
  uv.timer_again(timer)
end
