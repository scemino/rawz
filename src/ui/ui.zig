const std = @import("std");
const sokol = @import("sokol");
const simgui = sokol.imgui;
const slog = sokol.log;
const sapp = sokol.app;
const sg = sokol.gfx;
const ig = @import("cimgui");
const raw = @import("../raw/raw.zig");
const Disasm = @import("Disasm.zig");
const Video = @import("Video.zig");
const raw_dasm = @import("ui_rawdasm.zig");
const util = @import("ui_util.zig");

const Desc = struct {
    game: *raw.game.Game,
};

const ResStat = struct {
    uncompressed_total: u32 = 0,
    compressed_total: u32 = 0,
};

const Res = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    w: f32 = 0.0,
    h: f32 = 0.0,
    open: bool = true,

    filters: [7]bool = [1]bool{false} ** 7, // filter for each resource types
    stats: [8]ResStat = [1]ResStat{.{}} ** 8, // stats for each resource types
};

const state = struct {
    var game: *raw.game.Game = undefined;
    var res: Res = .{};
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
    updateStats();
    var da_desc: Disasm.Desc = .{
        .title = "Disassembler",
        .read_cb = _ui_raw_dasm_read,
        .dasm_op_cb = ui_dasm_op,
        .user_data = desc.game,
    };
    da_desc.layers[0] = "Script";
    state.dasm = Disasm.init(da_desc);
    state.video = Video.init(.{ .game = desc.game });
}

