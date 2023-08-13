local M = {}

local bufpath = require("infra.bufpath")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("cricket", "debug")
local strlib = require("infra.strlib")

local player = require("cricket.player")
local kite = require("kite")
local tui = require("tui")

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

function M.switch()
  local iter = fn.filter(function(_, type)
    if type ~= "file" then return false end
    return true
  end, fs.iterdir(facts.root))

  local playlists = {}
  for path in iter do
    table.insert(playlists, path)
  end

  tui.select(playlists, { prompt = "choose a playlist to play" }, function(playlist)
    if playlist == nil then return end
    player.playlist_switch(fs.joinpath(facts.root, playlist))
    jelly.info("playing playlist: %s", playlist)
  end)
end

function M.play_this()
  local bufnr = api.nvim_get_current_buf()

  local path = bufpath.file(bufnr)
  if path == nil then return jelly.warn("no associated file with buf#%d", bufnr) end
  if not strlib.startswith(path, facts.root) then return jelly.warn("not a known playlist") end

  assert(player.playlist_switch(path))
  jelly.info("playing playlist: %s", fs.basename(path))
end

function M.browse() kite.fly(facts.root) end

function M.info()
  local filename = player.prop_filename()
  return string.format("playing track: %s", fs.basename(filename))
end

return M
