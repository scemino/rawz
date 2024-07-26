const ig = @import("cimgui");
const raw = @import("../raw/raw.zig");
x: f32 = 0.0,
y: f32 = 0.0,
w: f32 = 0.0,
h: f32 = 0.0,
open: bool = true,
game: *raw.game.Game = undefined,

const Self = @This();

const Desc = struct {
    game: *raw.game.Game,
    x: f32 = 0.0,
    y: f32 = 0.0, // initial window pos
    w: f32 = 200.0,
    h: f32 = 200.0, // initial window size or 0 for default size
};

pub fn init(desc: Desc) Self {
    return .{
        .game = desc.game,
        .x = desc.x,
        .y = desc.y,
        .w = desc.w,
        .h = desc.h,
    };
}

pub fn draw(self: *Self) void {
    if (!self.open) return;

    ig.igSetNextWindowPos(.{ .x = self.x, .y = self.y }, ig.ImGuiCond_Once, .{});
    ig.igSetNextWindowSize(.{ .x = self.w, .y = self.h }, ig.ImGuiCond_Once);
    if (ig.igBegin("Audio", &self.open, ig.ImGuiWindowFlags_None)) {
        for (0..4) |i| {
            ig.igPushID_Int(@intCast(i));
            _ = ig.igCheckbox("Mute", &self.game.audio.channels[i].mute);
            ig.igPopID();
        }
        _ = ig.igCheckbox("Mute music", &self.game.audio.mute_music);
    }
    ig.igEnd();
}
