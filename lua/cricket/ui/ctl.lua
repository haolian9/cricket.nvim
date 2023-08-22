local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local fs = require("infra.fs")
local handyclosekeys = require("infra.handyclosekeys")
local jelly = require("infra.jellyfish")("cricket.ui.ctl", "debug")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")
local strlib = require("infra.strlib")

local facts = require("cricket.facts")
local player = require("cricket.player")
local kite = require("kite")
local tui = require("tui")

local api = vim.api

local function get_chirps()
  return fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
end

local function rhs_refresh(bufnr)
  local winid = api.nvim_get_current_win()
  assert(api.nvim_win_get_buf(winid) == bufnr)
  ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, get_chirps()) end)
end

local function rhs_browse()
  kite.land(facts.root)

  local bufnr = api.nvim_get_current_buf()
  assert(strlib.startswith(api.nvim_buf_get_name(bufnr), "kite://"))

  bufmap(bufnr, "n", "<cr>", function()
    local fname = strlib.lstrip(api.nvim_get_current_line(), " ")
    assert(player.playlist_switch(fs.joinpath(facts.root, fname)))
    jelly.info("playing: %s", fname)
  end)
end

local function new_buf()
  local bufnr = Ephemeral({ bufhidden = "hide", modifiable = false, name = "cricket://ctl" })

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
    bm.n("e", rhs_browse)
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

local bufnr, winid

return function()
  if bufnr == nil then bufnr = new_buf() end
  if winid and api.nvim_win_is_valid(winid) then return api.nvim_win_set_buf(winid, bufnr) end

  local winopts = dictlib.merged({ relative = "editor", border = "single" }, popupgeo.editor(0.6, 0.8, "mid", "mid", 1))
  winid = api.nvim_open_win(bufnr, true, winopts)
  api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
end
