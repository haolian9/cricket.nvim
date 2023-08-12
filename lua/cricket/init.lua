local M = {}

local cthulhu = require("cthulhu")
local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local bufmap = require("infra.keymap.buffer")
local strlib = require("infra.strlib")

local unsafe = require("cricket.unsafe")

local api = vim.api

do --init
  unsafe.init()
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

function M.edit(dir)
  local path = fs.joinpath(vim.fn.stdpath("state"), "cricket", cthulhu.md5(dir))

  ex("tabedit", path)
  local bufnr = api.nvim_get_current_buf()
  if not fs.exists(path) then
    local lines = fn.tolist(iter_music_files(dir))
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  local bm = bufmap.wraps(bufnr)
  bm.n("<F2>", function() assert(unsafe.playlist_switch(path)) end)
end

return M
