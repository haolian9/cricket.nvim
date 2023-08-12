local M = {}

local ffi = require("ffi")

local fs = require("infra.fs")

ffi.cdef([[
  bool cricket_init(void);
  bool cricket_quit(void);
  bool cricket_playlist_switch(const char *path);
  bool cricket_cmd1(const char *subcmd);
]])

local C
do
  local lua_root = fs.resolve_plugin_root("cricket", "unsafe.lua")
  local root = fs.parent(fs.parent(lua_root))
  C = ffi.load(fs.joinpath(root, "zig-out/lib/libcricket.so"), false)
end

---@return boolean
function M.init() return C.cricket_init() end

---@return boolean
function M.quit() return C.cricket_quit() end

---@param path string
---@return boolean
function M.playlist_switch(path)
  assert(path ~= nil and path ~= "")
  assert(fs.exists(path))
  return C.cricket_playlist_switch(path)
end

---@return boolean
function M.cmd1(subcmd) return C.cricket_cmd1(subcmd) end

return M
