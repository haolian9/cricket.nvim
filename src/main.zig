const std = @import("std");
const testing = std.testing;
const log = std.log;

// * loadlist {playlist}
// * playlist-next/prev, shuffle/unshuffle
// * playlist-clear
// * quit
// * volume up/down
// * mute/unmute

const client = @cImport(@cInclude("mpv/client.h"));

var ctx: ?*client.mpv_handle = null;

fn checkError(status: c_int) !void {
    if (status >= 0) return;

    log.err("mpv API error: {s}", .{client.mpv_error_string(status)});
    return error.API;
}

fn initImpl() !void {
    if (ctx != null) return;

    ctx = client.mpv_create() orelse return error.CreateFailed;

    // no inputs
    try checkError(client.mpv_set_option_string(ctx, "input-default-bindings", "no"));
    try checkError(client.mpv_set_option_string(ctx, "input-vo-keyboard", "no"));
    try checkError(client.mpv_set_option_string(ctx, "osc", "no"));
    // no ui/window
    try checkError(client.mpv_set_option_string(ctx, "audio-display", "no"));

    try checkError(client.mpv_initialize(ctx));
}

export fn cricket_init() bool {
    initImpl() catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}

fn destroyImpl() void {
    if (ctx == null) return;

    client.mpv_terminate_destroy(ctx);
    ctx = null;
}

export fn cricket_destroy() void {
    destroyImpl();
}

fn playlistSwitchImpl(path: [*:0]const u8) !void {
    if (ctx == null) return error.InitRequired;

    // todo: seamless
    { // clear
        var cmd = [_:null]?[*:0]const u8{ "playlist-clear", null };
        try checkError(client.mpv_command(ctx, &cmd));
    }
    {
        var cmd = [_:null]?[*:0]const u8{ "loadlist", path, null };
        try checkError(client.mpv_command(ctx, &cmd));
    }
}

export fn cricket_playlist_switch(path: [*:0]const u8) bool {
    playlistSwitchImpl(path) catch |err| {
        log.err("playlist-switch {!}", .{err});
        return false;
    };
    return true;
}

fn playlistShuffleImpl() !void {
    if (ctx == null) return error.InitRequired;

    //todo: global cmds enum
    var cmd = [_:null]?[*:0]const u8{ "playlist-shuffle", null };
    try checkError(client.mpv_command(ctx, &cmd));
}

export fn cricket_playlist_shuffle() bool {
    playlistShuffleImpl() catch |err| {
        log.err("playlist-shuffle {!}", .{err});
        return false;
    };
    return true;
}

// todo: cricket_cmd0?
fn quitImpl() !void {
    if (ctx == null) return error.InitRequired;

    var cmd = [_:null]?[*:0]const u8{ "quit", null };
    try checkError(client.mpv_command(ctx, &cmd));
    destroyImpl();
}

export fn cricket_quit() bool {
    quitImpl() catch |err| {
        log.err("quit {!}", .{err});
        return false;
    };
    return true;
}
