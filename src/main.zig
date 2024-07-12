const std = @import("std");
const ig = @import("cimgui");
const sokol = @import("sokol");
const raw = @import("raw.zig");
const time = @import("time.zig");
const gfx = @import("gfx.zig");
const prof = @import("prof.zig");
const audio = @import("audio.zig");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;

const state = struct {
    const GameOptions = struct {
        part_num: raw.GamePart = .intro,
        use_ega: bool = false,
        lang: raw.GameLang = .us,
        enable_protection: bool = false,
    };

    var ready: bool = false;
    var data: raw.GameData = .{};
    var options: GameOptions = .{};
    var game: raw.Game = undefined;
    var frame_time_us: u32 = 0;
};

export fn init() void {
    audio.init(.{});
    prof.init();
    time.init();
    raw.game_init(&state.game, .{
        .audio = .{
            .sample_rate = audio.sampleRate(),
            .callback = audio.push,
        },
        .part_num = state.options.part_num,
        .use_ega = state.options.use_ega,
        .enable_protection = state.options.enable_protection,
        .lang = state.options.lang,
        .data = .{
            .banks = .{
                .bank0D = @embedFile("data/pc_demo/BANK0D"),
                .bank01 = @embedFile("data/pc_demo/BANK01"),
                .bank02 = @embedFile("data/pc_demo/BANK02"),
                .bank05 = @embedFile("data/pc_demo/BANK05"),
                .bank06 = @embedFile("data/pc_demo/BANK06"),
            },
            .mem_list = @embedFile("data/pc_demo/MEMLIST.BIN"),
            .demo3_joy = @embedFile("data/pc_demo/DEMO3.JOY"),
        },
    }) catch |e| {
        std.log.err("Game init failed: {}", .{e});
        return;
    };

    // initialize sokol-gfx
    gfx.init(.{
        .border = gfx.DEFAULT_BORDER,
        .display = raw.displayInfo(&state.game),
        .pixel_aspect = .{ .width = 2, .height = 2 },
    });
    // initialize sokol-imgui
    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });
}

export fn frame() void {
    state.frame_time_us = time.frameTime();
    prof.pushMicroSeconds(.FRAME, state.frame_time_us);

    // call simgui.newFrame() before any ImGui calls
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });

    //=== UI CODE STARTS HERE
    ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once, .{ .x = 0, .y = 0 });
    ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
    _ = ig.igBegin("GFX", 0, ig.ImGuiWindowFlags_None);
    for (0..16) |i| {
        const color = ig.ImColor_ImColor_U32(@as(c_uint, state.game.gfx.palette[i]));
        ig.igPushID_Int(@intCast(i));
        _ = ig.igColorEdit3("", &color.*.Value.x, ig.ImGuiColorEditFlags_NoInputs);
        ig.igSameLine(0, 0);
        ig.igPopID();
    }
    ig.igNewLine();

    // var buf: [3 * raw.GAME_WIDTH]u8 = undefined;
    // for (0..raw.GAME_HEIGHT) |y| {
    //     var i: usize = 0;
    //     for (0..raw.GAME_WIDTH) |x| {
    //         const b = state.game.gfx.fb[y * raw.GAME_WIDTH + x];
    //         _ = std.fmt.bufPrint(buf[i .. i + 3], "{X:0>2} ", .{b}) catch @panic("fb failed to print");
    //         i += 3;
    //     }
    //     ig.igText(buf[0..]);
    // }
    ig.igEnd();
    //=== UI CODE ENDS HERE

    // call simgui.render() inside a sokol-gfx pass
    time.emuStart();
    raw.game_exec(&state.game, state.frame_time_us / 1000) catch @panic("gameexec failed");
    prof.pushMicroSeconds(.EMU, time.emuEnd());
    // simgui.render();

    gfx.draw(.{
        .display = raw.displayInfo(&state.game),
        .status = .{
            .name = "RAW zig",
            .num_ticks = 0,
            .frame_stats = prof.stats(.FRAME),
            .emu_stats = prof.stats(.EMU),
        },
    });
}

export fn cleanup() void {
    simgui.shutdown();
    sg.shutdown();
}

export fn event(ev: [*c]const sapp.Event) void {
    // forward input events to sokol-imgui
    _ = simgui.handleEvent(ev.*);
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .window_title = "RAW zig",
        .width = 800,
        .height = 600,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}
