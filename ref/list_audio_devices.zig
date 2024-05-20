const std = @import("std");
const log = std.log;
const mem = std.mem;

const client = @cImport(@cInclude("mpv/client.h"));

fn checkError(status: c_int) !void {
    if (status >= 0) return;

    log.err("mpv API error: {s}", .{client.mpv_error_string(status)});
    return error.API;
}

pub fn main() !void {
    var ctx = client.mpv_create() orelse return error.CreateFailed;
    defer client.mpv_terminate_destroy(ctx);

    {
        // no inputs
        try checkError(client.mpv_set_option_string(ctx, "input-default-bindings", "no"));
        try checkError(client.mpv_set_option_string(ctx, "input-vo-keyboard", "no"));
        try checkError(client.mpv_set_option_string(ctx, "osc", "no"));
        // no ui/window
        try checkError(client.mpv_set_option_string(ctx, "audio-display", "no"));

        // try checkError(client.mpv_set_option_string(ctx, "idle", "yes"));
    }

    try checkError(client.mpv_initialize(ctx));

    if (false) { // --audio-device=help

        // MPV_FORMAT_NODE_ARRAY
        //      MPV_FORMAT_NODE_MAP (for each device entry)
        //          "name"          MPV_FORMAT_STRING
        //          "description"   MPV_FORMAT_STRING

        const stdout = std.io.getStdOut().writer();

        var data: client.mpv_node = undefined;
        try checkError(client.mpv_get_property(ctx, "audio-device-list", client.MPV_FORMAT_NODE, &data));

        const p1: client.mpv_node_list = data.u.list.*;
        for (0..@intCast(p1.num)) |i| {
            const p2: client.mpv_node_list = p1.values[i].u.list.*;
            var offset: usize = 0;
            while (offset < p2.num) : (offset += 2) {
                const key = mem.span(p2.keys[offset]);
                if (!mem.eql(u8, key, "name")) unreachable;

                const dev = mem.span(p2.values[offset].u.string);
                if (!mem.startsWith(u8, dev, "pipewire")) continue;

                const desc = mem.span(p2.values[offset + 1].u.string);
                try stdout.print("device={s}, desc={s}", .{ dev, desc });
            }
        }
    }

    if (true) { // --audio-device=help

        // MPV_FORMAT_NODE_ARRAY
        //      MPV_FORMAT_NODE_MAP (for each device entry)
        //          "name"          MPV_FORMAT_STRING
        //          "description"   MPV_FORMAT_STRING

        // const stdout = std.io.getStdOut().writer();

        // [{name: string, description: string}]
        const adlist = client.mpv_get_property_string(ctx, "volumexxxx");
        defer client.mpv_free(adlist);

        if (adlist == null) return error.NoSuchProp;

        log.debug("{s}", .{adlist});
    }
}

// millet: zig run -lc -lmpv %:p

