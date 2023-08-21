local M = {}

local bufrename = require("infra.bufrename")
local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local fs = require("infra.fs")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("cricket", "debug")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")
local strlib = require("infra.strlib")

local facts = require("cricket.facts")
local player = require("cricket.player")
local kite = require("kite")
local tui = require("tui")

local api = vim.api
local uv = vim.loop

do --init
  player.init()
  --although barrier is being used, this is still necessary for :qa!
  api.nvim_create_autocmd("vimleave", { callback = function() player.quit() end })
end

---@param winid? integer
function M.browse(winid)
  if winid == nil then winid = api.nvim_get_current_win() end

  kite.land(facts.root)

  local bufnr = api.nvim_get_current_buf()
  assert(strlib.startswith(api.nvim_buf_get_name(bufnr), "kite://"))

  bufmap(bufnr, "n", "<cr>", function()
    local fname = strlib.lstrip(api.nvim_get_current_line(), " ")
    assert(player.playlist_switch(fs.joinpath(facts.root, fname)))
    jelly.info("playing: %s", fname)
  end)
end

do
  local function get_chirps()
    return fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
  end

  local function rhs_refresh(bufnr)
    local winid = api.nvim_get_current_win()
    assert(api.nvim_win_get_buf(winid) == bufnr)
    ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, get_chirps()) end)
  end

  local function new_buf()
    local bufnr = Ephemeral({ bufhidden = "hide", modifiable = false })
    bufrename(bufnr, "cricket://controller")

    do
      local bm = bufmap.wraps(bufnr)

      handyclosekeys(bufnr)

      bm.n("n", function() player.cmd1("playlist-next") end)
      bm.n("p", function() player.cmd1("playlist-prev") end)
      bm.n("s", function() player.cmd1("playlist-shuffle") end)
      bm.n("S", function() player.cmd1("playlist-unshuffle") end)
      bm.n("<cr>", function()
        local index = api.nvim_win_get_cursor(0)[1] - 1
        player.play_index(index)
      end)
      bm.n("x", function()
        --todo: fix the mysterious goto(0,0) when pressing q
        tui.confirm({ prompt = "quit the player?" }, function(confirmed)
          if not confirmed then return end
          assert(player.quit())
          jelly.info("you'll need to call player.init() manually")
        end)
      end)
      bm.n("-", function() player.volume(-5) end)
      bm.n("=", function() player.volume(5) end)
      bm.n("h", function() player.seek(-5) end)
      bm.n("l", function() player.seek(5) end)
      bm.n("<space>", function() player.toggle("pause") end)
      bm.n("m", function() player.toggle("mute") end)
      bm.n("r", function() player.toggle("loop-playlist") end)
      bm.n("e", function() M.browse(api.nvim_get_current_win()) end)
      bm.n("R", function() rhs_refresh(bufnr) end)
    end

    api.nvim_create_autocmd({ "winenter", "bufwinenter" }, {
      buffer = bufnr,
      callback = function()
        assert(api.nvim_get_current_buf() == bufnr)
        rhs_refresh(bufnr)
      end,
    })

    return bufnr
  end

  local bufnr

  function M.controller()
    if bufnr == nil then bufnr = new_buf() end
    local winopts = dictlib.merged({ relative = "editor", border = "single" }, popupgeo.editor(0.6, 0.8))
    local winid = api.nvim_open_win(bufnr, true, winopts)
    api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
  end
end

do
  local timer = uv.new_timer()

  local function resolve_track_name()
    local full = player.prop_filename()
    if full == nil then return "n/a" end
    local stem = fs.stem(full)
    return assert(string.match(stem, "^%d*[- .]*(.+)"))
  end

  local feedfile = fs.joinpath(vim.fn.stdpath("state"), "cricket.obs")

  local handlers = {
    feed = function()
      uv.timer_start(timer, 0, 5 * 1000, function()
        local file = assert(io.open(feedfile, "w"))
        local ok, err = pcall(function() file:write(resolve_track_name()) end)
        file:close()
        if not ok then error(err) end
      end)
    end,
    stop = function() uv.timer_stop() end,
  }

  ---@param op 'feed'|'stop'
  function M.obs(op) assert(handlers[op])() end
end

do
  --todo: dedicated bufnr
  --todo: update via an event
  --todo: transparency
  --todo: make it eyecandy

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

  function M.hud()
    local lines = get_lines()

    local bufnr
    do
      bufnr = Ephemeral({ bufhidden = "hide" }, lines)
      handyclosekeys(bufnr)
      bufmap(bufnr, "n", "r", function()
        api.nvim_win_close(0, false)
        M.hud()
      end)
    end

    do
      local winopts
      do
        local llen = assert(fn.max(fn.map(function(l) return #l end, lines)))
        local height = #lines
        local width = math.min(llen, vim.go.columns)
        winopts = dictlib.merged({ relative = "editor" }, popupgeo.editor(width, height, "right", "top"))
      end
      local winid = api.nvim_open_win(bufnr, false, winopts)
      api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
    end
  end
end

return M
