const std = @import("std");
const ig = @import("cimgui");
const raw = @import("raw");
const Video = raw.Video;
const util = @import("util.zig");
const sokol = @import("sokol");
const sg = sokol.gfx;

/// Preview data
const PreviewDataKind = enum {
    /// Represents palette data
    palette,
    /// Represents bitmap data
    bitmap,
    /// Represents sound data
    sound,
};

const PreviewData = union(PreviewDataKind) {
    palette: [16 * 64]ig.ImVec4,
    bitmap: void,
    sound: struct {
        view_sound: []const f32,
        data: []const u8,
    },
};

x: f32 = 0.0,
y: f32 = 0.0,
w: f32 = 0.0,
h: f32 = 0.0,
open: bool = true,
filters: [7]bool = [1]bool{false} ** 7, // filter for each resource types
stats: [8]ResStat = [1]ResStat{.{}} ** 8, // stats for each resource types
select_index: usize = 0,
preview_data: ?PreviewData = null,
snd_frequency: c_int = 15,
snd_volume: c_int = 32,
use_ega: bool = false,
dirty: bool = false,
game: *raw.Game,
nearest_sampler: sg.Sampler = .{},
tex_fb: ?*anyopaque = null,
const Self = @This();

const ResStat = struct {
    uncompressed_total: u32 = 0,
    compressed_total: u32 = 0,
};

const Desc = struct {
    game: *raw.Game,
    x: f32 = 0.0,
    y: f32 = 0.0, // initial window pos
    w: f32 = 200.0,
    h: f32 = 200.0, // initial window size or 0 for default size
};

pub fn init(desc: Desc) Self {
    var self = Self{
        .game = desc.game,
        .x = desc.x,
        .y = desc.y,
        .w = desc.w,
        .h = desc.h,
    };
    self.tex_fb = util.createTexture(raw.GAME_WIDTH, raw.GAME_HEIGHT, self.nearest_sampler);
    // init stats
    for (0..self.game.res.num_mem_list) |i| {
        const res = &self.game.res.mem_list[i];
        if (res.status == .uninit) break;
        if (self.game.res.data.banks.get(res.bank_num - 1) == null) continue;
        self.stats[@intFromEnum(res.type)].compressed_total += res.packed_size;
        self.stats[@intFromEnum(res.type)].uncompressed_total += res.unpacked_size;
        self.stats[7].compressed_total += res.packed_size;
        self.stats[7].uncompressed_total += res.unpacked_size;
    }
    return self;
}

pub fn deinit(self: *Self) void {
    util.destroyTexture(self.tex_fb);
}

pub fn draw(self: *Self) void {
    self.drawResList();
    self.drawPreview();
}

/// Draw the preview window.
fn drawPreview(self: *Self) void {
    if (!self.open) return;

    ig.igSetNextWindowPos(.{ .x = self.x, .y = self.y }, ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(.{ .x = self.w, .y = self.h }, ig.ImGuiCond_Once);
    if (ig.igBegin("Preview", &self.open, ig.ImGuiWindowFlags_None)) {
        const item = self.game.res.mem_list[self.select_index];
        // update selected data
        if (self.dirty) {
            self.dirty = false;
            switch (item.type) {
                .palette => self.updatePalette(item),
                .bitmap => {
                    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                    const buf = self.readResItem(item, gpa.allocator());
                    defer gpa.allocator().free(buf);
                    if (buf.len > 0) {
                        var pal: [16]u32 = undefined;
                        self.getPalForResource(@intCast(self.select_index), &pal);
                        self.decodeBmp(buf, pal);
                        self.preview_data = PreviewData{ .bitmap = {} };
                    }
                },
                .sound => {
                    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                    const buf = self.readResItem(item, gpa.allocator());
                    var buf_audio = gpa.allocator().alloc(f32, buf.len) catch @panic("failed to allocate");
                    for (buf, 0..) |value, i| {
                        buf_audio[i] = @as(f32, @floatFromInt(@as(i8, @bitCast(value)))) / 128.0;
                    }
                    self.preview_data = PreviewData{ .sound = .{ .data = buf, .view_sound = buf_audio } };
                },
                else => {},
            }
        }
        // draw data
        if (self.preview_data) |preview_data| {
            switch (preview_data) {
                .palette => self.drawPalette(),
                .bitmap => self.drawBitmap(),
                .sound => self.drawSound(),
            }
        }
    }
    ig.igEnd();
}

/// Update the palette from the specified resource item.
fn updatePalette(self: *Self, item: raw.GameMemEntry) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var buf = self.readResItem(item, gpa.allocator());
    defer gpa.allocator().free(buf);
    var p = buf[@as(usize, 0) * 16 * @sizeOf(u16) ..];
    var colors: [16 * 64]ig.ImVec4 = undefined;
    // decode VGA palette
    for (0..16 * 32) |i| {
        const color = std.mem.readInt(u16, p[i * 2 ..][0..2], .big);
        var r: u32 = (color >> 8) & 0xF;
        var g: u32 = (color >> 4) & 0xF;
        var b: u32 = color & 0xF;
        r = (r << 4) | r;
        g = (g << 4) | g;
        b = (b << 4) | b;
        const pal = 0xFF000000 | r | (g << 8) | (b << 16);
        colors[i] = ig.ImColor_ImColor_U32(@as(c_uint, pal)).*.Value;
    }
    // decode EGA palette
    p = p[1024..];
    for (0..16 * 32) |i| {
        const color = std.mem.readInt(u16, p[0..2], .big);
        p = p[2..];
        const ega = Video.palette_ega[3 * ((color >> 12) & 15) ..][0..3];
        const pal = 0xFF000000 | @as(u32, @intCast(ega[0])) | (@as(u32, @intCast(ega[1])) << 8) | (@as(u32, @intCast(ega[2])) << 16);
        colors[16 * 32 + i] = ig.ImColor_ImColor_U32(@as(c_uint, pal)).*.Value;
    }
    self.preview_data = PreviewData{ .palette = colors };
}

