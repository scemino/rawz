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
const raw_dasm = @import("ui_rawdasm.zig");
const util = @import("ui_util.zig");

const Desc = struct {
    game: *raw.game.Game,
};

const state = struct {
    var game: *raw.game.Game = undefined;
    var res: Res = undefined;
    var video: Video = .{};
    var dasm: Disasm = undefined;
    var layer_names: [8][:0]const u8 = undefined;
    var nearest_sampler: sg.Sampler = .{};
};

pub fn init(desc: Desc) void {
    // initialize sokol-imgui
    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });
    state.game = desc.game;
    state.nearest_sampler = sg.makeSampler(.{
        .min_filter = sg.Filter.NEAREST,
        .mag_filter = sg.Filter.NEAREST,
        .wrap_u = sg.Wrap.CLAMP_TO_EDGE,
        .wrap_v = sg.Wrap.CLAMP_TO_EDGE,
    });
    for (0..4) |i| {
        state.video.tex_fb[i] = util.createTexture(raw.GAME_WIDTH, raw.GAME_HEIGHT, state.nearest_sampler);
    }
    var da_desc: Disasm.Desc = .{
        .title = "Disassembler",
        .read_cb = ui_raw_dasm_read,
        .dasm_op_cb = ui_dasm_op,
        .user_data = desc.game,
    };
    da_desc.layers[0] = "Script";
    state.dasm = Disasm.init(da_desc);
    state.video = Video.init(.{ .game = desc.game });
    state.res = Res.init(.{ .game = desc.game });
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
}

pub fn handleEvent(ev: [*c]const sapp.Event) bool {
    return simgui.handleEvent(ev.*);
}

pub fn shutdown() void {
    for (0..4) |i| {
        util.destroyTexture(state.video.tex_fb[i]);
    }
    simgui.shutdown();
    state.dasm.deinit();
}

fn ui_dasm_op(layer: usize, pc: u16, in_cb: Disasm.ui_dasm_input_t, out_cb: Disasm.ui_dasm_output_t, user_data: ?*anyopaque) u16 {
    _ = layer;
    return raw_dasm.disasmOp(pc, in_cb, out_cb, ui_raw_getstr, user_data);
}

fn ui_raw_dasm_read(layer: usize, addr: u16, valid: *bool, user_data: ?*anyopaque) u8 {
    _ = layer;
    _ = user_data;
    valid.* = false;
    if (addr >= 0 and addr < state.game.res.seg_code.len) {
        valid.* = true;
        return state.game.res.seg_code[addr];
    }
    return 0;
}

fn ui_raw_getstr(id: u16, user_data: ?*anyopaque) []const u8 {
    _ = user_data;
    return state.game.strings_table.find(id);
}

fn drawMenu() void {
    if (ig.igBeginMainMenuBar()) {
        if (ig.igBeginMenu("Info", true)) {
            _ = ig.igMenuItem_BoolPtr("Video", 0, &state.video.open, true);
            _ = ig.igMenuItem_BoolPtr("Resource", 0, &state.res.open, true);
            ig.igEndMenu();
        }
        ig.igEndMainMenuBar();
    }
}
