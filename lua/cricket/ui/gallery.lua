local M = {}

local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")
local winsplit = require("infra.winsplit")

local facts = require("cricket.facts")
local player = require("cricket.player")
local signals = require("cricket.ui.signals")

local api = vim.api

local create_buf
do
  local function resolve_cursor_path()
    local line = api.nvim_get_current_line()
    assert(line ~= "")
    return fs.joinpath(facts.root, line)
  end

  local function rhs_play()
    player.playlist_switch(resolve_cursor_path())
    player.play_index(0)
    player.unpause()
    signals.ctl_refresh()
  end

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

  function create_buf()
    local lines = fn.tolist(fs.iterfiles(facts.root))

    local bufnr = Ephemeral({ handyclose = true, name = "cricket://library" }, lines)

    local bm = bufmap.wraps(bufnr)
    bm.n("<cr>", rhs_play)
    bm.n("a", rhs_floatedit)
    bm.n("e", rhs_floatedit)
    bm.n("i", rhs_floatedit)
    bm.n("o", rhs_floatedit)
    bm.n("t", rhs_tabedit)

    return bufnr
  end
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

function M.floatwin() rifts.open.fragment(prepare_buf(), true, { relative = "editor", border = "single" }, { width = 0.6, height = 0.8 }) end

function M.win1000() api.nvim_win_set_buf(0, prepare_buf()) end

---@param side infra.winsplit.Side
function M.split(side) winsplit(side, prepare_buf()) end

return M
