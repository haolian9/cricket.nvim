local bufrename = require("infra.bufrename")
local Ephemeral = require("infra.Ephemeral")
local fn = require("infra.fn")
local handyclosekeys = require("infra.handyclosekeys")
local bufmap = require("infra.keymap.buffer")
local popupgeo = require("infra.popupgeo")

local player = require("cricket.player")

local api = vim.api

do -- main
  local bufnr
  do
    local lines = fn.tolist(fn.map(function(chirp) return chirp.filename end, player.prop_playlist()))
    bufnr = Ephemeral(nil, lines)
    bufrename(bufnr, "cricket://controller")
  end

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
    bm.n("x", function() assert(player.quit()) end)
    bm.n("-", function() player.volume(-5) end)
    bm.n("=", function() player.volume(5) end)
    bm.n("h", function() player.seek(-5) end)
    bm.n("l", function() player.seek(5) end)
    bm.n("<space>", function() player.toggle("pause") end)
    bm.n("m", function() player.toggle("mute") end)
    bm.n("r", function() player.toggle("loop-playlist") end)
  end

  do
    local width, height = math.floor(vim.go.columns / 2), vim.go.lines - 2 - vim.go.cmdheight
    local row, col = 0, width
    api.nvim_open_win(bufnr, true, { relative = "editor", border = "single", width = width, height = height, row = row, col = col, title = "cricket controller", title_pos = "center" })
  end
end
