const std = @import("std");
const ig = @import("cimgui");
const raw = @import("../raw/raw.zig");
const util = @import("ui_util.zig");

x: f32 = 0.0,
y: f32 = 0.0,
w: f32 = 0.0,
h: f32 = 0.0,
open: bool = true,
filters: [7]bool = [1]bool{false} ** 7, // filter for each resource types
stats: [8]ResStat = [1]ResStat{.{}} ** 8, // stats for each resource types
game: *raw.game.Game,
const Self = @This();

const ResStat = struct {
    uncompressed_total: u32 = 0,
    compressed_total: u32 = 0,
};

const Desc = struct {
    game: *raw.game.Game,
};

pub fn init(desc: Desc) Self {
    return .{ .game = desc.game };
}

pub fn draw(self: *Self) void {
    if (!self.open) return;
    self.update();
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
                _ = ig.igSelectable_Bool(@ptrCast(status_fmt), false, ig.ImGuiSelectableFlags_SpanAllColumns, .{});
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

fn update(self: *Self) void {
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
