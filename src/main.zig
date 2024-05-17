const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const log = std.log;

pub const log_level: std.log.Level = .info;

const c = @cImport(@cInclude("mpv/client.h"));

var ctx: ?*c.mpv_handle = null;

fn checkError(status: c_int) !void {
    if (status >= 0) return;

    log.debug("mpv API error: {s}", .{c.mpv_error_string(status)});
    return error.API;
}

fn initImpl(props: [*c]const [*c]const u8) !void {
    if (ctx != null) return;

    ctx = c.mpv_create() orelse return error.CreateFailed;
    errdefer quitImpl();

    // no inputs
    try checkError(c.mpv_set_option_string(ctx, "input-default-bindings", "no"));
    try checkError(c.mpv_set_option_string(ctx, "input-vo-keyboard", "no"));
    // headless
    try checkError(c.mpv_set_option_string(ctx, "video", "no"));
    try checkError(c.mpv_set_option_string(ctx, "audio-display", "no"));
    try checkError(c.mpv_set_option_string(ctx, "idle", "yes"));

    {
        var i: usize = 0;
        while (props[i] != 0) : (i += 2) {
            const name = props[i];
            const value = props[i + 1];
            try checkError(c.mpv_set_option_string(ctx, name, value));
        }
    }

    try checkError(c.mpv_initialize(ctx));
}

export fn cricket_init(props: [*c]const [*c]const u8) bool {
    initImpl(props) catch |err| {
        log.debug("{!}", .{err});
        return false;
    };
    return true;
}

fn quitImpl() void {
    if (ctx == null) return;

    c.mpv_terminate_destroy(ctx);
    ctx = null;
}

export fn cricket_quit() bool {
    quitImpl();
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
    const prop = try fmt.bufPrintZ(&prop_buf, "playlist/{d}/filename", .{pos});
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

var toggles = [_]struct { k: []const u8, v: bool }{
    .{ .k = "mute", .v = false },
    .{ .k = "pause", .v = false },
    .{ .k = "loop-playlist", .v = false },
    // todo: loop-playlist and loop-file should be mutual exclusive
    .{ .k = "loop-file", .v = false },
};

fn findToggleIndex(key: []const u8) ?usize {
    for (toggles, 0..) |t, idx| {
        if (!mem.eql(u8, t.k, key)) continue;
        return idx;
    }
    return null;
}

fn toggleImpl(what: [*:0]const u8) !void {
    if (ctx == null) return error.InitRequired;

    const ti = findToggleIndex(mem.span(what)) orelse return error.InvalidToggle;

    var cmd = [_:null]?[*:0]const u8{ "cycle-values", what, "yes", "no", null };
    try checkError(c.mpv_command(ctx, &cmd));

    toggles[ti].v = !toggles[ti].v;
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
    .{"playlist-pos"}, // starts from 0; -1 when unavailable
    .{"playlist-count"},
});

fn propiImpl(cname: [*:0]const u8, result: *i64) !void {
    if (ctx == null) return error.InitRequired;

    // try toggles first
    if (findToggleIndex(mem.span(cname))) |ti| {
        result.* = @intFromBool(toggles[ti].v);
        return;
    }

    if (!allowed_propis.has(mem.span(cname))) return error.InvalidPropi;
    try checkError(c.mpv_get_property(ctx, cname, c.MPV_FORMAT_INT64, result));
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
