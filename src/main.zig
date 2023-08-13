const std = @import("std");
const testing = std.testing;
const log = std.log;
const mem = std.mem;
const fmt = std.fmt;

const c = @cImport(@cInclude("mpv/client.h"));

var ctx: ?*c.mpv_handle = null;

fn checkError(status: c_int) !void {
    if (status >= 0) return;

    log.err("mpv API error: {s}", .{c.mpv_error_string(status)});
    return error.API;
}

fn initImpl() !void {
    if (ctx != null) return;

    ctx = c.mpv_create() orelse return error.CreateFailed;

    // no inputs
    try checkError(c.mpv_set_option_string(ctx, "input-default-bindings", "no"));
    try checkError(c.mpv_set_option_string(ctx, "input-vo-keyboard", "no"));
    try checkError(c.mpv_set_option_string(ctx, "osc", "no"));
    // no ui/window
    try checkError(c.mpv_set_option_string(ctx, "audio-display", "no"));

    try checkError(c.mpv_initialize(ctx));
}

export fn cricket_init() bool {
    initImpl() catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}

fn quitImpl() !void {
    if (ctx == null) return error.InitRequired;

    var cmd = [_:null]?[*:0]const u8{ "quit", null };
    checkError(c.mpv_command(ctx, &cmd)) catch unreachable;

    c.mpv_terminate_destroy(ctx);
    ctx = null;
}

export fn cricket_quit() bool {
    quitImpl() catch |err| {
        log.err("quit {!}", .{err});
        return false;
    };
    return true;
}

fn playlistSwitchImpl(path: [*:0]const u8) !void {
    if (ctx == null) return error.InitRequired;

    var cmd = [_:null]?[*:0]const u8{ "loadlist", path, null };
    try checkError(c.mpv_command(ctx, &cmd));
}

export fn cricket_playlist_switch(path: [*:0]const u8) bool {
    playlistSwitchImpl(path) catch |err| {
        log.err("playlist-switch {!}", .{err});
        return false;
    };
    return true;
}

const allowed_subcmds = std.ComptimeStringMap(void, .{
    .{"playlist-shuffle"},
    .{"playlist-unshuffle"},
    .{"playlist-next"},
    .{"playlist-prev"},
    .{"playlist-clear"},
    .{"stop"}, // Stop playback and clear playlist
});

fn cmd1Impl(subcmd: [*:0]const u8) !void {
    if (ctx == null) return error.InitRequired;
    if (!allowed_subcmds.has(mem.span(subcmd))) return error.InvalidSubcmd;

    var cmd = [_:null]?[*:0]const u8{ subcmd, null };
    try checkError(c.mpv_command(ctx, &cmd));
}

export fn cricket_cmd1(subcmd: [*:0]const u8) bool {
    cmd1Impl(subcmd) catch |err| {
        log.err("{s} {!}", .{ subcmd, err });
        return false;
    };
    return true;
}

fn propFilenameImpl(result: *[4096:0]u8) !void {
    if (ctx == null) return error.InitRequired;

    var pos: i64 = undefined;
    try checkError(c.mpv_get_property(ctx, "playlist-pos", c.MPV_FORMAT_INT64, &pos));

    var prop_buf: [32]u8 = undefined;
    const prop = try std.fmt.bufPrintZ(&prop_buf, "playlist/{d}/filename", .{pos});
    const filename = c.mpv_get_property_string(ctx, prop.ptr);
    defer c.mpv_free(filename);
    if (filename == null) return error.PropUnavailable;
    mem.copy(u8, result, mem.span(filename));
}

export fn cricket_prop_filename(result: *[4096:0]u8) bool {
    propFilenameImpl(result) catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}

fn seekImpl(offset: i8) !void {
    if (ctx == null) return error.InitRequired;
    if (offset == 0) return;
    var buf: [4]u8 = undefined;
    const str = try fmt.bufPrintZ(&buf, "{d:1}", .{offset});
    var cmd = [_:null]?[*:0]const u8{ "seek", str, "relative", null };
    try checkError(c.mpv_command(ctx, &cmd));
}

export fn cricket_seek(offset: i8) bool {
    seekImpl(offset) catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}

const allowed_toggles = std.ComptimeStringMap(void, .{
    .{"mute"},
    .{"pause"},
});

fn toggleImpl(what: [*:0]const u8) !void {
    if (ctx == null) return error.InitRequired;
    if (!allowed_toggles.has(mem.span(what))) return error.InvalidToggle;

    var cmd = [_:null]?[*:0]const u8{ "cycle", what, null };
    try checkError(c.mpv_command(ctx, &cmd));
}

export fn cricket_toggle(what: [*:0]const u8) bool {
    toggleImpl(what) catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}

fn volumeImpl(offset: i8) !void {
    if (ctx == null) return error.InitRequired;
    if (offset == 0) return;
    var buf: [4]u8 = undefined;
    const str = try fmt.bufPrintZ(&buf, "{d:1}", .{offset});
    var cmd = [_:null]?[*:0]const u8{ "add", "volume", str, null };
    try checkError(c.mpv_command(ctx, &cmd));
}

/// offset: percent?
export fn cricket_volume(offset: i8) bool {
    volumeImpl(offset) catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}

fn propiImpl(name: [*:0]const u8, result: *i64) !void {
    if (ctx == null) return error.InitRequired;

    var val: i64 = undefined;
    try checkError(c.mpv_get_property(ctx, name, c.MPV_FORMAT_INT64, &val));
    result.* = val;
}

export fn cricket_propi(name: [*:0]const u8, result: *i64) bool {
    propiImpl(name, result) catch |err| {
        log.err("{!}", .{err});
        return false;
    };
    return true;
}
