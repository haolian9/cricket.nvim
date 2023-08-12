local ffi = require("ffi")

ffi.cdef([[
  bool cricket_init(void);
  void cricket_destroy(void);
  bool cricket_playlist_switch(const char *path);
  bool cricket_quit(void);
]])

local C = ffi.load("/srv/playground/cricket.nvim/zig-out/lib/libcricket.so", false)

do
  assert(C.cricket_init())
  assert(C.cricket_playlist_switch("/tmp/library/playlist"))

  os.execute("sleep 9999")
end
