local ctx = require("infra.ctx")
local dictlib = require("infra.dictlib")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("cricket.ui.ctl", "debug")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local facts = require("cricket.facts")
local player = require("cricket.player")
local kite = require("kite")
local tui = require("tui")

local api = vim.api

local function get_chirps()
  return fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
end

local bufnr, winid, rhs

do
  rhs = {}
  function rhs.refresh()
    --a workaround for https://github.com/neovim/neovim/issues/24843
    if api.nvim_get_current_win() ~= winid then return end
    if api.nvim_win_get_buf(winid) ~= bufnr then return end
    ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, get_chirps()) end)
  end

  function rhs.browse_library()
    kite.land(facts.root)

    local kite_bufnr = api.nvim_get_current_buf()
    assert(strlib.startswith(api.nvim_buf_get_name(kite_bufnr), "kite://"))

    bufmap(kite_bufnr, "n", "<cr>", function()
      local fname = strlib.lstrip(api.nvim_get_current_line(), " ")
      assert(player.playlist_switch(fs.joinpath(facts.root, fname)))
      jelly.info("playing: %s", fname)
    end)
  end

  function rhs.whereami()
    local pos = player.propi("playlist-pos")
    if not (pos and pos ~= -1) then return end
    api.nvim_win_set_cursor(winid, { pos + 1, 0 })
  end

  function rhs.edit_playlist()
    local path = player.playlist_current()
    if path == nil then return jelly.info("no playlist available") end

    ex("tabedit", path)

    local this_bufnr = api.nvim_get_current_buf()
    prefer.bo(this_bufnr, "bufhidden", "wipe")

    api.nvim_create_autocmd("bufwipeout", {
      buffer = this_bufnr,
      callback = function()
        if player.playlist_current() ~= path then return jelly.info("no reloading as %s is not the current playlist", fs.basename(path)) end

        local same = fn.iter_equals(player.prop_playlist(), api.nvim_buf_get_lines(this_bufnr, 0, -1, false))
        if same then return jelly.info("no reloading, %s has no changes", fs.basename(path)) end

        player.playlist_switch(path)
      end,
    })
  end

  function rhs.quit()
    tui.confirm({ prompt = "quit the player?" }, function(confirmed)
      if not confirmed then return end
      player.quit()
      jelly.info("you'll need to call player.init() manually")
    end)
  end

  function rhs.play_cursor()
    local index = api.nvim_win_get_cursor(0)[1] - 1
    player.play_index(index)
    --todo: resume if paused
  end

  function rhs.shuffle()
    player.cmd1("playlist-shuffle")
    rhs.refresh()
  end

  function rhs.unshuffle()
    player.cmd1("playlist-unshuffle")
    rhs.refresh()
  end
end

do
  bufnr = Ephemeral({ bufhidden = "hide", modifiable = false, name = "cricket://ctl", handyclose = true })

  -- stylua: ignore
  do
    local bm = bufmap.wraps(bufnr)

    bm.n("n",       function() player.cmd1("playlist-next") end)
    bm.n("p",       function() player.cmd1("playlist-prev") end)
    bm.n("s",       rhs.shuffle)
    bm.n("S",       rhs.unshuffle)
    bm.n("<cr>",    rhs.play_cursor)
    bm.n("x",       rhs.quit)
    bm.n("-",       function() player.volume(-5) end)
    bm.n("=",       function() player.volume(5) end)
    bm.n("h",       function() player.seek(-5) end)
    bm.n("l",       function() player.seek(5) end)
    bm.n("<space>", function() player.toggle("pause") end)
    bm.n("m",       function() player.toggle("mute") end)
    bm.n("r",       function() player.toggle("loop-playlist") end)
    bm.n("e",       rhs.browse_library)
    bm.n("R",       rhs.refresh)
    bm.n("i",       rhs.whereami)
    bm.n("o",       rhs.edit_playlist)
  end

  api.nvim_create_autocmd({ "winenter", "bufwinenter" }, { buffer = bufnr, callback = rhs.refresh })
end

return function()
  assert(api.nvim_buf_is_valid(bufnr))
  if winid and api.nvim_win_is_valid(winid) then return api.nvim_win_set_buf(winid, bufnr) end

  local winopts = dictlib.merged({ relative = "editor", border = "single" }, popupgeo.editor(0.6, 0.8, "mid", "mid", 1))
  winid = api.nvim_open_win(bufnr, true, winopts)
  api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
end
