local M = {}

local buflines = require("infra.buflines")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fs = require("infra.fs")
local itertools = require("infra.itertools")
local its = require("infra.its")
local jelly = require("infra.jellyfish")("cricket.ui.ctl", "info")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local wincursor = require("infra.wincursor")
local winsplit = require("infra.winsplit")

local beckonize = require("beckon.beckonize")
local player = require("cricket.player")
local audiodevices = require("cricket.ui.audiodevices")
local gallery = require("cricket.ui.gallery")
local hud = require("cricket.ui.hud")
local signals = require("cricket.ui.signals")
local puff = require("puff")

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

    local this_bufnr = ni.get_current_buf()
    prefer.bo(this_bufnr, "bufhidden", "wipe")

    ni.create_autocmd("bufwipeout", {
      buffer = this_bufnr,
      once = true,
      callback = function()
        if player.playlist_current() ~= path then return jelly.info("no reloading as %s is not the current playlist", fs.basename(path)) end

        local same = itertools.equals(
          itertools.project("filename", player.prop_playlist()),
          --
          buflines.iter(self.bufnr)
        )
        if same then return jelly.info("no reloading, %s has no changes", fs.basename(path)) end

        player.playlist_switch(path)
        signals.ctl_refresh()
      end,
    })
  end

  function Impl:whereami()
    local pos = player.intprop("playlist-pos")
    if not (pos and pos ~= -1) then return jelly.info("not playing nor paused") end
    wincursor.go(nil, pos, 0)
  end

  function Impl:quit()
    puff.confirm({ subject = "quit the player?" }, function(confirmed)
      if not confirmed then return end
      jelly.info("remember player.init()")
      player.quit()
    end)
  end

  function Impl:play_cursor()
    local index = wincursor.lnum()
    player.play_index(index)
    player.unpause()
    jelly.info("playing #%d", index)
  end

  function Impl:refresh()
    local chirps = its(player.prop_playlist()) --
      :map(function(chirp) return fs.stem(chirp.filename) end)
      :tolist()
    ctx.modifiable(self.bufnr, function() buflines.replaces_all(self.bufnr, chirps) end)
  end

  function Impl:shuffle()
    player.cmd1("playlist-shuffle")
    signals.ctl_refresh()
    jelly.info("playlist shuffled")
  end

  function Impl:unshuffle()
    player.cmd1("playlist-unshuffle")
    signals.ctl_refresh()
    jelly.info("playlist restore/unshuffled")
  end

  function Impl:volume_up()
    player.volume(5)
    jelly.info("volume: +5, %d", player.intprop("volume"))
  end

  function Impl:volume_down()
    player.volume(-5)
    jelly.info("volume: -5, %d", player.intprop("volume"))
  end

  function Impl:toggle_pause()
    player.toggle("pause")
    jelly.info("toggle: paused?")
  end

  function Impl:toggle_mute()
    player.toggle("mute")
    jelly.info("toggle: muted?")
  end

  function Impl:seek_forward()
    player.seek(5)
    jelly.info("progress: +5s")
  end

  function Impl:seek_backword()
    player.seek(-5)
    jelly.info("progress: -5")
  end

  function Impl:play_next()
    player.cmd1("playlist-next")
    jelly.info("playing next track")
  end

  function Impl:play_prev()
    player.cmd1("playlist-prev")
    jelly.info("playing previous track")
  end

  function Impl:loop_track()
    player.toggle("loop-file")
    jelly.info("toggle: loop the current track? %d", player.intprop("loop-file"))
  end

  function Impl:loop_playlist()
    player.toggle("loop-playlist")
    jelly.info("toggle: loop the current playlist? %d", player.intprop("loop-playlist"))
  end

  ---@param bufnr integer
  ---@return cricket.ui.ctl.RHS
  function RHS(bufnr) return setmetatable({ bufnr = bufnr }, Impl) end
end

---@return integer
local function create_buf()
  ---@diagnostic disable-next-line: redefined-local
  local bufnr = Ephemeral({ bufhidden = "hide", modifiable = false, name = "cricket://ctl", handyclose = true })

  ---@type cricket.ui.ctl.RHS
  local rhs
  do
    local origin = RHS(bufnr)

    rhs = setmetatable({}, {
      __index = function(t, key)
        local f = function(...) return origin[key](origin, ...) end
        t[key] = f
        return f
      end,
    })
  end

  do
    local bm = bufmap.wraps(bufnr)

    --stylua: ignore start
    bm.n("<c-g>",   hud)
    bm.n("i",       rhs.whereami)
    bm.n("a",       rhs.edit_playlist)
    bm.n("e",       rhs.edit_playlist)
    bm.n("o",       rhs.edit_playlist)
    bm.n("-",       gallery.floatwin)

    bm.n("<cr>",    rhs.play_cursor)
    bm.n("9",       rhs.volume_down)
    bm.n("0",       rhs.volume_up)
    bm.n("<space>", rhs.toggle_pause)
    bm.n("m",       rhs.toggle_mute)
    bm.n("h",       rhs.seek_backword)
    bm.n("l",       rhs.seek_forward)
    bm.n("n",       rhs.play_next)
    bm.n("p",       rhs.play_prev)
    bm.n("s",       rhs.shuffle)
    bm.n("S",       rhs.unshuffle)
    bm.n("r",       rhs.loop_track)
    bm.n("R",       rhs.loop_playlist)
    bm.n("A",       audiodevices.switch)
    bm.n("x",       rhs.quit)
    bm.n("/",       function() beckonize(nil, nil, { remember = true }) end)
    --stylua: ignore end
  end

  signals.on_ctl_refresh(function()
    if not ni.buf_is_valid(bufnr) then return true end
    ---@diagnostic disable-next-line: missing-parameter
    rhs.refresh()
  end)
  signals.ctl_refresh()

  return bufnr
end

local prepare_buf
do
  local bufnr
  ---@return integer
  function prepare_buf()
    if not (bufnr and ni.buf_is_valid(bufnr)) then bufnr = create_buf() end
    return bufnr
  end
end

function M.floatwin() rifts.open.fragment(prepare_buf(), true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 }) end

function M.win1000() ni.win_set_buf(0, prepare_buf()) end

---@param side infra.winsplit.Side
function M.split(side) winsplit(side, prepare_buf()) end

return M
