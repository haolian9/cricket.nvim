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
local uv = vim.loop

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

  ---@param root string
  ---@return fun(): string? @generates absolute file paths
  function iter_music_files(root)
    local iter = fn.filtern(function(fname, ftype)
      if ftype ~= "file" then return false end
      local ext = fs.suffix(fname)
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

  local global_bufnr

  local function load_buf()
    if global_bufnr and api.nvim_buf_is_valid(global_bufnr) then return global_bufnr end

    local bufnr = Ephemeral({ bufhidden = "hide" }, get_playlist())
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

    api.nvim_create_autocmd("winenter", {
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

    do
      local width = math.floor(vim.go.columns / 2)
      local height = vim.go.lines - 2 - vim.go.cmdheight - 1 -- border + cmdline + statusline; tab?
      local row, col = 0, 0
      local winid = api.nvim_open_win(bufnr, true, { relative = "editor", border = "single", width = width, height = height, row = row, col = col })
      api.nvim_win_set_hl_ns(winid, facts.floatwin_ns)
    end
  end
end

do
  local timer = uv.new_timer()

  local function resolve_track_name()
    local full = player.prop_filename()
    if full == nil then return "n/a" end
    local stem = fs.stem(full)
    return string.match(stem, "^%d*[- .]*(.+)")
  end

  local feedfile = fs.joinpath(vim.fn.stdpath("state"), "cricket.obs")

  local function op_feed()
    uv.timer_start(timer, 0, 5 * 1000, function()
      local file = assert(io.open(feedfile, "w"))
      local ok, err = pcall(function() file:write(resolve_track_name()) end)
      file:close()
      if not ok then error(err) end
    end)
  end

  local function op_stop() uv.timer_stop() end

  ---@param op 'feed'|'stop'
  function M.obs(op)
    if op == "feed" then
      op_feed()
    elseif op == "stop" then
      op_stop()
    else
      error("unknown op")
    end
  end
end

return M
