local ffi = require("ffi")

ffi.cdef([[
  bool cricket_init(void);
  bool cricket_quit(void);
  bool cricket_playlist_switch(const char *path);
  bool cricket_prop_filename(char result[4096]);
]])

local C = ffi.load("/srv/playground/cricket.nvim/zig-out/lib/libcricket.so", false)

do
  assert(C.cricket_init())

  local ok, err = xpcall(function()
    assert(C.cricket_playlist_switch("/tmp/library/playlist"))
    local buf = ffi.new("char[?]", 4096)
    assert(C.cricket_prop_filename(buf))
    print("filename", ffi.string(buf))
    os.execute("sleep 3")
  end, debug.traceback)

  C.cricket_quit()

  if not ok then error(err) end
end
