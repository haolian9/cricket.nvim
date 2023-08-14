local M = {}

local ffi = require("ffi")

local fs = require("infra.fs")

ffi.cdef([[
  bool cricket_init(void);
  bool cricket_quit(void);
  bool cricket_playlist_switch(const char *path);
  bool cricket_cmd1(const char *subcmd);
  char *cricket_prop_filename(void);
  bool cricket_toggle(const char *what);
  bool cricket_seek(int8_t offset);
  bool cricket_volume(int8_t offset);
  bool cricket_propi(const char *name, int64_t *result);
  bool cricket_play_index(uint16_t index);
  char *cricket_prop_playlist(void);
  void cricket_free(void *ptr);
]])

local C
do
  local lua_root = fs.resolve_plugin_root("cricket", "player.lua")
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

---@param subcmd "playlist-shuffle"|"playlist-unshuffle"|"playlist-next"|"playlist-prev"|"playlist-clear"|"stop"
---@return boolean
function M.cmd1(subcmd) return C.cricket_cmd1(subcmd) end

---@param offset integer @positive=forward, negative=backward
---@return boolean
function M.seek(offset) return C.cricket_seek(offset) end

---@param what "mute"|"pause"|"loop-playlist"
---@return boolean
function M.toggle(what) return C.cricket_toggle(what) end

---@return string?
function M.prop_filename()
  local ptr = C.cricket_prop_filename()
  if ptr == nil then return end
  local ok, filename = pcall(function() return ffi.string(ptr) end)
  C.cricket_free(ptr)
  if not ok then error(filename) end
  return filename
end

---@param offset integer
---@return boolean
function M.volume(offset) return C.cricket_volume(offset) end

---@param name "volume"|"duration"|"percent-pos"|"loop-playlist"
---@return integer?
function M.propi(name)
  local val = ffi.new("int64_t[1]")
  if C.cricket_propi(name, val) then return assert(tonumber(val[0])) end
end

---@param index integer @>=0
---@return boolean
function M.play_index(index) return C.cricket_play_index(index) end

do
  ---@class cricket.Chirp
  ---@field filename string
  ---@field current? 1
  ---@field playing? 1
  ---@field title? string
  ---@field id integer

  ---@return cricket.Chirp[]
  function M.prop_playlist()
    local ptr = C.cricket_prop_playlist()
    if ptr == nil then return {} end
    --todo: avoid ffi.string
    return vim.json.decode(ffi.string(ptr))
  end
end

return M