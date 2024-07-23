const raw = @import("../raw/raw.zig");
const ig = @import("cimgui");
const util = @import("ui_util.zig");
x: f32 = 0.0,
y: f32 = 0.0,
w: f32 = 0.0,
h: f32 = 0.0,
open: bool = true,
tex_fb: [4]?*anyopaque = [1]?*anyopaque{null} ** 4,
pixel_buffer: [raw.GAME_WIDTH * raw.GAME_HEIGHT]u32 = [1]u32{0} ** (raw.GAME_WIDTH * raw.GAME_HEIGHT),
game: *raw.game.Game = undefined,
const Self = @This();

const Desc = struct {
    game: *raw.game.Game,
};

pub fn init(desc: Desc) Self {
    return .{ .game = desc.game };
}

pub fn draw(self: *Self) void {
    if (!self.open) return;
    ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once, .{ .x = 0, .y = 0 });
    ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
    _ = ig.igBegin("Video", &self.open, ig.ImGuiWindowFlags_None);

    // palette
    if (ig.igCollapsingHeader_TreeNodeFlags("Palette", ig.ImGuiTreeNodeFlags_DefaultOpen)) {
        inline for (0..16) |i| {
            const color = ig.ImColor_ImColor_U32(@as(c_uint, self.game.gfx.palette[i]));
            ig.igPushID_Int(@intCast(i));
            _ = ig.igColorEdit3("", &color.*.Value.x, ig.ImGuiColorEditFlags_NoInputs);
            ig.igPopID();
            if (i != 7) {
                ig.igSameLine(0, -1);
            }
        }
        ig.igNewLine();
    }

    // frame buffers
    if (ig.igCollapsingHeader_TreeNodeFlags("Frame buffers", ig.ImGuiTreeNodeFlags_DefaultOpen)) {
        ig.igText("Current page: %d", @as(u8, @intCast(self.game.video.buffers[0])));
        self.updateFbs();
        inline for (0..4) |i| {
            const border_color = if (self.game.video.buffers[0] == i) ig.ImColor_ImColor_U32(0xFF30FF30) else ig.ImColor_ImColor_Int(1, 1, 1, 1);
            ig.igImage(self.tex_fb[i], .{ .x = raw.GAME_WIDTH, .y = raw.GAME_HEIGHT }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 1 }, .{ .x = 1, .y = 1, .z = 1, .w = 1 }, border_color.*.Value);
            if (i != 1) {
                ig.igSameLine(0, -1);
            }
        }
    }

    ig.igEnd();
}

fn updateFbs(self: *Self) void {
    for (0..4) |i| {
        for (0..raw.GAME_WIDTH * raw.GAME_HEIGHT) |j| {
            self.pixel_buffer[j] = self.game.gfx.palette[self.game.gfx.fbs[i].buffer[j]];
        }
        util.updateTexture(self.tex_fb[i], &self.pixel_buffer, raw.GAME_WIDTH * raw.GAME_HEIGHT * @sizeOf(u32));
    }
}
