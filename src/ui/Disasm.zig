const std = @import("std");
const assert = std.debug.assert;
const ig = @import("cimgui");
const util = @import("util.zig");

// callback for reading a byte from memory
const ui_dasm_read_t = *const fn (layer: usize, addr: u16, valid: *bool, user_data: ?*anyopaque) u8;
// the input callback type
pub const ui_dasm_input_t = *const fn (user_data: ?*anyopaque) u8;
// the output callback type
pub const ui_dasm_output_t = *const fn (c: u8, user_data: ?*anyopaque) void;
const ui_dasm_op_t = *const fn (layer: usize, pc: u16, in_cb: ui_dasm_input_t, out_cb: ui_dasm_output_t, user_data: ?*anyopaque) u16;

const UI_DASM_MAX_LAYERS = 16;
const UI_DASM_MAX_STRLEN = 32 * 4;
const UI_DASM_MAX_BINLEN = 16;
const UI_DASM_NUM_LINES = 4096;
const UI_DASM_MAX_STACK = 128;

pub const Desc = struct {
    title: [:0]const u8, // window title
    layers: [UI_DASM_MAX_LAYERS]?[:0]const u8 = [1]?[:0]const u8{null} ** UI_DASM_MAX_LAYERS, // memory system layer names
    start_addr: u16 = 0,
    dasm_op_cb: ?ui_dasm_op_t,
    read_cb: ?ui_dasm_read_t = null,
    user_data: ?*anyopaque = null,
    x: f32 = 0.0,
    y: f32 = 0.0, // initial window pos
    w: f32 = 200.0,
    h: f32 = 200.0, // initial window size or 0 for default size
    open: bool = true, // initial open state
};

title: [:0]const u8,
read_cb: ?ui_dasm_read_t = null,
dasm_op_cb: ?ui_dasm_op_t = null,
cur_layer: usize = 0,
num_layers: usize = 0,
layers: [UI_DASM_MAX_LAYERS]?[:0]const u8 = [1]?[:0]const u8{null} ** UI_DASM_MAX_LAYERS,
user_data: ?*anyopaque = null,
init_x: f32 = 0.0,
init_y: f32 = 0.0,
init_w: f32 = 200.0,
init_h: f32 = 200.0,
open: bool = false,
valid: bool = false,
start_addr: u16 = 0,
cur_addr: u16 = 0,
str_pos: usize = 0,
str_buf: [UI_DASM_MAX_STRLEN:0]u8,
bin_pos: usize = 0,
bin_buf: [UI_DASM_MAX_BINLEN:0]u8,
stack_num: usize = 0,
stack_pos: usize = 0,
stack: [UI_DASM_MAX_STACK]u16,
highlight_addr: u16 = 0,
highlight_color: u32 = 0,
const Self = @This();

pub fn init(desc: Desc) Self {
    // GAME_ASSERT(win && desc);
    assert(desc.title.len > 0);
    var win: Self = undefined;
    win = std.mem.zeroes(@TypeOf(win));
    win.title = desc.title;
    win.read_cb = desc.read_cb;
    win.dasm_op_cb = desc.dasm_op_cb;
    win.start_addr = desc.start_addr;
    win.user_data = desc.user_data;
    win.init_x = desc.x;
    win.init_y = desc.y;
    win.init_w = if (desc.w == 0) 400 else desc.w;
    win.init_h = if (desc.h == 0) 256 else desc.h;
    win.open = desc.open;
    win.highlight_color = 0xFF30FF30;
    for (0..UI_DASM_MAX_LAYERS) |i| {
        if (desc.layers[i]) |layer| {
            win.num_layers += 1;
            win.layers[i] = layer;
        } else {
            break;
        }
    }
    win.valid = true;
    return win;
}

