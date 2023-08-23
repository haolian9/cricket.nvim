local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local fs = require("infra.fs")
local popupgeo = require("infra.popupgeo")

local facts = require("cricket.facts")
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

    local loop = player.propi("loop-times")
    table.insert(parts, string.format("循环=%s", loop == -1 and "inf" or "1"))

    local duration = player.propi("duration")
    table.insert(parts, string.format("时长=%d", fn.nilor(duration, 0)))

    return table.concat(parts, " ")
  end)()

  local has_playlist
  lines[#lines + 1] = (function()
    local path = player.playlist_current()
    has_playlist = path ~= nil
    if not has_playlist then return end
    return fs.basename(path)
  end)()

  lines[#lines + 1] = (function()
    if not has_playlist then return end
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
  return dictlib.merged({ relative = "editor", focusable = false }, popupgeo.editor(width, height, "right", "top"))
end

local bufnr, winid, timer

do
  timer = uv.new_timer()
  uv.timer_start(timer, 0, 5 * 1000, function()
    vim.schedule(function()
      if not (bufnr and api.nvim_buf_is_valid(bufnr)) then return uv.timer_stop(timer) end
      if not (winid and api.nvim_win_is_valid(winid)) then return uv.timer_stop(timer) end
      local lines = get_lines()
      ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, lines) end)
      ctx.landwincall(function() api.nvim_win_set_config(winid, resolve_winopts(lines)) end)
    end)
  end)
end

---toggle show a HUD
return function()
  if winid and api.nvim_win_is_valid(winid) then return api.nvim_win_close(winid, false) end

  local lines = get_lines()
  bufnr = Ephemeral({ name = "cricket://hud", handyclose = true }, lines)
  winid = api.nvim_open_win(bufnr, false, resolve_winopts(lines))
  api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  uv.timer_again(timer)
end
