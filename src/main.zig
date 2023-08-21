const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const fmt = std.fmt;
const os = std.os;
const fs = std.fs;
const linux = std.os.linux;
const log = std.log;
const assert = std.debug.assert;

pub const log_level: std.log.Level = .info;

const c = @cImport(@cInclude("mpv/client.h"));

var ctx: ?*c.mpv_handle = null;

fn checkError(status: c_int) !void {
    if (status >= 0) return;

    log.debug("mpv API error: {s}", .{c.mpv_error_string(status)});
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
    try checkError(c.mpv_set_option_string(ctx, "idle", "yes"));

    try checkError(c.mpv_initialize(ctx));
}

export fn cricket_init() bool {
    initImpl() catch |err| {
        log.debug("{!}", .{err});
        return false;
    };
    return true;
}

fn quitImpl() !void {
    if (ctx == null) return;

    var cmd = [_:null]?[*:0]const u8{ "quit", null };
    checkError(c.mpv_command(ctx, &cmd)) catch {};

    c.mpv_terminate_destroy(ctx);
    ctx = null;
}

export fn cricket_quit() bool {
    quitImpl() catch |err| {
        log.debug("quit {!}", .{err});
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
        log.debug("playlist-switch {!}", .{err});
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
        log.debug("{s} {!}", .{ subcmd, err });
        return false;
    };
    return true;
}

fn propFilenameImpl() ![*c]u8 {
    if (ctx == null) return error.InitRequired;

    var pos: i64 = undefined;
    try checkError(c.mpv_get_property(ctx, "playlist-pos", c.MPV_FORMAT_INT64, &pos));

    var prop_buf: [32]u8 = undefined;
    const prop = try std.fmt.bufPrintZ(&prop_buf, "playlist/{d}/filename", .{pos});
    return c.mpv_get_property_string(ctx, prop.ptr);
}

/// caller should free the returned filename eventually
export fn cricket_prop_filename() [*c]u8 {
    return propFilenameImpl() catch |err| {
        log.debug("{!}", .{err});
        return null;
    };
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
        log.debug("{!}", .{err});
        return false;
    };
    return true;
}

const allowed_toggles = std.ComptimeStringMap(void, .{
    .{"mute"},
    .{"pause"},
    .{"loop-playlist"},
});

var loop: bool = false; // a workaround to record loop-times since mpv does not expose it based on loop-playlist

fn toggleImpl(what: [*:0]const u8) !void {
    if (ctx == null) return error.InitRequired;
    if (!allowed_toggles.has(mem.span(what))) return error.InvalidToggle;

    var cmd = [_:null]?[*:0]const u8{ "cycle-values", what, "yes", "no", null };
    try checkError(c.mpv_command(ctx, &cmd));

    if (mem.eql(u8, mem.span(what), "loop-playlist")) loop = !loop;
}

export fn cricket_toggle(what: [*:0]const u8) bool {
    toggleImpl(what) catch |err| {
        log.debug("{!}", .{err});
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

/// offset: percent
export fn cricket_volume(offset: i8) bool {
    volumeImpl(offset) catch |err| {
        log.debug("{!}", .{err});
        return false;
    };
    return true;
}

const allowed_propis = std.ComptimeStringMap(void, .{
    .{"volume"}, // 0-100 percent
    .{"duration"}, // Duration of the current file in seconds
    .{"percent-pos"}, // 0-100; Position in current file (0-100)
    .{"loop-times"}, // -1 or 1
    .{"playlist-pos"}, // starts from 0
    .{"playlist-count"},
});

fn propiImpl(name: [*:0]const u8, result: *i64) !void {
    if (ctx == null) return error.InitRequired;
    if (!allowed_propis.has(mem.span(name))) return error.InvalidPropi;

    var val: i64 = undefined;
    if (mem.eql(u8, mem.span(name), "loop-times")) {
        val = if (loop) -1 else 1;
    } else {
        try checkError(c.mpv_get_property(ctx, name, c.MPV_FORMAT_INT64, &val));
    }
    result.* = val;
}

export fn cricket_propi(name: [*:0]const u8, result: *i64) bool {
    propiImpl(name, result) catch |err| {
        log.debug("{!}", .{err});
        return false;
    };
    return true;
}

fn playIndexImpl(index: u16) !void {
    if (ctx == null) return error.InitRequired;

    var buf: [8]u8 = undefined;
    const str = try fmt.bufPrintZ(&buf, "{d}", .{index});
    var cmd = [_:null]?[*:0]const u8{ "playlist-play-index", str, null };
    try checkError(c.mpv_command(ctx, &cmd));
}

export fn cricket_play_index(index: u16) bool {
    playIndexImpl(index) catch |err| {
        log.debug("{!}", .{err});
        return false;
    };
    return true;
}

fn propPlaylistImpl() ![*c]u8 {
    if (ctx == null) return error.InitRequired;

    // if (false) { var node: c.mpv_node = undefined; try checkError(c.mpv_get_property(ctx, "playlist", c.MPV_FORMAT_NODE, &node)); defer c.mpv_free_node_contents(&node); assert(node.format == c.MPV_FORMAT_NODE_ARRAY); var list = node.u.list.*.values; const list_end = list + @intCast(usize, node.u.list.*.num); while (list < list_end) : (list += 1) { const map: c.mpv_node_list = list.*.u.list.*; var keys = map.keys; var values = map.values; const keys_end = keys + @intCast(usize, map.num); while (keys < keys_end) : ({ keys += 1; values += 1; }) { const k = mem.span(keys.*); const v = values.*.u; if (mem.eql(u8, k, "filename")) { log.info("filename: {s}", .{v.string}); } else if (mem.eql(u8, k, "current")) { log.info("current? {d}", .{v.flag}); } } } }
    return c.mpv_get_property_string(ctx, "playlist");
}

/// caller should free the returned filename eventually
export fn cricket_prop_playlist() [*c]u8 {
    return propPlaylistImpl() catch |err| {
        log.debug("{!}", .{err});
        return null;
    };
}

export fn cricket_free(ptr: ?*anyopaque) void {
    if (ptr == null) return;
    c.mpv_free(ptr);
}
