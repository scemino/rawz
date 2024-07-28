const std = @import("std");
const sokol = @import("sokol");
const simgui = sokol.imgui;
const slog = sokol.log;
const sapp = sokol.app;
const sg = sokol.gfx;
const ig = @import("cimgui");
const raw = @import("../raw/raw.zig");
const Disasm = @import("Disasm.zig");
const Res = @import("Res.zig");
const Video = @import("Video.zig");
const Audio = @import("Audio.zig");
const raw_dasm = @import("rawdasm.zig");
const util = @import("util.zig");

const Desc = struct {
    game: *raw.Game,
};

const state = struct {
    var game: *raw.Game = undefined;
    var res: Res = undefined;
    var video: Video = .{};
    var audio: Audio = .{};
    var dasm: Disasm = undefined;
    var layer_names: [8][:0]const u8 = undefined;
};

pub fn init(desc: Desc) void {
    // initialize sokol-imgui
    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });
    state.game = desc.game;
    state.dasm = Disasm.init(.{
        .title = "Disassembler",
        .y = 40,
        .read_cb = readCode,
        .dasm_op_cb = dasmOp,
        .user_data = desc.game,
    });
    state.video = Video.init(.{
        .game = desc.game,
        .x = 120,
        .y = 40,
    });
    state.res = Res.init(.{
        .game = desc.game,
        .x = 120,
        .y = 120,
    });
    state.audio = Audio.init(.{
        .game = desc.game,
        .x = 220,
        .y = 140,
    });
}

pub fn draw() void {
    // call simgui.newFrame() before any ImGui calls
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });

    drawMenu();
    state.res.draw();
    state.video.draw();
    state.dasm.draw();
    state.audio.draw();
}

pub fn handleEvent(ev: [*c]const sapp.Event) bool {
    return simgui.handleEvent(ev.*);
}

pub fn shutdown() void {
    state.video.deinit();
    state.dasm.deinit();
    state.res.deinit();
    simgui.shutdown();
}

fn dasmOp(layer: usize, pc: u16, in_cb: Disasm.ui_dasm_input_t, out_cb: Disasm.ui_dasm_output_t, user_data: ?*anyopaque) u16 {
    _ = layer;
    return raw_dasm.disasmOp(pc, in_cb, out_cb, getStr, user_data);
}

fn readCode(layer: usize, addr: u16, valid: *bool, user_data: ?*anyopaque) u8 {
    _ = layer;
    _ = user_data;
    valid.* = false;
    if (addr >= 0 and addr < state.game.res.seg_code.len) {
        valid.* = true;
        return state.game.res.seg_code[addr];
    }
    return 0;
}

fn getStr(id: u16, user_data: ?*anyopaque) []const u8 {
    _ = user_data;
    return state.game.strings_table.find(id);
}

fn resExists(id: u16) bool {
    return state.game.res.data.banks.get(state.game.res.mem_list[id].bank_num - 1) != null;
}

fn drawMenu() void {
    if (ig.igBeginMainMenuBar()) {
        if (ig.igBeginMenu("System", true)) {
            if (ig.igBeginMenu("Restart at", true)) {
                const parts = [_]raw.GamePart{ .intro, .water, .prison, .cite, .arene, .luxe, .final, .password, .copy_protection };
                const part_names = [_][:0]const u8{ "Intro", "Water", "Prison", "Cite", "Arene", "Luxe", "Final", "Password", "Copy Protection" };
                for (parts, 0..) |part, i| {
                    // check if part exists in the resources
                    const icod = raw.Res.mem_list_parts[@intFromEnum(part) - 16000][1];
                    if (!resExists(icod)) continue;
                    const ivd2 = raw.Res.mem_list_parts[@intFromEnum(part) - 16000][3];
                    if (ivd2 != 0 and !resExists(ivd2)) continue;
                    var part_selected = state.game.res.current_part == part;
                    if (ig.igMenuItem_BoolPtr(part_names[i], 0, &part_selected, true)) {
                        state.game.restartAt(part, -1);
                    }
                }
                ig.igEndMenu();
            }
            ig.igEndMenu();
        }
        if (ig.igBeginMenu("Info", true)) {
            _ = ig.igMenuItem_BoolPtr("Video", 0, &state.video.open, true);
            _ = ig.igMenuItem_BoolPtr("Audio", 0, &state.audio.open, true);
            _ = ig.igMenuItem_BoolPtr("Resource", 0, &state.res.open, true);
            ig.igEndMenu();
        }
        ig.igEndMainMenuBar();
    }
}