pub fn ui_dasm_op(layer: usize, pc: u16, in_cb: Disasm.ui_dasm_input_t, out_cb: Disasm.ui_dasm_output_t, user_data: ?*anyopaque) u16 {
    _ = layer;
    return raw_dasm.disasmOp(pc, in_cb, out_cb, _ui_raw_getstr, user_data);
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
    drawRes();
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

fn _ui_raw_dasm_read(layer: usize, addr: u16, valid: *bool, user_data: ?*anyopaque) u8 {
    _ = layer;
    _ = user_data;
    valid.* = false;
    if (addr >= 0 and addr < state.game.res.seg_code.len) {
        valid.* = true;
        return state.game.res.seg_code[addr];
    }
    return 0;
}

fn _ui_raw_getstr(id: u16, user_data: ?*anyopaque) []const u8 {
    _ = user_data;
    return state.game.strings_table.find(id);
}

fn convertSize(buf: []u8, size: u32) [*c]const u8 {
    const suffix = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var s = size;
    var dblBytes: f32 = @floatFromInt(size);
    var i: usize = 0;
    if (s > 1024) {
        while ((s / 1024) > 0 and (i < suffix.len)) {
            dblBytes = @as(f32, @floatFromInt(s)) / 1024.0;
            s = s / 1024;
            i += 1;
        }
    }
    const buf2 = std.fmt.bufPrintZ(buf, "{d:.2} {s}", .{ dblBytes, suffix[i] }) catch @panic("failed to format");
    return @ptrCast(buf2);
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

pub fn drawRes() void {
    if (!state.res.open) return;
    const labels = [_][*c]const u8{ "Sound", "Music", "Bitmap", "Palette", "Byte code", "Shape", "Bank" };
    ig.igSetNextWindowPos(.{ .x = state.res.x, .y = state.res.y }, ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(.{ .x = state.res.w, .y = state.res.h }, ig.ImGuiCond_Once);
    if (ig.igBegin("Resources", &state.res.open, ig.ImGuiWindowFlags_None)) {
        for (labels, 0..) |label, i| {
            if (i > 0) ig.igSameLine(0, 2);
            ig.igPushID_Int(@intCast(i));
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, hsv(@as(f32, @floatFromInt(i)) / 7.0, 0.6, 0.6).Value);
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_ButtonHovered, hsv(@as(f32, @floatFromInt(i)) / 7.0, 0.7, 0.7).Value);
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_ButtonActive, hsv(@as(f32, @floatFromInt(i)) / 7.0, 0.8, 0.8).Value);
            if (ig.igButton(label, .{})) {
                state.res.filters[i] = !state.res.filters[i];
            }
            ig.igPopStyleColor(3);
            ig.igPopID();
        }

        if (ig.igBeginTable("##resources", 6, ig.ImGuiTableFlags_Resizable | ig.ImGuiTableFlags_NoSavedSettings, .{}, 0)) {
            ig.igTableSetupColumn("#", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableSetupColumn("Type", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableSetupColumn("Bank", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableSetupColumn("Packed Size", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableSetupColumn("Size", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableHeadersRow();

            for (0..state.game.res.num_mem_list) |i| {
                const e = &state.game.res.mem_list[i];
                if (e.status == .uninit) break;

                if (state.res.filters[@intFromEnum(e.type)]) continue;
                if (state.game.res.data.banks.get(e.bank_num - 1) == null) continue;

                ig.igTableNextRow(0, 20.0);
                _ = ig.igTableNextColumn();
                ig.igPushID_Int(@intCast(i));
                var status_text: [256:0]u8 = undefined;
                const status_fmt: []const u8 = std.fmt.bufPrintZ(&status_text, "{X:0>2}", .{i}) catch @panic("format failed");
                _ = ig.igSelectable_Bool(@ptrCast(status_fmt), false, ig.ImGuiSelectableFlags_SpanAllColumns, .{});
                _ = ig.igTableNextColumn();
                ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_FramePadding, .{});
                _ = ig.igColorButton("##color", hsv(@as(f32, @floatFromInt(@intFromEnum(e.type))) / 7.0, 0.6, 0.6).Value, ig.ImGuiColorEditFlags_NoTooltip, .{});
                ig.igSameLine(0, -1);
                ig.igText("%s", labels[@intFromEnum(e.type)]);
                ig.igPopStyleVar(1);

                _ = ig.igTableNextColumn();
                ig.igText("%02X", e.bank_num);
                _ = ig.igTableNextColumn();
                ig.igText("%s", convertSize(&status_text, e.packed_size));
                _ = ig.igTableNextColumn();
                ig.igText("%s", convertSize(&status_text, e.unpacked_size));
                ig.igPopID();
            }
            ig.igEndTable();
        }
        ig.igSeparator();

        // stats
        if (ig.igBeginTable("##stats", 3, ig.ImGuiTableFlags_Resizable | ig.ImGuiTableFlags_NoSavedSettings, .{}, 0)) {
            ig.igTableSetupColumn("Type", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableSetupColumn("Total Packed Size", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableSetupColumn("Total Size", ig.ImGuiTableColumnFlags_None, 0, 0);
            ig.igTableHeadersRow();
            for (labels, 0..) |label, i| {
                ig.igTableNextRow(0, 20.0);
                _ = ig.igTableNextColumn();
                ig.igText("%s", label);
                _ = ig.igTableNextColumn();
                var status_text: [256:0]u8 = undefined;
                ig.igText("%s", convertSize(&status_text, state.res.stats[i].compressed_total));
                _ = ig.igTableNextColumn();
                ig.igText("%s", convertSize(&status_text, state.res.stats[i].uncompressed_total));
            }
            ig.igTableNextRow(0, 20.0);
            _ = ig.igTableNextColumn();
            ig.igText("Total");
            _ = ig.igTableNextColumn();
            var status_text: [256:0]u8 = undefined;
            ig.igText("%s", convertSize(&status_text, state.res.stats[7].compressed_total));
            _ = ig.igTableNextColumn();
            ig.igText("%s", convertSize(&status_text, state.res.stats[7].uncompressed_total));
            ig.igEndTable();
        }
    }
    ig.igEnd();
}

fn updateStats() void {
    for (0..state.game.res.num_mem_list) |i| {
        const res = &state.game.res.mem_list[i];
        if (res.status == .uninit) break;
        if (state.game.res.data.banks.get(res.bank_num - 1) == null) continue;
        state.res.stats[@intFromEnum(res.type)].compressed_total += res.packed_size;
        state.res.stats[@intFromEnum(res.type)].uncompressed_total += res.unpacked_size;
        state.res.stats[7].compressed_total += res.packed_size;
        state.res.stats[7].uncompressed_total += res.unpacked_size;
    }
}

fn hsv(h: f32, s: f32, v: f32) ig.ImColor {
    var color: ig.ImColor = undefined;
    ig.ImColor_HSV(&color, h, s, v, 1.0);
    return color;
}