/// Get the palette from the specified resource `res_id` and palette `pal_id`.
fn getPal(self: *Self, res_id: u16, pal_id: u16, pal: *[16]u32) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const buf = self.readResItem(self.game.res.mem_list[res_id], gpa.allocator());
    defer gpa.allocator().free(buf);

    const p = buf[pal_id * 16 * @sizeOf(u16) ..];
    for (0..16) |i| {
        const color = std.mem.readInt(u16, p[i * 2 ..][0..2], .big);
        var r: u32 = (color >> 8) & 0xF;
        var g: u32 = (color >> 4) & 0xF;
        var b: u32 = color & 0xF;
        r = (r << 4) | r;
        g = (g << 4) | g;
        b = (b << 4) | b;
        pal[i] = 0xFF000000 | r | (g << 8) | (b << 16);
    }
}

fn drawBitmap(self: *Self) void {
    const border_color = ig.ImColor_ImColor_Int(1, 1, 1, 1);
    ig.igImage(self.tex_fb, .{ .x = raw.GAME_WIDTH, .y = raw.GAME_HEIGHT }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 1 }, .{ .x = 1, .y = 1, .z = 1, .w = 1 }, border_color.*.Value);
}

/// Get the palette from the specified resource `bmp_res_id`.
fn getPalForResource(self: *Self, bmp_res_id: u16, pal: *[16]u32) void {
    const BitmapPal = struct { bmp_res_id: u16, pal_res_id: u16, pal_id: u16 };
    const bmpPalInfos = [_]BitmapPal{
        .{ .bmp_res_id = 0x12, .pal_res_id = 0x14, .pal_id = 4 },
        .{ .bmp_res_id = 0x13, .pal_res_id = 0x14, .pal_id = 10 },
        .{ .bmp_res_id = 0x43, .pal_res_id = 0x20, .pal_id = 6 },
        .{ .bmp_res_id = 0x44, .pal_res_id = 0x20, .pal_id = 8 },
        .{ .bmp_res_id = 0x45, .pal_res_id = 0x20, .pal_id = 8 },
        .{ .bmp_res_id = 0x46, .pal_res_id = 0x20, .pal_id = 8 },
        .{ .bmp_res_id = 0x47, .pal_res_id = 0x14, .pal_id = 2 },
        .{ .bmp_res_id = 0x48, .pal_res_id = 0x1d, .pal_id = 25 },
        .{ .bmp_res_id = 0x49, .pal_res_id = 0x1d, .pal_id = 25 },
        .{ .bmp_res_id = 0x53, .pal_res_id = 0x14, .pal_id = 10 },
        .{ .bmp_res_id = 0x90, .pal_res_id = 0x26, .pal_id = 3 },
        .{ .bmp_res_id = 0x91, .pal_res_id = 0x26, .pal_id = 1 },
    };

    for (&bmpPalInfos) |bmpPalInfo| {
        if (bmpPalInfo.bmp_res_id == bmp_res_id) {
            self.getPal(bmpPalInfo.pal_res_id, bmpPalInfo.pal_id, pal);
            return;
        }
    }
    unreachable;
}

