const std = @import("std");
const log = std.log;

const client = @cImport(@cInclude("mpv/client.h"));

fn checkError(status: c_int) !void {
    if (status >= 0) return;

    log.err("mpv API error: {s}", .{client.mpv_error_string(status)});
    return error.API;
}

/// see also: mpv-example/libmpv/simple/simple.c
pub fn main() !void {
    const playlist = "/tmp/library/playlist";
    { // ensure the playlist exists
        var file = try std.fs.openFileAbsolute(playlist, .{});
        defer file.close();
    }

    var ctx = client.mpv_create() orelse return error.CreateFailed;
    defer client.mpv_terminate_destroy(ctx);

    {
        // no inputs
        try checkError(client.mpv_set_option_string(ctx, "input-default-bindings", "no"));
        try checkError(client.mpv_set_option_string(ctx, "input-vo-keyboard", "no"));
        try checkError(client.mpv_set_option_string(ctx, "osc", "no"));
        // no ui/window
        try checkError(client.mpv_set_option_string(ctx, "audio-display", "no"));
    }

    try checkError(client.mpv_initialize(ctx));

    {
        var cmd = [_:null]?[*:0]const u8{ "loadlist", playlist, null };
        try checkError(client.mpv_command(ctx, &cmd));
    }

    { // :mpv --input-cmdlist
        var cmd = [_:null]?[*:0]const u8{ "playlist-shuffle", null };
        try checkError(client.mpv_command(ctx, &cmd));
    }

    while (true) {
        const event = client.mpv_wait_event(ctx, 10000);
        if (event == null) continue;
        log.info("event: {s}", .{client.mpv_event_name(event.*.event_id)});
        if (event.*.event_id == client.MPV_EVENT_SHUTDOWN) break;
    }
}

// millet: zig run -lc -lmpv %:p
