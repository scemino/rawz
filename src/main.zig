const std = @import("std");
const clap = @import("clap");
const sokol = @import("sokol");
const slog = sokol.log;
const sapp = sokol.app;
const common = @import("common");
const time = common.time;
const gfx = common.gfx;
const prof = common.prof;
const audio = common.audio;
const raw = @import("raw");
const Game = raw.Game;
const GameLang = Game.GameLang;
const GameInput = Game.GameInput;
const ui = @import("ui/ui.zig");

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
        lang: GameLang = .us,
        enable_protection: bool = false,
        data: ?raw.GameData = null,
    };

    var ready: bool = false;
    var data: raw.GameData = .{};
    var options: GameOptions = .{};
    var game: Game = undefined;
    var frame_time_us: u32 = 0;
};

pub fn defaultPCDemoGameData() raw.GameData {
    return .{
        .banks = .{
            .bank0D = @embedFile("data/pc_demo/BANK0D"),
            .bank01 = @embedFile("data/pc_demo/BANK01"),
            .bank02 = @embedFile("data/pc_demo/BANK02"),
            .bank05 = @embedFile("data/pc_demo/BANK05"),
            .bank06 = @embedFile("data/pc_demo/BANK06"),
        },
        .mem_list = @embedFile("data/pc_demo/MEMLIST.BIN"),
        .demo3_joy = @embedFile("data/pc_demo/DEMO3.JOY"),
    };
}

export fn init() void {
    audio.init(.{});
    prof.init();
    time.init();
    Game.init(&state.game, .{
        .audio = .{
            .sample_rate = audio.sampleRate(),
            .callback = audio.push,
        },
        .part_num = state.options.part_num,
        .use_ega = state.options.use_ega,
        .enable_protection = state.options.enable_protection,
        .lang = state.options.lang,
        .data = state.options.data orelse defaultPCDemoGameData(),
    }) catch |e| {
        std.log.err("Game init failed: {}", .{e});
        return;
    };
    sapp.setWindowTitle(state.game.title);

    // initialize sokol-gfx
    gfx.init(.{
        .border = gfx.DEFAULT_BORDER,
        .display = state.game.displayInfo(),
        .pixel_aspect = .{ .width = 2, .height = 2 },
    });
    ui.init(.{ .game = &state.game });
}

export fn frame() void {
    state.frame_time_us = time.frameTime();
    prof.pushMicroSeconds(.FRAME, state.frame_time_us);

    ui.draw();

    time.emuStart();
    state.game.exec(state.frame_time_us / 1000) catch @panic("gameexec failed");
    prof.pushMicroSeconds(.EMU, time.emuEnd());

    gfx.draw(.{
        .display = state.game.displayInfo(),
        .status = .{
            .frame_stats = prof.stats(.FRAME),
            .emu_stats = prof.stats(.EMU),
        },
    });
}

export fn cleanup() void {
    ui.shutdown();
    gfx.shutdown();
}

export fn event(ev: [*c]const sapp.Event) void {
    // forward input events to sokol-imgui
    _ = ui.handleEvent(ev);
    switch (ev.*.type) {
        .CHAR => {
            const c = ev.*.char_code;
            if ((c > 0x20) and (c < 0x7F)) {
                state.game.charPressed(@truncate(c));
            }
        },
        .KEY_DOWN, .KEY_UP => {
            const input: ?GameInput = switch (ev.*.key_code) {
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
                if (ev.*.type == .KEY_DOWN) {
                    state.game.keyDown(key);
                } else {
                    state.game.keyUp(key);
                }
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
        \\<PATH>                 Path to the game data (directory or tar archive) 
    );

    const parsers = comptime .{
        .LANG = clap.parsers.string,
        .PATH = clap.parsers.string,
        .PART = clap.parsers.int(usize, 10),
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

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

    if (res.positionals.len > 0) {
        const path = res.positionals[0];
        state.options.data = raw.GameData.readData(path, arena.allocator());
    }

    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .fullscreen = res.args.fullscreen != 0,
        .event_cb = event,
        .window_title = "RAW zig",
        .width = 2 * raw.GAME_WIDTH + gfx.DEFAULT_BORDER.left + gfx.DEFAULT_BORDER.right,
        .height = 2 * raw.GAME_HEIGHT + gfx.DEFAULT_BORDER.top + gfx.DEFAULT_BORDER.bottom,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}