/// Draw the palettes of the selected resource.
fn drawPalette(self: *Self) void {
    if (self.game.res.data_type == .dos) {
        _ = ig.igCheckbox("EGA palette", &self.use_ega);
    }
    if (self.game.res.data_type != .dos or !self.use_ega) {
        for (0..32) |pal| {
            ig.igText("Palette %d", pal);
            for (0..16) |i| {
                ig.igPushID_Int(@intCast(i + pal * 16));
                _ = ig.igColorEdit3("", &self.preview_data.?.palette[pal * 16 + i].x, ig.ImGuiColorEditFlags_NoInputs);
                ig.igPopID();
                if ((i % 8) != 7) {
                    ig.igSameLine(0, -1);
                }
            }
            ig.igSeparator();
        }
    } else {
        for (0..32) |pal| {
            ig.igText("Palette %d", pal);
            for (0..16) |i| {
                ig.igPushID_Int(@intCast(i + pal * 16));
                _ = ig.igColorEdit3("", &self.preview_data.?.palette[16 * 32 + pal * 16 + i].x, ig.ImGuiColorEditFlags_NoInputs);
                ig.igPopID();
                if ((i % 8) != 7) {
                    ig.igSameLine(0, -1);
                }
            }
            ig.igSeparator();
        }
    }
}

/// Draw the resource list window.
fn drawResList(self: *Self) void {
    if (!self.open) return;

    const labels = [_][*c]const u8{ "Sound", "Music", "Bitmap", "Palette", "Byte code", "Shape", "Bank" };
    ig.igSetNextWindowPos(.{ .x = self.x, .y = self.y }, ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(.{ .x = self.w, .y = self.h }, ig.ImGuiCond_Once);
    if (ig.igBegin("Resources", &self.open, ig.ImGuiWindowFlags_None)) {
        for (labels, 0..) |label, i| {
            if (i > 0) ig.igSameLine(0, 2);
            ig.igPushID_Int(@intCast(i));
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, util.hsv(@as(f32, @floatFromInt(i)) / 7.0, 0.6, 0.6).Value);
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_ButtonHovered, util.hsv(@as(f32, @floatFromInt(i)) / 7.0, 0.7, 0.7).Value);
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_ButtonActive, util.hsv(@as(f32, @floatFromInt(i)) / 7.0, 0.8, 0.8).Value);
            if (ig.igButton(label, .{})) {
                self.filters[i] = !self.filters[i];
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

            for (0..self.game.res.num_mem_list) |i| {
                const e = &self.game.res.mem_list[i];
                if (e.status == .uninit) break;
                // skip resource if its bank does not exist
                if (self.game.res.data.banks.get(e.bank_num - 1) == null) continue;

                if (self.filters[@intFromEnum(e.type)]) continue;
                if (self.game.res.data.banks.get(e.bank_num - 1) == null) continue;

                ig.igTableNextRow(0, 20.0);
                _ = ig.igTableNextColumn();
                ig.igPushID_Int(@intCast(i));
                var status_text: [256:0]u8 = undefined;
                const status_fmt: []const u8 = std.fmt.bufPrintZ(&status_text, "{X:0>2}", .{i}) catch @panic("format failed");
                if (ig.igSelectable_Bool(@ptrCast(status_fmt), i == self.select_index, ig.ImGuiSelectableFlags_SpanAllColumns, .{})) {
                    self.select_index = i;
                    self.dirty = true;
                }
                _ = ig.igTableNextColumn();
                ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_FramePadding, .{});
                _ = ig.igColorButton("##color", util.hsv(@as(f32, @floatFromInt(@intFromEnum(e.type))) / 7.0, 0.6, 0.6).Value, ig.ImGuiColorEditFlags_NoTooltip, .{});
                ig.igSameLine(0, -1);
                ig.igText("%s", labels[@intFromEnum(e.type)]);
                ig.igPopStyleVar(1);

                _ = ig.igTableNextColumn();
                ig.igText("%02X", e.bank_num);
                _ = ig.igTableNextColumn();
                ig.igText("%s", util.convertSize(&status_text, e.packed_size));
                _ = ig.igTableNextColumn();
                ig.igText("%s", util.convertSize(&status_text, e.unpacked_size));
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
                ig.igText("%s", util.convertSize(&status_text, self.stats[i].compressed_total));
                _ = ig.igTableNextColumn();
                ig.igText("%s", util.convertSize(&status_text, self.stats[i].uncompressed_total));
            }
            ig.igTableNextRow(0, 20.0);
            _ = ig.igTableNextColumn();
            ig.igText("Total");
            _ = ig.igTableNextColumn();
            var status_text: [256:0]u8 = undefined;
            ig.igText("%s", util.convertSize(&status_text, self.stats[7].compressed_total));
            _ = ig.igTableNextColumn();
            ig.igText("%s", util.convertSize(&status_text, self.stats[7].uncompressed_total));
            ig.igEndTable();
        }
    }
    ig.igEnd();
}

