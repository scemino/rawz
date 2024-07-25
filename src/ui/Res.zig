const std = @import("std");
const ig = @import("cimgui");
const raw = @import("../raw/raw.zig");
const Video = @import("../raw/Video.zig");
const util = @import("ui_util.zig");

/// Preview data
const PreviewDataKind = enum {
    /// Represents palette data
    palette,
};

const PreviewData = union(PreviewDataKind) {
    palette: [16 * 64]ig.ImVec4,
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
use_ega: bool = false,
dirty: bool = false,
game: *raw.game.Game,
const Self = @This();

const ResStat = struct {
    uncompressed_total: u32 = 0,
    compressed_total: u32 = 0,
};

const Desc = struct {
    game: *raw.game.Game,
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
    self.updateStats();
    return self;
}

pub fn draw(self: *Self) void {
    self.drawResList();
    self.drawPreview();
}

fn drawPreview(self: *Self) void {
    if (!self.open) return;

    ig.igSetNextWindowPos(.{ .x = self.x, .y = self.y }, ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(.{ .x = self.w, .y = self.h }, ig.ImGuiCond_Once);
    if (ig.igBegin("Preview", &self.open, ig.ImGuiWindowFlags_None)) {
        const item = self.game.res.mem_list[self.select_index];
        switch (item.type) {
            .palette => self.updatePalette(item),
            else => {},
        }
    }
    ig.igEnd();
}

fn updatePalette(self: *Self, item: raw.game.GameMemEntry) void {
    if (self.dirty) {
        self.dirty = false;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        var buf: []u8 = gpa.allocator().alloc(u8, item.unpacked_size) catch @panic("no more memory :(");
        _ = raw.game.gameResReadBank(self.game, &item, buf);
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
    self.drawPalette();
}

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

fn updateStats(self: *Self) void {
    for (0..self.game.res.num_mem_list) |i| {
        const res = &self.game.res.mem_list[i];
        if (res.status == .uninit) break;
        if (self.game.res.data.banks.get(res.bank_num - 1) == null) continue;
        self.stats[@intFromEnum(res.type)].compressed_total += res.packed_size;
        self.stats[@intFromEnum(res.type)].uncompressed_total += res.unpacked_size;
        self.stats[7].compressed_total += res.packed_size;
        self.stats[7].uncompressed_total += res.unpacked_size;
    }
}
