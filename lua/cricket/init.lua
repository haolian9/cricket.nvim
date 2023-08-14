local M = {}

local bufpath = require("infra.bufpath")
local bufrename = require("infra.bufrename")
local coreutils = require("infra.coreutils")
local ctx = require("infra.ctx")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local handyclosekeys = require("infra.handyclosekeys")
local highlighter = require("infra.highlighter")
local jelly = require("infra.jellyfish")("cricket", "debug")
local bufmap = require("infra.keymap.buffer")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local player = require("cricket.player")
local kite = require("kite")

local api = vim.api

do --init
  player.init()
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

local iter_music_files
do
  local allowed_exts = fn.toset({ ".mp3", ".m4a", ".flac" })

  local function resolve_ext(path)
    local at = strlib.rfind(path, ".")
    if at == nil then return end
    return string.sub(path, at)
  end

  ---@param root string
  ---@return fun(): string? @generates absolute file paths
  function iter_music_files(root)
    local iter = fn.filtern(function(fname, ftype)
      if ftype ~= "file" then return false end
      local ext = resolve_ext(fname)
      if ext == nil then return false end
      return allowed_exts[string.lower(ext)]
    end, fs.iterdir(root))

    return function()
      local fname = iter()
      if fname == nil then return end
      return fs.joinpath(root, fname)
    end
  end
end

---collect music files in a directory non-recursively
---@param dir string @absolute path
function M.collect(dir)
  if not fs.exists(dir) then return jelly.warn("%s not exists", dir) end

  local path = fs.joinpath(facts.root, fs.basename(dir))

  ex("tabedit", path)

  if fs.exists(path) then return end

  local bufnr = api.nvim_get_current_buf()
  local lines = fn.tolist(iter_music_files(dir))
  ctx.no_undo(bufnr, function() api.nvim_buf_set_lines(bufnr, 0, -1, false, lines) end)
end

function M.play_this()
  local bufnr = api.nvim_get_current_buf()

  local path = bufpath.file(bufnr)
  if path == nil then return jelly.warn("no associated file with buf#%d", bufnr) end
  if not strlib.startswith(path, facts.root) then return jelly.warn("not a known playlist") end

  assert(player.playlist_switch(path))
  jelly.info("playing: %s", fs.basename(path))
end

function M.browse()
  kite.fly(facts.root)
  local bufnr = api.nvim_get_current_buf()
  assert(strlib.startswith(api.nvim_buf_get_name(bufnr), "kite://"))
  bufmap(bufnr, "n", "<cr>", function()
    local fname = strlib.lstrip(api.nvim_get_current_line(), " ")
    assert(player.playlist_switch(fs.joinpath(facts.root, fname)))
    jelly.info("playing: %s", fname)
  end)
end

do
  local function get_playlist()
    return fn.tolist(fn.map(function(chirp) return chirp.filename end, player.prop_playlist()))
  end

  local function rhs_reload(bufnr)
    local bo = prefer.buf(bufnr)
    bo.modified = false
    api.nvim_buf_set_lines(bufnr, 0, -1, false, get_playlist())
    bo.modified = true
  end

  function M.controller()
    local bufnr
    do
      bufnr = Ephemeral(nil, get_playlist())
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
      bm.n("e", function() M.browse() end)
      bm.n("R", function() rhs_reload(bufnr) end)
    end

    local winid
    do
      local width = math.floor(vim.go.columns / 2)
      local height = vim.go.lines - 2 - vim.go.cmdheight - 1 -- border + cmdline + statusline; tab?
      local row, col = 0, 0
      winid = api.nvim_open_win(bufnr, true, { relative = "editor", border = "single", width = width, height = height, row = row, col = col })
      api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
    end

    do
      api.nvim_create_autocmd("winenter", {
        buffer = bufnr,
        callback = function()
          --todo: leaving another float win will not trigger this for the underlying floatwin?
          if api.nvim_get_current_win() ~= winid then return end
          assert(api.nvim_win_get_buf(winid) == bufnr)
          rhs_reload(bufnr)
        end,
      })
    end
  end
end

return M