/// Read the data of the specified resource.
fn readResItem(self: *Self, item: raw.GameMemEntry, allocator: std.mem.Allocator) []const u8 {
    const buf: []u8 = allocator.alloc(u8, item.unpacked_size) catch @panic("no more memory :(");
    _ = self.game.res.readBank(&item, buf);
    return buf;
}

/// Decode the bitmap from the specified buffer and the given palette.
fn decodeBmp(self: *Self, buf: []const u8, pal: [16]u32) void {
    var temp_bitmap: [raw.GAME_WIDTH * raw.GAME_HEIGHT]u8 = undefined;
    var temp_bitmap2: [raw.GAME_WIDTH * raw.GAME_HEIGHT]u32 = undefined;
    switch (self.game.res.data_type) {
        .dos, .amiga => Video.decodeAmiga(buf, &temp_bitmap),
        .atari => Video.decodeAtari(buf, &temp_bitmap),
    }
    for (0..raw.GAME_WIDTH * raw.GAME_HEIGHT) |i| {
        temp_bitmap2[i] = pal[temp_bitmap[i]];
    }
    util.updateTexture(self.tex_fb, &temp_bitmap2, raw.GAME_WIDTH * raw.GAME_HEIGHT * @sizeOf(u32));
}

fn drawSound(self: *Self) void {
    if (self.preview_data.?.sound.view_sound.len < 8) return;

    const sample_buffer = self.preview_data.?.sound.view_sound[8..];
    const cursor_pos = self.game.audio.channels[4].pos.getInt();
    var area: ig.ImVec2 = undefined;
    ig.igGetContentRegionAvail(&area);
    var pos: ig.ImVec2 = undefined;
    ig.igGetCursorScreenPos(&pos);
    ig.igPlotLines_FloatPtr("##samples", sample_buffer.ptr, @intCast(sample_buffer.len), 0, 0, -1.0, 1.0, area, @sizeOf(f32));
    const style = ig.igGetStyle().*;
    const x0: f32 = pos.x + style.FramePadding.x;
    const x1: f32 = pos.x + area.x - style.FramePadding.x;
    const y0: f32 = pos.y + style.FramePadding.y;
    const y1: f32 = pos.y + area.y - style.FramePadding.y;
    const tx: f32 = @as(f32, @floatFromInt(cursor_pos)) / @as(f32, @floatFromInt(sample_buffer.len));
    const x: f32 = x0 + (x1 - x0) * tx;
    ig.ImDrawList_AddLine(ig.igGetWindowDrawList(), .{ .x = x, .y = y0 }, .{ .x = x, .y = y1 }, 0xFFFFFFFF, 1);

    _ = ig.igDragInt("Volume", &self.snd_volume, 1, 0, 63, 0, ig.ImGuiSliderFlags_None);
    const frequencies = "3326\u{0}3523\u{0}3728\u{0}3950\u{0}4181\u{0}4430\u{0}4697\u{0}4971\u{0}5279\u{0}5593\u{0}5926\u{0}6279\u{0}6653\u{0}7046\u{0}7457\u{0}7901\u{0}8363\u{0}8860\u{0}9395\u{0}9943\u{0}10559\u{0}11186\u{0}11852\u{0}12559\u{0}13306\u{0}14092\u{0}14914\u{0}15838\u{0}16726\u{0}17720\u{0}18839\u{0}19886\u{0}21056\u{0}22372\u{0}23705\u{0}25031\u{0}26515\u{0}28185\u{0}29829\u{0}\u{0}";
    _ = ig.igCombo_Str("Frequency", &self.snd_frequency, frequencies, 0);
    if (ig.igButton("Play", .{})) {
        self.game.debugSndPlaySound(self.preview_data.?.sound.data, @intCast(self.snd_frequency), @intCast(self.snd_volume));
    }
}
