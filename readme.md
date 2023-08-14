促织

a mpv frontend built with nvim facilities


## features/limits
* run mpv as a daemon
* control mpv over ffi rather than ipc
* first-class playlist, no operations on single track
* every playlist is a file, edit it to change track orders
* it has a rough UI


## status
* it just works (tm)
* it uses ffi which may crash nvim often


## prerequisites
* mpv/libmpv 0.35.1
* nvim 0.9.*
* zig 0.10.*
* haolian9/infra.nvim
* haolian9/kite.nvim


## usage
TBD
