local ffi = require("ffi")

ffi.cdef([[
  bool cricket_init(void);
  bool cricket_quit(void);
  bool cricket_playlist_switch(const char *path);
  bool cricket_cmd1(const char *subcmd);
  bool cricket_prop_filename(char result[4096]);
  bool cricket_toggle(const char *what);
  bool cricket_seek(int8_t offset);
  bool cricket_volume(int8_t offset);
  bool cricket_propi(const char *name, int64_t *result);
  bool cricket_play_index(uint16_t index);
]])

local C = ffi.load("/srv/playground/cricket.nvim/zig-out/lib/libcricket.so", false)

do
  local playlist = string.format("%s/.local/state/nvim/cricket/%s", assert(os.getenv("HOME")), "Lana Del Rey - Norman Fucking Rockwell! (2019) [flac]")

  assert(C.cricket_init())

  local ok, err = xpcall(function()
    assert(C.cricket_playlist_switch(playlist))

    do
      local buf = ffi.new("char[?]", 4096)
      assert(C.cricket_prop_filename(buf))
      print("filename", ffi.string(buf))
      os.execute("sleep 2")
    end

    -- assert(C.cricket_toggle("pause"))
    -- print("paused")
    -- os.execute("sleep 2")

    -- assert(C.cricket_toggle("pause"))
    -- print("unpaused")
    -- os.execute("sleep 2")

    -- assert(C.cricket_toggle("mute"))
    -- print("muted")
    -- os.execute("sleep 2")

    -- assert(C.cricket_toggle("mute"))
    -- print("unmuted")
    -- os.execute("sleep 2")

    -- assert(C.cricket_seek(5))
    -- print("+5s")
    -- os.execute("sleep 2")

    -- assert(C.cricket_seek(-5))
    -- print("-5s")
    -- os.execute("sleep 2")

    -- os.execute("sleep 2")
    -- for _ = 1, 5 do
    --   assert(C.cricket_volume(-10))
    --   do
    --     local volume = ffi.new("int64_t[1]")
    --     assert(C.cricket_propi("volume", volume))
    --     print("vol", tonumber(volume[0]))
    --   end
    --   os.execute("sleep 2")
    -- end

    do
      assert(C.cricket_play_index(3))
      local buf = ffi.new("char[?]", 4096)
      assert(C.cricket_prop_filename(buf))
      print("filename", ffi.string(buf))
      os.execute("sleep 10")
    end
  end, debug.traceback)

  C.cricket_quit()

  if not ok then error(err) end
end
