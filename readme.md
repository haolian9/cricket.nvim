促织

a mpv frontend built with nvim facilities


## features/limits
* run mpv as a daemon
* control mpv over ffi rather than ipc
* first-class playlist, no single track
* every playlist is a file, edit it to change track orders
* no dedicated UI


## status
* far from usable
* it uses ffi which may crash nvim often


## prerequisites
* mpv/libmpv 0.35.1
* nvim 0.9.*
* zig 0.10.*
* ~~haolian9/cthulhu.nvim~~
* haolian9/infra.nvim
* haolian9/kite.nvim
* haolian9/tui.nvim
