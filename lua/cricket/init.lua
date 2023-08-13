local M = {}

local bufpath = require("infra.bufpath")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("cricket", "debug")
local bufmap = require("infra.keymap.buffer")
local strlib = require("infra.strlib")

local player = require("cricket.player")
local kite = require("kite")

local api = vim.api

do --init
  player.init()
end

local facts = {}
do
  facts.root = fs.joinpath(vim.fn.stdpath("state"), "cricket")
end

local iter_music_files
do
  local allowed_exts = fn.toset({ ".mp3", ".m4a", ".flac" })

  local function resolve_ext(path)
    local at = strlib.rfind(path, ".")
    if at == nil then return end
    return string.sub(path, at)
  end

  ---@param dir string
  ---@return fun(): string? @generates absolute file paths
  function iter_music_files(dir)
    local iter = fn.filter(function(ent, type)
      if type ~= "file" then return false end
      local ext = resolve_ext(ent)
      if ext == nil then return false end
      return allowed_exts[string.lower(ext)]
    end, fs.iterdir(dir))

    return function()
      local ent = iter()
      if ent == nil then return end
      return fs.joinpath(dir, ent)
    end
  end
end

function M.collect(dir)
  if not fs.exists(dir) then return jelly.warn("%s not exists", dir) end

  local path = fs.joinpath(facts.root, fs.basename(dir))

  ex("tabedit", path)

  local bufnr = api.nvim_get_current_buf()

  if not fs.exists(path) then
    local lines = fn.tolist(iter_music_files(dir))
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  else
    --keep it unchanged
  end
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

return M
