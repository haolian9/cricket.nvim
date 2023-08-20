local M = {}

local bufrename = require("infra.bufrename")
local coreutils = require("infra.coreutils")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local fs = require("infra.fs")
local handyclosekeys = require("infra.handyclosekeys")
local highlighter = require("infra.highlighter")
local jelly = require("infra.jellyfish")("cricket", "debug")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")
local strlib = require("infra.strlib")

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

local facts = {}
do
  do
    facts.root = fs.joinpath(vim.fn.stdpath("state"), "cricket")
    coreutils.mkdir(facts.root)
  end
  do
    facts.floatwin_ns = api.nvim_create_namespace("cricket.floatwin")
    local hi = highlighter(facts.floatwin_ns)
    if vim.go.background == "light" then
      hi("normalfloat", { fg = 8 })
    else
      hi("normalfloat", { fg = 7 })
    end
  end
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
  local function get_lines()
    return fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
  end

  local function rhs_reload(bufnr)
    ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, get_lines()) end)
  end

  local global_bufnr

  local function load_buf()
    if global_bufnr and api.nvim_buf_is_valid(global_bufnr) then return global_bufnr end

    local bufnr = Ephemeral({ bufhidden = "hide" }, get_lines())
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
      bm.n("R", function() rhs_reload(bufnr) end)
    end

    api.nvim_create_autocmd({ "winenter", "bufwinenter" }, {
      buffer = bufnr,
      callback = function()
        assert(api.nvim_get_current_buf() == bufnr)
        rhs_reload(bufnr)
      end,
    })

    global_bufnr = bufnr
    return bufnr
  end

  function M.controller()
    local bufnr = load_buf()

    local width, height, row, col = popupgeo.editor_central(0.6, 0.8)
    local winid = api.nvim_open_win(bufnr, true, { relative = "editor", border = "single", width = width, height = height, row = row, col = col })
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

return M
