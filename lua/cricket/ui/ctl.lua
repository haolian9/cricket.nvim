local M = {}

local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("cricket.ui.ctl", "info")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local winsplit = require("infra.winsplit")

local player = require("cricket.player")
local gallery = require("cricket.ui.gallery")
local hud = require("cricket.ui.hud")
local signals = require("cricket.ui.signals")
local puff = require("puff")

local api = vim.api

local RHS
do
  ---@class cricket.ui.ctl.RHS
  ---@field bufnr integer
  local Impl = {}

  Impl.__index = Impl

  function Impl:edit_playlist()
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

  function Impl:whereami()
    local pos = player.propi("playlist-pos")
    if not (pos and pos ~= -1) then return end
    api.nvim_win_set_cursor(0, { pos + 1, 0 })
  end

  function Impl:quit()
    puff.confirm({ prompt = "quit the player?" }, function(confirmed)
      if not confirmed then return end
      jelly.info("you'll need to call player.init() manually")
      player.quit()
    end)
  end

  function Impl:play_cursor()
    local index = api.nvim_win_get_cursor(0)[1] - 1
    player.play_index(index)
    player.unpause()
  end

  function Impl:refresh()
    local chirps = fn.tolist(fn.map(function(chirp) return fs.stem(chirp.filename) end, player.prop_playlist()))
    ctx.modifiable(self.bufnr, function() api.nvim_buf_set_lines(self.bufnr, 0, -1, false, chirps) end)
  end

  function Impl:shuffle()
    player.cmd1("playlist-shuffle")
    signals.ctl_refresh()
  end

  function Impl:unshuffle()
    player.cmd1("playlist-unshuffle")
    signals.ctl_refresh()
  end

  ---@param bufnr integer
  ---@return cricket.ui.ctl.RHS
  function RHS(bufnr) return setmetatable({ bufnr = bufnr }, Impl) end
end

---@return integer
local function create_buf()
  ---@diagnostic disable-next-line: redefined-local
  local bufnr = Ephemeral({ bufhidden = "hide", modifiable = false, name = "cricket://ctl", handyclose = true })

  local rhs = RHS(bufnr)

  -- stylua: ignore
  do
    local bm = bufmap.wraps(bufnr)

    bm.n("<c-g>",   hud.transient)
    bm.n("i",       function() rhs:whereami() end)
    bm.n("e",       function() rhs:edit_playlist() end)
    bm.n("o",       gallery.floatwin)

    bm.n("<cr>",    function() rhs:play_cursor() end)
    bm.n("-",       function() player.volume(-5) end)
    bm.n("=",       function() player.volume(5) end)
    bm.n("<space>", function() player.toggle("pause") end)
    bm.n("m",       function() player.toggle("mute") end)
    bm.n("h",       function() player.seek(-5) end)
    bm.n("l",       function() player.seek(5) end)
    bm.n("n",       function() player.cmd1("playlist-next") end)
    bm.n("p",       function() player.cmd1("playlist-prev") end)
    bm.n("s",       function() rhs:shuffle() end)
    bm.n("S",       function() rhs:unshuffle() end)
    bm.n("r",       function() player.toggle("loop-file") end)
    bm.n("R",       function() player.toggle("loop-playlist") end)
    bm.n("x",       function() rhs:quit() end)

  end

  signals.on_ctl_refresh(function()
    if not api.nvim_buf_is_valid(bufnr) then return true end
    rhs:refresh()
  end)
  signals.ctl_refresh()

  return bufnr
end

local prepare_buf
do
  local bufnr
  ---@return integer
  function prepare_buf()
    if not (bufnr and api.nvim_buf_is_valid(bufnr)) then bufnr = create_buf() end
    return bufnr
  end
end

function M.floatwin()
  local bufnr = prepare_buf()
  rifts.open.fragment(bufnr, true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 })
end

function M.win1000()
  local bufnr = prepare_buf()
  api.nvim_win_set_buf(0, bufnr)
end

---@param side infra.winsplit.Side
function M.split(side)
  local bufnr = prepare_buf()
  winsplit(side, api.nvim_buf_get_name(bufnr))
end

return M
