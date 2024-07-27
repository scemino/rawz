const std = @import("std");
const ig = @import("cimgui");
const sokol = @import("sokol");
const simgui = sokol.imgui;
const sg = sokol.gfx;

const UI_DELETE_STACK_SIZE = 32;

const state = struct {
    const DeleteStack = struct {
        images: [UI_DELETE_STACK_SIZE]simgui.Image = [1]simgui.Image{.{}} ** UI_DELETE_STACK_SIZE,
        cur_slot: usize = 0,
    };
    var delete_stack: DeleteStack = .{};
};

// draw an 16-bit hex text input field
pub fn ui_util_input_u16(label: [:0]const u8, value: u16) u16 {
    var val = value;
    var buf: [5:0]u8 = undefined;
    inline for (0..4) |i| {
        buf[i] = "0123456789ABCDEF"[val >> ((3 - i) * 4) & 0xF];
    }
    buf[4] = 0;
    const flags = ig.ImGuiInputTextFlags_CharsHexadecimal | ig.ImGuiInputTextFlags_CharsUppercase | ig.ImGuiInputTextFlags_EnterReturnsTrue;
    ig.igPushItemWidth(38);
    defer ig.igPopItemWidth();
    if (ig.igInputText(label, &buf, buf.len, flags, null, null)) {
        val = std.fmt.parseInt(u16, &buf, 16) catch return val;
    }
    return val;
}

pub fn createTexture(w: i32, h: i32, sampler: sg.Sampler) ?*anyopaque {
    return simgui.imtextureid(simgui.makeImage(.{
        .image = sg.makeImage(.{
            .width = w,
            .height = h,
            .usage = sg.Usage.STREAM,
            .pixel_format = sg.PixelFormat.RGBA8,
        }),
        .sampler = sampler,
    }));
}

pub fn destroyTexture(h: ?*anyopaque) void {
    if (state.delete_stack.cur_slot < UI_DELETE_STACK_SIZE) {
        state.delete_stack.images[state.delete_stack.cur_slot] = simgui.imageFromImtextureid(h);
        state.delete_stack.cur_slot += 1;
    }
}

pub fn updateTexture(h: ?*anyopaque, data: ?*anyopaque, data_byte_size: usize) void {
    const img = simgui.imageFromImtextureid(h);
    const desc = simgui.queryImageDesc(img);
    var img_data: sg.ImageData = .{};
    img_data.subimage[0][0] = .{ .ptr = data, .size = data_byte_size };
    sg.updateImage(desc.image, img_data);
}

pub fn hsv(h: f32, s: f32, v: f32) ig.ImColor {
    var color: ig.ImColor = undefined;
    ig.ImColor_HSV(&color, h, s, v, 1.0);
    return color;
}

pub fn convertSize(buf: []u8, size: u32) [*c]const u8 {
    const buf2 = std.fmt.bufPrintZ(buf, "{:.2}", .{std.fmt.fmtIntSizeBin(size)}) catch @panic("failed to format");
    return @ptrCast(buf2);
}
