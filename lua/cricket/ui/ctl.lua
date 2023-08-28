local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("cricket.ui.ctl", "debug")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local facts = require("cricket.facts")
local player = require("cricket.player")
local tui = require("tui")

local api = vim.api

local function get_chirps()
  return fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
end

local browse_library
do
  local editor = {}
  do
    --todo: reload playlist if it's beeing played
    function editor.tab(path)
      ex("tabedit", path)
      local bufnr = api.nvim_get_current_buf()
      prefer.bo(bufnr, "bufhidden", "wipe")
    end

    function editor.floatwin(path)
      local bufnr = vim.fn.bufadd(path)
      prefer.bo(bufnr, "bufhidden", "wipe")
      prefer.bo(bufnr, "buflisted", false)
      rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
    end
  end

  local function resolve_cursor_path()
    local line = api.nvim_get_current_line()
    assert(line ~= "")
    return fs.joinpath(facts.root, line)
  end

  local function rhs_play() require("cricket.player").playlist_switch(resolve_cursor_path()) end
  local function rhs_floatedit() editor.floatwin(resolve_cursor_path()) end

  function browse_library()
    local lines = fn.tolist(fs.iterfiles(facts.root))

    local bufnr = Ephemeral({ handyclose = true, name = "cricket://library" }, lines)

    local bm = bufmap.wraps(bufnr)
    bm.n("<cr>", rhs_play)
    bm.n("a", rhs_floatedit)
    bm.n("e", rhs_floatedit)
    bm.n("i", rhs_floatedit)
    bm.n("o", rhs_floatedit)
    bm.n("t", function() editor.tab(resolve_cursor_path()) end)

    rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
  end
end

local bufnr, winid, rhs

do
  rhs = {}
  function rhs.refresh()
    --necessary checks for https://github.com/neovim/neovim/issues/24843
    if api.nvim_get_current_win() ~= winid then return end
    if api.nvim_win_get_buf(winid) ~= bufnr then return end
    ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, get_chirps()) end)
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
    player.unpause()
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
    bm.n("e",       browse_library)
    bm.n("R",       rhs.refresh)
    bm.n("i",       rhs.whereami)
    bm.n("o",       rhs.edit_playlist)
    bm.n("<c-g>",   function() require("cricket.ui.hud").transient() end)
  end

  api.nvim_create_autocmd({ "winenter", "bufwinenter" }, { buffer = bufnr, callback = rhs.refresh })
end

return function()
  assert(api.nvim_buf_is_valid(bufnr))
  if winid and api.nvim_win_is_valid(winid) then return api.nvim_win_set_buf(winid, bufnr) end

  winid = rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
end