pub fn draw(win: *Self) void {
    assert(win.valid and win.title.len > 0);
    if (!win.open) {
        return;
    }
    ig.igSetNextWindowPos(.{ .x = win.init_x, .y = win.init_y }, ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(.{ .x = win.init_w, .y = win.init_h }, ig.ImGuiCond_Once);
    if (ig.igBegin(win.title, &win.open, ig.ImGuiWindowFlags_None)) {
        _ui_dasm_draw_stack(win);
        ig.igSameLine(0, -1.0);
        _ui_dasm_draw_disasm(win);
    }
    ig.igEnd();
}

pub fn deinit(win: *Self) void {
    assert(win.valid);
    win.valid = false;
}

// disassembler callback to fetch the next instruction byte
fn _ui_dasm_in_cb(user_data: ?*anyopaque) u8 {
    if (user_data) |data| {
        const win: *Self = @alignCast(@ptrCast(data));
        var valid: bool = undefined;
        if (win.read_cb) |read_cb| {
            const val: u8 = read_cb(win.cur_layer, win.cur_addr, &valid, win.user_data);
            win.cur_addr += 1;
            if (!valid) return 0;
            if (win.bin_pos < UI_DASM_MAX_BINLEN) {
                win.bin_buf[win.bin_pos] = val;
                win.bin_pos += 1;
            }
            return val;
        }
        return 0;
    }
    unreachable;
}

// disassembler callback to output a character
fn _ui_dasm_out_cb(c: u8, user_data: ?*anyopaque) void {
    if (user_data) |data| {
        const win: *Self = @alignCast(@ptrCast(data));
        if ((win.str_pos + 1) < UI_DASM_MAX_STRLEN) {
            win.str_buf[win.str_pos] = c;
            win.str_pos += 1;
            win.str_buf[win.str_pos] = 0;
        }
    }
}

// disassemble the next instruction
fn _ui_dasm_disasm(win: *Self) void {
    win.str_pos = 0;
    win.bin_pos = 0;
    if (win.dasm_op_cb) |dasm_op_cb| {
        _ = dasm_op_cb(win.cur_layer, win.cur_addr, _ui_dasm_in_cb, _ui_dasm_out_cb, win);
    }
}

fn _ui_dasm_jumptarget(win: *Self, pc: u16, out_addr: *u16) bool {
    _ = pc;
    switch (win.bin_buf[0]) {
        0x04, // jsr
        0x07, // jmp
        => {
            out_addr.* = win.bin_buf[2] | @as(u16, @intCast(win.bin_buf[1])) << 8;
            return true;
        },
        0x08, // setvec
        => {
            out_addr.* = win.bin_buf[3] | @as(u16, @intCast(win.bin_buf[2])) << 8;
            return true;
        },
        0x09, // if var
        => {
            out_addr.* = win.bin_buf[3] | @as(u16, @intCast(win.bin_buf[2])) << 8;
            return true;
        },
        0x0a, // if exp
        => {
            const op = win.bin_buf[1];
            const off: u8 = if ((op & 0x40) != 0) 5 else 4;
            out_addr.* = win.bin_buf[off + 1] | @as(u16, @intCast(win.bin_buf[off])) << 8;
            return true;
        },
        else => return false,
    }
}

// push an address on the bookmark stack
fn _ui_dasm_stack_push(win: *Self, addr: u16) void {
    if (win.stack_num < UI_DASM_MAX_STACK) {
        // ignore if the same address is already on top of stack
        if ((win.stack_num > 0) and (addr == win.stack[win.stack_num - 1])) {
            return;
        }
        win.stack_pos = win.stack_num;
        win.stack[win.stack_num] = addr;
        win.stack_num += 1;
    }
}

// return current address on stack, and set pos to previous
fn _ui_dasm_stack_back(win: *Self, addr: *u16) bool {
    if (win.stack_num > 0) {
        addr.* = win.stack[win.stack_pos];
        if (win.stack_pos > 0) {
            win.stack_pos -= 1;
        }
        return true;
    }
    addr.* = 0;
    return false;
}

// goto to address, op address on stack
fn _ui_dasm_goto(win: *Self, addr: u16) void {
    win.start_addr = addr;
}

// /* draw the address entry field and layer combo */
fn _ui_dasm_draw_controls(win: *Self) void {
    win.start_addr = util.ui_util_input_u16("##addr", win.start_addr);
    ig.igSameLine(0, -1.0);
    var addr: u16 = 0;
    if (ig.igArrowButton("##back", ig.ImGuiDir_Left)) {
        if (_ui_dasm_stack_back(win, &addr)) {
            _ui_dasm_goto(win, addr);
        }
    }
    if (ig.igIsItemHovered(ig.ImGuiHoveredFlags_None) and (win.stack_num > 0)) {
        ig.igSetTooltip("Goto %04X", win.stack[win.stack_pos]);
    }
    ig.igSameLine(0, -1.0);
    ig.igSameLine(0, -1.0);
    var region: ig.ImVec2 = undefined;
    ig.igGetContentRegionAvail(&region);
    ig.igPushItemWidth(region.x);
    var cur_layer: c_int = @intCast(win.cur_layer);
    if (ig.igCombo_Str_arr("##layer", &cur_layer, @ptrCast(&win.layers), @intCast(win.num_layers), -1)) {
        win.cur_layer = @intCast(cur_layer);
    }
    ig.igPopItemWidth();
}

// draw the disassembly column
fn _ui_dasm_draw_disasm(win: *Self) void {
    _ = ig.igBeginChild_Str("##dasmbox", .{}, ig.ImGuiChildFlags_Border, ig.ImGuiWindowFlags_None);
    _ui_dasm_draw_controls(win);

    _ = ig.igBeginChild_Str("##dasm", .{}, ig.ImGuiChildFlags_None, ig.ImGuiWindowFlags_None);
    ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_FramePadding, .{});
    ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ItemSpacing, .{});
    const line_height: f32 = ig.igGetTextLineHeight();
    var glyph_size: ig.ImVec2 = undefined;
    ig.igCalcTextSize(&glyph_size, "F", null, false, 0.0);
    const cell_width: f32 = 3 * glyph_size.x;
    var clipper = ig.ImGuiListClipper{};
    ig.ImGuiListClipper_Begin(&clipper, UI_DASM_NUM_LINES, line_height);
    _ = ig.ImGuiListClipper_Step(&clipper);

    // skip hidden lines
    win.cur_addr = win.start_addr;
    const min_line: usize = @max(0, @min(@as(isize, @intCast(clipper.DisplayStart)), UI_DASM_NUM_LINES));
    for (0..min_line) |_| {
        _ui_dasm_disasm(win);
    }

    // visible items
    for (@intCast(clipper.DisplayStart)..@intCast(clipper.DisplayEnd)) |line_i| {
        const op_addr = win.cur_addr;
        _ui_dasm_disasm(win);
        const num_bytes = win.bin_pos;
        if (num_bytes == 0) break;

        // highlight current hovered address
        var highlight = false;
        if (win.highlight_addr == op_addr) {
            ig.igPushStyleColor_U32(ig.ImGuiCol_Text, win.highlight_color);
            highlight = true;
        }

        // address
        ig.igText("%04X: ", op_addr);
        ig.igSameLine(0, -1.0);

        // instruction bytes
        const line_start_x: f32 = ig.igGetCursorPosX();
        for (0..num_bytes) |n| {
            ig.igSameLine(line_start_x + cell_width * @as(f32, @floatFromInt(n)), -1.0);
            ig.igText("%02X ", win.bin_buf[n]);
        }

        // disassembled instruction
        ig.igSameLine(line_start_x + cell_width * 8.0 + glyph_size.x * 2.0, -1.0);
        ig.igText("%s", &win.str_buf);

        if (highlight) {
            ig.igPopStyleColor(1);
        }

        // check for jump instruction and draw an arrow
        var jump_addr: u16 = 0;
        if (_ui_dasm_jumptarget(win, win.cur_addr, &jump_addr)) {
            ig.igSameLine(line_start_x + cell_width * 8 + glyph_size.x * 2 + glyph_size.x * 26, -1.0);
            ig.igPushID_Int(@intCast(line_i));
            if (ig.igArrowButton("##btn", ig.ImGuiDir_Right)) {
                ig.igSetScrollY_Float(0.0);
                _ui_dasm_goto(win, jump_addr);
                _ui_dasm_stack_push(win, op_addr);
            }
            if (ig.igIsItemHovered(ig.ImGuiHoveredFlags_None)) {
                ig.igSetTooltip("Goto %04X", jump_addr);
                win.highlight_addr = jump_addr;
            }
            ig.igPopID();
        }
    }
    ig.ImGuiListClipper_End(&clipper);
    ig.igPopStyleVar(2);
    ig.igEndChild();
    ig.igEndChild();
}

