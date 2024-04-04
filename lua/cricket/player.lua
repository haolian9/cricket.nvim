local M = {}

local ffi = require("ffi")

local augroups = require("infra.augroups")
local barrier = require("infra.barrier")
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

do
  local token = "cricket"
  local acquired = false

  --errs on failed
  function M.init()
    assert(C.cricket_init())
    barrier.acquire(token)
    acquired = true
  end

  --errs on failed
  function M.quit()
    if not acquired then return end
    assert(C.cricket_quit())
    barrier.release(token)
    acquired = false
  end
end

do
  local current

  ---@param fpath string
  ---@return boolean
  function M.playlist_switch(fpath)
    assert(fpath ~= nil and fpath ~= "")
    assert(fs.file_exists(fpath))
    local ok = C.cricket_playlist_switch(fpath)
    if ok then current = fpath end
    return ok
  end

  --get the current playlist's path
  --
  --impl notes:
  --* mpv does not have such thing: https://github.com/mpv-player/mpv/issues/11269
  --* having this in libmpv is inappropriate neither
  ---@return string?
  function M.playlist_current() return current end
end

---@param subcmd "playlist-shuffle"|"playlist-unshuffle"|"playlist-next"|"playlist-prev"|"playlist-clear"|"stop"
---@return boolean
function M.cmd1(subcmd) return C.cricket_cmd1(subcmd) end

---@param offset integer @positive=forward, negative=backward
---@return boolean
function M.seek(offset) return C.cricket_seek(offset) end

---@param what "mute"|"pause"|"loop-playlist"|"loop-file"
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

---@param name "volume"|"duration"|"percent-pos"|"playlist-pos"|"playlist-count"|"loop-playlist"|"loop-file"|"mute"|"pause"
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
    local ok, playlist = pcall(function()
      --todo: avoid ffi.string
      return vim.json.decode(ffi.string(ptr))
    end)
    C.cricket_free(ptr)
    if not ok then error(playlist) end
    return playlist
  end
end

function M.unpause()
  if M.propi("pause") ~= 1 then return end
  M.toggle("pause")
end

do --init
  M.init()
  --although barrier is being used, this is still necessary for :qa!
  local aug = augroups.Augroup("cricket://player")
  aug:once("VimLeave", { callback = function() M.quit() end })
end

return M
