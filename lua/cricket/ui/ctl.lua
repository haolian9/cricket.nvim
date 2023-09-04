local Augroup = require("infra.Augroup")
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
local hud = require("cricket.ui.hud")
local tui = require("tui")

local api = vim.api

local function get_chirps()
  return fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
end

local browse_library
do
  local function resolve_cursor_path()
    local line = api.nvim_get_current_line()
    assert(line ~= "")
    return fs.joinpath(facts.root, line)
  end

  local function rhs_play() require("cricket.player").playlist_switch(resolve_cursor_path()) end

  local function rhs_floatedit()
    local bufnr = vim.fn.bufadd(resolve_cursor_path())
    prefer.bo(bufnr, "bufhidden", "wipe")
    prefer.bo(bufnr, "buflisted", false)
    rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
  end

  local function rhs_tabedit()
    ex("tabedit", resolve_cursor_path())
    local bufnr = api.nvim_get_current_buf()
    prefer.bo(bufnr, "bufhidden", "wipe")
  end

  function browse_library()
    local lines = fn.tolist(fs.iterfiles(facts.root))

    local bufnr = Ephemeral({ handyclose = true, name = "cricket://library" }, lines)

    local bm = bufmap.wraps(bufnr)
    bm.n("<cr>", rhs_play)
    bm.n("a", rhs_floatedit)
    bm.n("e", rhs_floatedit)
    bm.n("i", rhs_floatedit)
    bm.n("o", rhs_floatedit)
    bm.n("t", rhs_tabedit)

    rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
  end
end

---@param bufnr integer
local function refresh_buf(bufnr)
  ctx.modifiable(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, get_chirps()) end)
end

local new_buf
do
  local function rhs_edit_playlist()
    local path = player.playlist_current()
    if path == nil then return jelly.info("no playlist available") end

    ex("tabedit", path)

    local this_bufnr = api.nvim_get_current_buf()
    prefer.bo(this_bufnr, "bufhidden", "wipe")

    api.nvim_create_autocmd("bufwipeout", {
      buffer = this_bufnr,
      once = true,
      callback = function()
        if player.playlist_current() ~= path then return jelly.info("no reloading as %s is not the current playlist", fs.basename(path)) end

        local same = fn.iter_equals(player.prop_playlist(), api.nvim_buf_get_lines(this_bufnr, 0, -1, false))
        if same then return jelly.info("no reloading, %s has no changes", fs.basename(path)) end

        player.playlist_switch(path)
      end,
    })
  end

  local function rhs_whereami()
    local pos = player.propi("playlist-pos")
    if not (pos and pos ~= -1) then return end
    api.nvim_win_set_cursor(0, { pos + 1, 0 })
  end

  local function rhs_quit()
    tui.confirm({ prompt = "quit the player?" }, function(confirmed)
      if not confirmed then return end
      jelly.info("you'll need to call player.init() manually")
      player.quit()
    end)
  end

  local function rhs_play_cursor()
    local index = api.nvim_win_get_cursor(0)[1] - 1
    player.play_index(index)
    player.unpause()
  end

  ---@return integer
  function new_buf()
    ---@diagnostic disable-next-line: redefined-local
    local bufnr = Ephemeral({ bufhidden = "hide", modifiable = false, name = "cricket://ctl", handyclose = true }, get_chirps())

    -- stylua: ignore
    do
      local bm = bufmap.wraps(bufnr)

      local function with_refresh(f, ...)
        local args = { ... }
        return function()
          f(unpack(args))
          refresh_buf(bufnr)
        end
      end

      bm.n("<cr>",    rhs_play_cursor)
      bm.n("-",       function() player.volume(-5) end)
      bm.n("=",       function() player.volume(5) end)
      bm.n("<space>", function() player.toggle("pause") end)
      bm.n("m",       function() player.toggle("mute") end)
      bm.n("r",       function() refresh_buf(bufnr) end)
      bm.n("<c-g>",   hud.transient)
      bm.n("i",       rhs_whereami)
      bm.n("o",       rhs_edit_playlist)
      --防误触
      bm.n("gh",      function() player.seek(-5) end)
      bm.n("gl",      function() player.seek(5) end)
      bm.n("gn",      function() player.cmd1("playlist-next") end)
      bm.n("gp",      function() player.cmd1("playlist-prev") end)
      bm.n("gs",      with_refresh(player.cmd1, "playlist-shuffle"))
      bm.n("gS",      with_refresh(player.cmd1, "playlist-unshuffle"))
      bm.n("gx",      rhs_quit)
      bm.n("gr",      function() player.toggle("loop-playlist") end)
      bm.n("ge",      browse_library)
    end

    return bufnr
  end
end

local bufnr, winid

return function()
  if not (bufnr and api.nvim_buf_is_valid(bufnr)) then bufnr = new_buf() end

  if winid and api.nvim_win_is_valid(winid) then return api.nvim_win_set_buf(winid, bufnr) end

  winid = rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })

  local aug = Augroup.win(winid, true)
  aug:repeats("winenter", {
    callback = function()
      do --necessary checks for https://github.com/neovim/neovim/issues/24843
        if api.nvim_get_current_win() ~= winid then return end
        if api.nvim_win_get_buf(winid) ~= bufnr then return end
      end
      refresh_buf(bufnr)
    end,
  })
end