// draw the stack
fn _ui_dasm_draw_stack(win: *Self) void {
    _ = ig.igBeginChild_Str("##stackbox", .{ .x = 72, .y = 0 }, ig.ImGuiChildFlags_Border, ig.ImGuiWindowFlags_None);
    if (ig.igButton("Clear", .{})) {
        win.stack_num = 0;
    }
    var buf: [5]u8 = [1]u8{0} ** 5;
    if (ig.igBeginListBox("##stack", .{ .x = -1, .y = -1 })) {
        for (0..win.stack_num) |i| {
            const buf2 = std.fmt.bufPrintZ(&buf, "{X:0>4}", .{win.stack[i]}) catch @panic("failed to format");
            ig.igPushID_Int(@intCast(i));
            if (ig.igSelectable_Bool(buf2, i == win.stack_pos, ig.ImGuiSelectableFlags_None, .{})) {
                win.stack_pos = i;
                _ui_dasm_goto(win, win.stack[i]);
            }
            if (ig.igIsItemHovered(ig.ImGuiHoveredFlags_None)) {
                ig.igSetTooltip("Goto %04X", win.stack[i]);
                win.highlight_addr = win.stack[i];
            }
            ig.igPopID();
        }
        ig.igEndListBox();
    }
    ig.igEndChild();
}
