const std = @import("std");
const clap = @import("clap");
const ig = @import("cimgui");
const sokol = @import("sokol");
const raw = @import("raw/raw.zig");
const time = @import("common/time.zig");
const gfx = @import("common/gfx.zig");
const prof = @import("common/prof.zig");
const audio = @import("common/audio.zig");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;

pub const std_options = .{
    // Set the log level to info
    .log_level = .debug,
    // Define logFn to override the std implementation
    .logFn = gameLogFn,
};

pub fn gameLogFn(comptime level: std.log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const scope_prefix = "(" ++ switch (scope) {
        // choose the debug channels by changing this:
        .video, .vm, .sound, .bank, std.log.default_log_scope => @tagName(scope),
        // std.log.default_log_scope => @tagName(scope),
        else => return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

const state = struct {
    const GameOptions = struct {
        part_num: u16 = 16001,
        use_ega: bool = false,
        lang: raw.GameLang = .us,
        enable_protection: bool = false,
        fullscreen: bool = false,
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
    raw.gameInit(&state.game, .{
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
    sapp.setWindowTitle(state.game.title);

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
    ig.igEnd();
    //=== UI CODE ENDS HERE

    // call simgui.render() inside a sokol-gfx pass
    time.emuStart();
    raw.gameExec(&state.game, state.frame_time_us / 1000) catch @panic("gameexec failed");
    prof.pushMicroSeconds(.EMU, time.emuEnd());

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
    switch (ev.*.type) {
        .CHAR => {
            const c = ev.*.char_code;
            if ((c > 0x20) and (c < 0x7F)) {
                raw.gameCharPressed(&state.game, @truncate(c));
            }
        },
        .KEY_DOWN, .KEY_UP => {
            const input: ?raw.GameInput = switch (ev.*.key_code) {
                .LEFT => .left,
                .RIGHT => .right,
                .DOWN => .down,
                .UP => .up,
                .ENTER => .action,
                .SPACE => .action,
                .ESCAPE => .back,
                .F => .back,
                .C => .code,
                .P => .pause,
                else => null,
            };
            if (input) |key| {
                const gameKeyFunc = if (ev.*.type == .KEY_DOWN) &raw.gameKeyDown else &raw.gameKeyUp;
                gameKeyFunc(&state.game, key);
            }
        },
        else => {},
    }
}

pub fn main() void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-p, --part <PART>      Game part to start from (0-35 or 16001-16009)
        \\-e, --ega              Use EGA palette with DOS version
        \\-l, --lang <LANG>      Language (fr,us)
        \\--protec               Enable game protection
        \\--fullscreen           Start in fullscreen mode
        \\
    );

    const parsers = comptime .{
        .LANG = clap.parsers.string,
        .PART = clap.parsers.int(usize, 10),
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return;
    };
    defer res.deinit();

    // args to options
    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{}) catch return;
    if (res.args.part) |part|
        state.options.part_num = @intCast(part);
    if (res.args.lang) |lang|
        state.options.lang = if (std.mem.eql(u8, lang, "us")) .us else .fr;
    state.options.use_ega = res.args.ega != 0;
    state.options.enable_protection = res.args.protec != 0;
    state.options.fullscreen = res.args.fullscreen != 0;

    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .fullscreen = state.options.fullscreen,
        .event_cb = event,
        .window_title = "RAW zig",
        .width = 640,
        .height = 400,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}
