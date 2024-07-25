const std = @import("std");
const audio = @import("sokol").audio;
const glue = @import("../common/glue.zig");
const DemoJoy = @import("DemoJoy.zig");
const Strings = @import("Strings.zig");
const GameFrac = @import("GameFrac.zig");
const GamePc = @import("GamePc.zig");
const GameData = @import("GameData.zig");
const Gfx = @import("Gfx.zig");
const Video = @import("Video.zig");
pub const mementries = @import("mementries.zig");
pub const util = @import("util.zig");
pub const byteKillerUnpack = @import("unpack.zig").byteKillerUnpack;
pub const detectAmigaAtari = mementries.detectAmigaAtari;
pub const GameDataType = mementries.GameDataType;
pub const GameLang = Strings.GameLang;
const DefaultPrng = std.rand.DefaultPrng;
const assert = std.debug.assert;

const GAME_ENTRIES_COUNT = 146;
const GAME_MEM_BLOCK_SIZE = 1 * 1024 * 1024;
const GAME_NUM_TASKS = 64;

const GAME_MIX_FREQ = 22050;
const GAME_MIX_BUF_SIZE = 4096 * 8;
const GAME_MIX_CHANNELS = 4;
const GAME_SFX_NUM_CHANNELS = 4;
const GAME_MAX_AUDIO_SAMPLES = 2048 * 16; // max number of audio samples in internal sample buffer

const GAME_INACTIVE_TASK = 0xFFFF;

const GAME_VAR_RANDOM_SEED = 0x3C;
const GAME_VAR_SCREEN_NUM = 0x67;
const GAME_VAR_LAST_KEYCHAR = 0xDA;
const GAME_VAR_HERO_POS_UP_DOWN = 0xE5;
const GAME_VAR_MUSIC_SYNC = 0xF4;
const GAME_VAR_SCROLL_Y = 0xF9;
const GAME_VAR_HERO_ACTION = 0xFA;
const GAME_VAR_HERO_POS_JUMP_DOWN = 0xFB;
const GAME_VAR_HERO_POS_LEFT_RIGHT = 0xFC;
const GAME_VAR_HERO_POS_MASK = 0xFD;
const GAME_VAR_HERO_ACTION_POS_MASK = 0xFE;
const GAME_VAR_PAUSE_SLICES = 0xFF;

const GAME_QUAD_STRIP_MAX_VERTICES = 70;

const GAME_PAULA_FREQ: i32 = 7159092;

const font = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x10, 0x00, 0x28, 0x28, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x24, 0x7E, 0x24, 0x24, 0x7E, 0x24, 0x00, 0x08, 0x3E, 0x48, 0x3C, 0x12, 0x7C, 0x10, 0x00, 0x42, 0xA4, 0x48, 0x10, 0x24, 0x4A, 0x84, 0x00, 0x60, 0x90, 0x90, 0x70, 0x8A, 0x84, 0x7A, 0x00, 0x08, 0x08, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x08, 0x10, 0x10, 0x10, 0x08, 0x06, 0x00, 0xC0, 0x20, 0x10, 0x10, 0x10, 0x20, 0xC0, 0x00, 0x00, 0x44, 0x28, 0x10, 0x28, 0x44, 0x00, 0x00, 0x00, 0x10, 0x10, 0x7C, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x20, 0x00, 0x00, 0x00, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x28, 0x10, 0x00, 0x00, 0x04, 0x08, 0x10, 0x20, 0x40, 0x00, 0x00, 0x78, 0x84, 0x8C, 0x94, 0xA4, 0xC4, 0x78, 0x00, 0x10, 0x30, 0x50, 0x10, 0x10, 0x10, 0x7C, 0x00, 0x78, 0x84, 0x04, 0x08, 0x30, 0x40, 0xFC, 0x00, 0x78, 0x84, 0x04, 0x38, 0x04, 0x84, 0x78, 0x00, 0x08, 0x18, 0x28, 0x48, 0xFC, 0x08, 0x08, 0x00, 0xFC, 0x80, 0xF8, 0x04, 0x04, 0x84, 0x78, 0x00, 0x38, 0x40, 0x80, 0xF8, 0x84, 0x84, 0x78, 0x00, 0xFC, 0x04, 0x04, 0x08, 0x10, 0x20, 0x40, 0x00, 0x78, 0x84, 0x84, 0x78, 0x84, 0x84, 0x78, 0x00, 0x78, 0x84, 0x84, 0x7C, 0x04, 0x08, 0x70, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x10, 0x10, 0x60, 0x04, 0x08, 0x10, 0x20, 0x10, 0x08, 0x04, 0x00, 0x00, 0x00, 0xFE, 0x00, 0x00, 0xFE, 0x00, 0x00, 0x20, 0x10, 0x08, 0x04, 0x08, 0x10, 0x20, 0x00, 0x7C, 0x82, 0x02, 0x0C, 0x10, 0x00, 0x10, 0x00, 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00, 0x78, 0x84, 0x84, 0xFC, 0x84, 0x84, 0x84, 0x00, 0xF8, 0x84, 0x84, 0xF8, 0x84, 0x84, 0xF8, 0x00, 0x78, 0x84, 0x80, 0x80, 0x80, 0x84, 0x78, 0x00, 0xF8, 0x84, 0x84, 0x84, 0x84, 0x84, 0xF8, 0x00, 0x7C, 0x40, 0x40, 0x78, 0x40, 0x40, 0x7C, 0x00, 0xFC, 0x80, 0x80, 0xF0, 0x80, 0x80, 0x80, 0x00, 0x7C, 0x80, 0x80, 0x8C, 0x84, 0x84, 0x7C, 0x00, 0x84, 0x84, 0x84, 0xFC, 0x84, 0x84, 0x84, 0x00, 0x7C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x7C, 0x00, 0x04, 0x04, 0x04, 0x04, 0x84, 0x84, 0x78, 0x00, 0x8C, 0x90, 0xA0, 0xE0, 0x90, 0x88, 0x84, 0x00, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0xFC, 0x00, 0x82, 0xC6, 0xAA, 0x92, 0x82, 0x82, 0x82, 0x00, 0x84, 0xC4, 0xA4, 0x94, 0x8C, 0x84, 0x84, 0x00, 0x78, 0x84, 0x84, 0x84, 0x84, 0x84, 0x78, 0x00, 0xF8, 0x84, 0x84, 0xF8, 0x80, 0x80, 0x80, 0x00, 0x78, 0x84, 0x84, 0x84, 0x84, 0x8C, 0x7C, 0x03, 0xF8, 0x84, 0x84, 0xF8, 0x90, 0x88, 0x84, 0x00, 0x78, 0x84, 0x80, 0x78, 0x04, 0x84, 0x78, 0x00, 0x7C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x78, 0x00, 0x84, 0x84, 0x84, 0x84, 0x84, 0x48, 0x30, 0x00, 0x82, 0x82, 0x82, 0x82, 0x92, 0xAA, 0xC6, 0x00, 0x82, 0x44, 0x28, 0x10, 0x28, 0x44, 0x82, 0x00, 0x82, 0x44, 0x28, 0x10, 0x10, 0x10, 0x10, 0x00, 0xFC, 0x04, 0x08, 0x10, 0x20, 0x40, 0xFC, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00, 0x00, 0x00, 0x38, 0x04, 0x3C, 0x44, 0x3C, 0x00, 0x40, 0x40, 0x78, 0x44, 0x44, 0x44, 0x78, 0x00, 0x00, 0x00, 0x3C, 0x40, 0x40, 0x40, 0x3C, 0x00, 0x04, 0x04, 0x3C, 0x44, 0x44, 0x44, 0x3C, 0x00, 0x00, 0x00, 0x38, 0x44, 0x7C, 0x40, 0x3C, 0x00, 0x38, 0x44, 0x40, 0x60, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x3C, 0x44, 0x44, 0x3C, 0x04, 0x78, 0x40, 0x40, 0x58, 0x64, 0x44, 0x44, 0x44, 0x00, 0x10, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x02, 0x00, 0x02, 0x02, 0x02, 0x02, 0x42, 0x3C, 0x40, 0x40, 0x46, 0x48, 0x70, 0x48, 0x46, 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0xEC, 0x92, 0x92, 0x92, 0x92, 0x00, 0x00, 0x00, 0x78, 0x44, 0x44, 0x44, 0x44, 0x00, 0x00, 0x00, 0x38, 0x44, 0x44, 0x44, 0x38, 0x00, 0x00, 0x00, 0x78, 0x44, 0x44, 0x78, 0x40, 0x40, 0x00, 0x00, 0x3C, 0x44, 0x44, 0x3C, 0x04, 0x04, 0x00, 0x00, 0x4C, 0x70, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x3C, 0x40, 0x38, 0x04, 0x78, 0x00, 0x10, 0x10, 0x3C, 0x10, 0x10, 0x10, 0x0C, 0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x44, 0x78, 0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x28, 0x10, 0x00, 0x00, 0x00, 0x82, 0x82, 0x92, 0xAA, 0xC6, 0x00, 0x00, 0x00, 0x44, 0x28, 0x10, 0x28, 0x44, 0x00, 0x00, 0x00, 0x42, 0x22, 0x24, 0x18, 0x08, 0x30, 0x00, 0x00, 0x7C, 0x08, 0x10, 0x20, 0x7C, 0x00, 0x60, 0x90, 0x20, 0x40, 0xF0, 0x00, 0x00, 0x00, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0x00, 0x38, 0x44, 0xBA, 0xA2, 0xBA, 0x44, 0x38, 0x00, 0x38, 0x44, 0x82, 0x82, 0x44, 0x28, 0xEE, 0x00, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA };

const restart_pos = [36 * 2]i16{ 16008, 0, 16001, 0, 16002, 10, 16002, 12, 16002, 14, 16003, 20, 16003, 24, 16003, 26, 16004, 30, 16004, 31, 16004, 32, 16004, 33, 16004, 34, 16004, 35, 16004, 36, 16004, 37, 16004, 38, 16004, 39, 16004, 40, 16004, 41, 16004, 42, 16004, 43, 16004, 44, 16004, 45, 16004, 46, 16004, 47, 16004, 48, 16004, 49, 16006, 64, 16006, 65, 16006, 66, 16006, 67, 16006, 68, 16005, 50, 16006, 60, 16007, 0 };
const mem_list_parts = [_][4]u8{
    // ipal, icod, ivd1, ivd2
    .{ 0x14, 0x15, 0x16, 0x00 }, // 16000 - protection screens
    .{ 0x17, 0x18, 0x19, 0x00 }, // 16001 - introduction
    .{ 0x1A, 0x1B, 0x1C, 0x11 }, // 16002 - water
    .{ 0x1D, 0x1E, 0x1F, 0x11 }, // 16003 - jail
    .{ 0x20, 0x21, 0x22, 0x11 }, // 16004 - 'cite'
    .{ 0x23, 0x24, 0x25, 0x00 }, // 16005 - 'arene'
    .{ 0x26, 0x27, 0x28, 0x11 }, // 16006 - 'luxe'
    .{ 0x29, 0x2A, 0x2B, 0x11 }, // 16007 - 'final'
    .{ 0x7D, 0x7E, 0x7F, 0x00 }, // 16008 - password screen
    .{ 0x7D, 0x7E, 0x7F, 0x00 }, // 16009 - password screen
};

const period_table = [_]u16{ 1076, 1016, 960, 906, 856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453, 428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226, 214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113 };

const GAME_TITLE_EU = "Another World";
const GAME_TITLE_US = "Out Of This World";

pub const GameMemEntry = struct {
    status: GameResStatus, // 0x0
    type: GameResType, // 0x1
    buf_ptr: []u8, // 0x2
    rank_num: u8, // 0x6
    bank_num: u8, // 0x7
    bank_pos: u32, // 0x8
    packed_size: u32, // 0xC
    unpacked_size: u32, // 0x12
};

pub const GamePart = enum(u16) {
    copy_protection = 16000,
    intro = 16001,
    water = 16002,
    prison = 16003,
    cite = 16004,
    arene = 16005,
    luxe = 16006,
    final = 16007,
    password = 16008,
};

pub const GameInput = enum {
    left,
    right,
    up,
    down,
    action,
    back,
    code,
    pause,
};

const GameResType = enum(u8) {
    sound,
    music,
    bitmap, // full screen 4bpp video buffer, size=200*320/2
    palette, // palette (1024=vga + 1024=ega), size=2048
    bytecode,
    shape,
    bank, // common part shapes (bank2.mat)
};

const GameResStatus = enum(u8) {
    null,
    loaded,
    toload,
    uninit = 0xff,
};

const GameAudioSfxInstrument = struct {
    data: []u8,
    volume: u16 = 0,
};

const GameAudioSfxPattern = struct {
    note_1: u16 = 0,
    note_2: u16 = 0,
    sample_start: u16 = 0,
    sample_buffer: ?[]u8 = null,
    sample_len: u16 = 0,
    loop_pos: u16 = 0,
    loop_data: ?[]u8 = null,
    loop_len: u16 = 0,
    period_arpeggio: u16 = 0, // unused by Another World tracks
    sample_volume: u16 = 0,
};

const GameAudioSfxModule = struct {
    data: []const u8,
    cur_pos: u16 = 0,
    cur_order: u8 = 0,
    num_order: u8 = 0,
    order_table: []u8,
    samples: [15]GameAudioSfxInstrument,
};

const GameAudioSfxChannel = struct {
    sample_data: []u8,
    sample_len: u16 = 0,
    sample_loop_pos: u16 = 0,
    sample_loop_len: u16 = 0,
    volume: u16 = 0,
    pos: GameFrac,
};

const GameAudioSfxPlayer = struct {
    delay: u16 = 0,
    res_num: u16 = 0,
    sfx_mod: GameAudioSfxModule,
    playing: bool = false,
    samples_left: i32 = 0,
    channels: [GAME_SFX_NUM_CHANNELS]GameAudioSfxChannel,
};

const GameAudioCallback = ?*const fn ([]const f32) void;

const GameAudioChannel = struct {
    data: ?[]const u8,
    pos: GameFrac,
    len: u32 = 0,
    loop_len: u32 = 0,
    loop_pos: u32 = 0,
    volume: i32 = 0,
};

const GameAudioDesc = struct {
    callback: GameAudioCallback,
    sample_rate: i32,
};

const GameInputDir = packed struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
};

pub const GameRes = struct {
    mem_list: [GAME_ENTRIES_COUNT]GameMemEntry,
    num_mem_list: u16,
    mem: [GAME_MEM_BLOCK_SIZE]u8,
    current_part: GamePart,
    next_part: ?GamePart,
    script_bak: usize,
    script_cur: usize,
    vid_cur: usize,
    use_seg_video2: bool,
    seg_video_pal: []u8,
    seg_code: []u8,
    seg_code_size: u16,
    seg_video1: []u8,
    seg_video2: []u8,
    has_password_screen: bool,
    data_type: GameDataType,
    data: GameData,
    lang: GameLang,
};

// configuration parameters for game_init()
const GameDesc = struct {
    part_num: u16, // indicates the part number where the fame starts
    use_ega: bool, // true to use EGA palette, false to use VGA palette
    lang: GameLang, // language to use
    enable_protection: bool,
    audio: GameAudioDesc,
    //TODO: debug = game_debug_t,
    data: GameData,
};

const GameStrEntry = struct {
    id: u16,
    str: []const u8,
};

pub const Game = struct {
    const Audio = struct {
        sample_buffer: [GAME_MAX_AUDIO_SAMPLES]f32,
        samples: [GAME_MIX_BUF_SIZE]i16,
        channels: [GAME_MIX_CHANNELS]GameAudioChannel,
        sfx_player: GameAudioSfxPlayer,
        callback: GameAudioCallback,
    };

    const Vm = struct {
        const Task = struct {
            pc: u16,
            next_pc: u16,
            state: u8,
            next_state: u8,
        };
        vars: [256]i16,
        stack_calls: [64]u16,

        tasks: [GAME_NUM_TASKS]Task,
        ptr: GamePc,
        stack_ptr: u8,
        paused: bool,
        screen_num: i32,
        start_time: u32,
        time_stamp: u32,
        current_task: u8,
    };

    const Input = struct {
        dir_mask: GameInputDir,
        action: bool, // run,shoot
        code: bool,
        pause: bool,
        quit: bool,
        back: bool,
        last_char: u8,
        demo_joy: DemoJoy,
    };

    valid: bool,
    enable_protection: bool,
    // TODO: debug:game_debug_t,
    res: GameRes,
    strings_table: Strings,
    part_num: u16,
    elapsed: u32,
    sleep: u32,

    gfx: Gfx,

    audio: Audio,
    video: Video,

    vm: Vm,

    input: Input,

    title: [:0]const u8, // title of the game
};

const video_log = std.log.scoped(.video);
const vm_log = std.log.scoped(.vm);
const snd_log = std.log.scoped(.sound);
const bank_log = std.log.scoped(.bank);

pub fn displayInfo(game: ?*Game) glue.DisplayInfo {
    return .{
        .fb = .{
            .dim = .{
                .width = Gfx.GAME_WIDTH,
                .height = Gfx.GAME_HEIGHT,
            },
            .buffer = if (game) |self| .{ .Palette8 = &self.gfx.fb } else null,
        },
        .view = .{
            .x = 0,
            .y = 0,
            .width = Gfx.GAME_WIDTH,
            .height = Gfx.GAME_HEIGHT,
        },
        .palette = if (game) |self| &self.gfx.palette else null,
        .orientation = .Landscape,
    };
}

pub fn gameInit(game: *Game, desc: GameDesc) !void {
    //assert(game and desc);
    //if (desc.debug.callback.func) { GAME_ASSERT(desc.debug.stopped); }
    game.valid = true;
    game.enable_protection = desc.enable_protection;
    // game.debug = desc.debug;
    game.part_num = desc.part_num;
    game.res.lang = desc.lang;
    gameAudioInit(game, desc.audio.callback);

    game.res.data = desc.data;
    if (game.res.data.demo3_joy) |demo| {
        game.input.demo_joy.read(demo);
    }

    gameResDetectVersion(game);
    game.video = Video.init(&game.gfx, game.res.data_type, desc.use_ega);
    game.res.has_password_screen = true;
    game.res.script_bak = 0;
    game.res.script_cur = 0;
    game.res.vid_cur = GAME_MEM_BLOCK_SIZE - (Gfx.GAME_WIDTH * Gfx.GAME_HEIGHT / 2); // 4bpp bitmap
    try gameResReadEntries(game);

    game.gfx.setWorkPagePtr(2);

    var rnd = DefaultPrng.init(0);
    game.vm.vars[GAME_VAR_RANDOM_SEED] = rnd.random().int(i16);
    if (!game.enable_protection) {
        game.vm.vars[0xBC] = 0x10;
        game.vm.vars[0xC6] = 0x80;
        game.vm.vars[0xF2] = if (game.res.data_type == .amiga or game.res.data_type == .atari) 6000 else 4000;
        game.vm.vars[0xDC] = 33;
    }

    if (game.res.data_type == .dos) {
        game.vm.vars[0xE4] = 20;
    }

    game.strings_table = Strings.init(game.res.lang);

    if (game.enable_protection and (game.res.data_type != .dos or game.res.has_password_screen)) {
        game.part_num = @intFromEnum(GamePart.copy_protection);
    }

    const num = game.part_num;
    if (num < 36) {
        restartAt(game, @enumFromInt(restart_pos[num * 2]), restart_pos[num * 2 + 1]);
    } else {
        restartAt(game, @enumFromInt(num), -1);
    }
    game.title = game_res_get_game_title(game);
}

fn game_res_get_game_title(game: *Game) [:0]const u8 {
    return if (game.res.data_type == .dos and game.res.lang == .us) GAME_TITLE_US else GAME_TITLE_EU;
}

pub fn gameExec(game: *Game, ms: u32) !void {
    game.elapsed += ms;

    if (game.sleep > 0) {
        if (ms > game.sleep) {
            game.sleep = 0;
        } else {
            game.sleep -= ms;
        }
        return;
    }

    var stopped = false;
    while (!stopped) {
        // TODO: debug
        // if (null == game.debug.callback.func) {
        //     // run without _debug hook
        //     stopped = game_vm_run(game);
        // } else {
        // run with _debug hook
        // stopped = *game.debug.stopped;
        if (!stopped) {
            stopped = stopped or try gameVmRun(game);
            // game.debug.callback.func(game.debug.callback.user_data, game.vm.tasks[game.vm.current_task].pc);
        } else {
            game.sleep = 0;
        }
        // }
    }

    //  audio
    const num_frames: usize = @intCast(audio.saudio_expect());
    if (num_frames > 0) {
        const num_samples: usize = num_frames * @as(usize, @intCast(audio.saudio_channels()));
        gameAudioUpdate(game, num_samples);
    }

    game.sleep += 20; // wait 20 ms (50 Hz)
}

pub fn restartAt(game: *Game, part: GamePart, pos: i16) void {
    gameAudioStopAll(game);
    if (game.res.data_type == .dos and part == .copy_protection) {
        // VAR(0x54) indicates if the "Out of this World" title screen should be presented
        //
        //   0084: jmpIf(VAR(0x54) < 128, @00C4)
        //   ..
        //   008D: setPalette(num=0)
        //   0090: updateResources(res=18)
        //   ...
        //   00C4: setPalette(num=23)
        //   00CA: updateResources(res=71)

        // Use "Another World" title screen if language is set to French
        game.vm.vars[0x54] = if (game.res.lang == .fr) 0x1 else 0x81;
    }
    gameResSetupPart(game, @intFromEnum(part));
    for (0..GAME_NUM_TASKS) |i| {
        game.vm.tasks[i].pc = GAME_INACTIVE_TASK;
        game.vm.tasks[i].next_pc = GAME_INACTIVE_TASK;
        game.vm.tasks[i].state = 0;
        game.vm.tasks[i].next_state = 0;
    }
    game.vm.tasks[0].pc = 0;
    game.vm.screen_num = -1;
    if (pos >= 0) {
        game.vm.vars[0] = pos;
    }
    game.vm.start_time = game.elapsed;
    game.vm.time_stamp = game.elapsed;
    if (part == .water) {
        if (game.input.demo_joy.start()) {
            @memset(game.vm.vars[0..256], 0);
        }
    }
}

fn gameVmSetupTasks(game: *Game) void {
    if (game.res.next_part) |part| {
        restartAt(game, part, -1);
        game.res.next_part = null;
    }
    for (0..GAME_NUM_TASKS) |i| {
        game.vm.tasks[i].state = game.vm.tasks[i].next_state;
        const n = game.vm.tasks[i].next_pc;
        if (n != GAME_INACTIVE_TASK) {
            game.vm.tasks[i].pc = if (n == GAME_INACTIVE_TASK - 1) GAME_INACTIVE_TASK else n;
            game.vm.tasks[i].next_pc = GAME_INACTIVE_TASK;
        }
    }
}

fn gameVmExecuteTask(game: *Game) !void {
    const opcode = game.vm.ptr.fetchByte();
    if ((opcode & 0x80) != 0) {
        const off = ((@as(u16, opcode) << 8) | game.vm.ptr.fetchByte()) << 1;
        game.res.use_seg_video2 = false;
        var pt: Gfx.GamePoint = .{ .x = game.vm.ptr.fetchByte(), .y = game.vm.ptr.fetchByte() };
        const h = pt.y - 199;
        if (h > 0) {
            pt.y = 199;
            pt.x += h;
        }
        video_log.debug("vid_opcd_0x80 : opcode=0x{X} off=0x{X} x={} y={}", .{ opcode, off, pt.x, pt.y });
        game.video.setDataBuffer(game.res.seg_video1, off);
        game.video.drawShape(0xFF, 64, pt);
    } else if ((opcode & 0x40) == 0x40) {
        var pt: Gfx.GamePoint = undefined;
        const offsetHi = game.vm.ptr.fetchByte();
        const off = ((@as(u16, offsetHi) << 8) | game.vm.ptr.fetchByte()) << 1;
        pt.x = game.vm.ptr.fetchByte();
        game.res.use_seg_video2 = false;
        if ((opcode & 0x20) == 0) {
            if ((opcode & 0x10) == 0) {
                pt.x = (pt.x << 8) | game.vm.ptr.fetchByte();
            } else {
                pt.x = game.vm.vars[@intCast(pt.x)];
            }
        } else {
            if ((opcode & 0x10) != 0) {
                pt.x += 0x100;
            }
        }
        pt.y = game.vm.ptr.fetchByte();
        if ((opcode & 8) == 0) {
            if ((opcode & 4) == 0) {
                pt.y = (pt.y << 8) | game.vm.ptr.fetchByte();
            } else {
                pt.y = game.vm.vars[@intCast(pt.y)];
            }
        }
        var zoom: u16 = 64;
        if ((opcode & 2) == 0) {
            if ((opcode & 1) != 0) {
                zoom = @intCast(game.vm.vars[game.vm.ptr.fetchByte()]);
            }
        } else {
            if ((opcode & 1) != 0) {
                game.res.use_seg_video2 = true;
            } else {
                zoom = game.vm.ptr.fetchByte();
            }
        }
        video_log.debug("vid_opcd_0x40 : off=0x{X} x={} y={}", .{ off, pt.x, pt.y });
        game.video.setDataBuffer(if (game.res.use_seg_video2) game.res.seg_video2 else game.res.seg_video1, off);
        game.video.drawShape(0xFF, zoom, pt);
    } else if (opcode > 0x1A) {
        std.log.err("Script::executeTask() ec=0xFFF invalid opcode=0x{X}", .{opcode});
        return error.InvalidOpcode;
    } else {
        op_table[opcode](game);
    }
}

fn gameVmRun(game: *Game) !bool {
    var i = game.vm.current_task;
    if (!game.input.quit and game.vm.tasks[i].state == 0) {
        const n = game.vm.tasks[i].pc;
        if (n != GAME_INACTIVE_TASK) {
            // execute 1 step of 1 task
            game.vm.ptr = .{ .data = game.res.seg_code, .pc = n };
            game.vm.paused = false;
            vm_log.debug("Script::runTasks() i=0x{X} n=0x{X}", .{ i, n });
            try gameVmExecuteTask(game);
            game.vm.tasks[i].pc = game.vm.ptr.pc;
            vm_log.debug("Script::runTasks() i=0x{X} pos=0x{X}", .{ i, game.vm.tasks[i].pc });
            if (!game.vm.paused and game.vm.tasks[i].pc != GAME_INACTIVE_TASK) {
                return false;
            }
        }
    }

    var result = false;

    while (true) {
        // go to next active thread
        i = (i + 1) % GAME_NUM_TASKS;
        if (i == 0) {
            result = true;
            gameVmSetupTasks(game);
            gameVmUpdateInput(game);
        }

        if (game.vm.tasks[i].pc != GAME_INACTIVE_TASK) {
            game.vm.stack_ptr = 0;
            game.vm.current_task = i;
            break;
        }
    }

    return result;
}

fn gameVmUpdateInput(game: *Game) void {
    if (game.res.current_part == .password) {
        const c = game.input.last_char;
        if (c == 8 or c == 0 or (c >= 'a' and c <= 'z')) {
            game.vm.vars[GAME_VAR_LAST_KEYCHAR] = c & ~@as(u8, @intCast(0x20));
            game.input.last_char = 0;
        }
    }
    var lr: i16 = 0;
    var m: i16 = 0;
    var ud: i16 = 0;
    var jd: i16 = 0;
    if (game.input.dir_mask.right) {
        lr = 1;
        m |= 1;
    }
    if (game.input.dir_mask.left) {
        lr = -1;
        m |= 2;
    }
    if (game.input.dir_mask.down) {
        ud = 1;
        jd = 1;
        m |= 4; // crouch
    }
    if (game.input.dir_mask.up) {
        ud = -1;
        jd = -1;
        m |= 8; // jump
    }
    if (!(game.res.data_type == .amiga or game.res.data_type == .atari)) {
        game.vm.vars[GAME_VAR_HERO_POS_UP_DOWN] = ud;
    }
    game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = jd;
    game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = lr;
    game.vm.vars[GAME_VAR_HERO_POS_MASK] = m;
    var action: i16 = 0;
    if (game.input.action) {
        action = 1;
        m |= 0x80;
    }
    game.vm.vars[GAME_VAR_HERO_ACTION] = action;
    game.vm.vars[GAME_VAR_HERO_ACTION_POS_MASK] = m;
    if (game.res.current_part == .water) {
        const mask = game.input.demo_joy.update();
        if (mask != 0) {
            game.vm.vars[GAME_VAR_HERO_ACTION_POS_MASK] = mask;
            game.vm.vars[GAME_VAR_HERO_POS_MASK] = mask & 15;
            game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = 0;
            // TODO: change bit mask
            if ((mask & 1) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = 1;
            }
            if ((mask & 2) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_LEFT_RIGHT] = -1;
            }
            game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = 0;
            if ((mask & 4) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = 1;
            }
            if ((mask & 8) != 0) {
                game.vm.vars[GAME_VAR_HERO_POS_JUMP_DOWN] = -1;
            }
            game.vm.vars[GAME_VAR_HERO_ACTION] = (mask >> 7);
        }
    }
}

fn gameResInvalidateAll(game: *Game) void {
    for (0..game.res.num_mem_list) |i| {
        game.res.mem_list[i].status = .null;
    }
    game.res.script_cur = 0;
    game.video.current_pal = 0xFF;
}

pub fn gameResReadBank(game: *Game, me: *const GameMemEntry, dst_buf: []u8) bool {
    if (me.bank_num > 0xd)
        return false;

    if (game.res.data.banks.get(me.bank_num - 1)) |bank| {
        if (me.packed_size != me.unpacked_size) {
            return byteKillerUnpack(dst_buf[0..me.unpacked_size], bank[me.bank_pos..][0..me.packed_size]);
        } else {
            @memcpy(dst_buf[0..me.unpacked_size], bank[me.bank_pos..][0..me.packed_size]);
        }

        return true;
    }
    return false;
}

fn gameResLoad(game: *Game) void {
    while (true) {
        var me_found: ?*GameMemEntry = null;

        // get resource with max rank_num
        var max_num: u8 = 0;
        var resource_num: usize = 0;
        for (0..game.res.num_mem_list) |i| {
            const it = &game.res.mem_list[i];
            if (it.status == .toload and max_num <= it.rank_num) {
                max_num = it.rank_num;
                me_found = it;
                resource_num = i;
            }
        }
        if (me_found) |me| {
            var mem_ptr: []u8 = undefined;
            if (me.type == .bitmap) {
                mem_ptr = game.res.mem[game.res.vid_cur..];
            } else {
                mem_ptr = game.res.mem[game.res.script_cur..];
                const avail: usize = (game.res.vid_cur - game.res.script_cur);
                if (me.unpacked_size > avail) {
                    std.log.warn("Resource::load() not enough memory, available={}", .{avail});
                    me.status = .null;
                    continue;
                }
            }
            if (me.bank_num == 0) {
                std.log.warn("Resource::load() ec=0xF00 (me.bankNum == 0)", .{});
                me.status = .null;
            } else {
                bank_log.debug("Resource::load() bufPos=0x{X} size={} type={} pos=0x{X} bankNum={}", .{ game.res.mem.len - mem_ptr.len, me.packed_size, me.type, me.bank_pos, me.bank_num });
                if (gameResReadBank(game, me, mem_ptr)) {
                    if (me.type == .bitmap) {
                        game.video.copyBitmapPtr(game.res.mem[game.res.vid_cur..]);
                        me.status = .null;
                    } else {
                        me.buf_ptr = mem_ptr;
                        me.status = .loaded;
                        game.res.script_cur += me.unpacked_size;
                    }
                } else {
                    if (game.res.data_type == .dos and me.bank_num == 12 and me.type == .bank) {
                        // DOS demo version does not have the bank for this resource
                        // this should be safe to ignore as the resource does not appear to be used by the game code
                        me.status = .null;
                        continue;
                    }
                    std.log.err("Unable to read resource {} from bank {}", .{ resource_num, me.bank_num });
                }
            }
        } else break;
    }
}

fn gameResSetupPart(game: *Game, id: usize) void {
    if (@as(GamePart, @enumFromInt(id)) != game.res.current_part) {
        var ipal: u8 = 0;
        var icod: u8 = 0;
        var ivd1: u8 = 0;
        var ivd2: u8 = 0;
        if (id >= 16000 and id <= 16009) {
            const part = id - 16000;
            ipal = mem_list_parts[part][0];
            icod = mem_list_parts[part][1];
            ivd1 = mem_list_parts[part][2];
            ivd2 = mem_list_parts[part][3];
        } else {
            std.log.err("Resource::setupPart() ec=0xF07 invalid part", .{});
        }
        gameResInvalidateAll(game);
        game.res.mem_list[ipal].status = .toload;
        game.res.mem_list[icod].status = .toload;
        game.res.mem_list[ivd1].status = .toload;
        if (ivd2 != 0) {
            game.res.mem_list[ivd2].status = .toload;
        }
        gameResLoad(game);
        game.res.seg_video_pal = game.res.mem_list[ipal].buf_ptr;
        game.res.seg_code = game.res.mem_list[icod].buf_ptr;
        game.res.seg_code_size = @intCast(game.res.mem_list[icod].unpacked_size);
        game.res.seg_video1 = game.res.mem_list[ivd1].buf_ptr;
        if (ivd2 != 0) {
            game.res.seg_video2 = game.res.mem_list[ivd2].buf_ptr;
        }
        game.res.current_part = @enumFromInt(id);
    }
    game.res.script_bak = game.res.script_cur;
}

fn gameResDetectVersion(game: *Game) void {
    if (game.res.data.mem_list) |_| {
        // only DOS game has a memlist.bin file
        game.res.data_type = .dos;
        std.log.info("Using DOS data files", .{});
    } else {
        const detection = detectAmigaAtari(game.res.data.banks.bank01.?.len);
        if (detection) |detected| {
            game.res.data_type = detected.data_type;
            if (detected.data_type == .atari) {
                std.log.info("Using Atari data files", .{});
            } else {
                std.log.info("Using Amiga data files", .{});
            }
            game.res.num_mem_list = GAME_ENTRIES_COUNT;
            for (0..GAME_ENTRIES_COUNT) |i| {
                game.res.mem_list[i].type = @enumFromInt(detected.entries[i].type);
                game.res.mem_list[i].bank_num = detected.entries[i].bank;
                game.res.mem_list[i].bank_pos = detected.entries[i].offset;
                game.res.mem_list[i].packed_size = detected.entries[i].packed_size;
                game.res.mem_list[i].unpacked_size = detected.entries[i].unpacked_size;
            }
        }
    }
}

fn gameResUpdate(game: *Game, num: u16) void {
    if (num > 16000) {
        game.res.next_part = @enumFromInt(num);
        return;
    }

    var me = &game.res.mem_list[num];
    if (me.status == .null) {
        me.status = .toload;
        gameResLoad(game);
    }
}

fn gameResReadEntries(game: *Game) !void {
    switch (game.res.data_type) {
        .amiga, .atari => {
            assert(game.res.num_mem_list > 0);
        },
        .dos => {
            game.res.has_password_screen = false; // DOS demo versions do not have the resources
            const mem_list = game.res.data.mem_list orelse @panic("mem list is mandatory for pc version");
            var stream = std.io.fixedBufferStream(mem_list);
            var reader = stream.reader();
            while (true) {
                const status: GameResStatus = @enumFromInt(try reader.readByte());
                if (status == .uninit) {
                    game.res.has_password_screen = game.res.data.banks.bank08 != null;
                    return;
                }
                assert(game.res.num_mem_list < game.res.mem_list.len);
                var me = &game.res.mem_list[game.res.num_mem_list];
                me.status = status;
                me.type = @enumFromInt(try reader.readByte());
                me.buf_ptr = &[0]u8{};
                _ = try reader.readInt(u32, .big);
                me.rank_num = try reader.readByte();
                me.bank_num = try reader.readByte();
                me.bank_pos = try reader.readInt(u32, .big);
                me.packed_size = try reader.readInt(u32, .big);
                me.unpacked_size = try reader.readInt(u32, .big);
                game.res.num_mem_list += 1;
            }
        },
    }
}

fn gameResInvalidate(game: *Game) void {
    for (&game.res.mem_list) |*me| {
        if (@intFromEnum(me.type) <= 2 or @intFromEnum(me.type) > 6) {
            me.*.status = .null;
        }
    }
    game.res.script_cur = game.res.script_bak;
    game.video.current_pal = 0xFF;
}

fn mixi16(sample1: i32, sample2: i32) i16 {
    const sample: i32 = sample1 + sample2;
    return @intCast(if (sample < -32768) -32768 else if (sample > 32767) 32767 else sample);
}

fn toRawi16(a: i32) i16 {
    return @truncate(((a << 8) | a) - 32768);
}

fn toi16(a: i32) i16 {
    if (a <= -128) {
        return -32768;
    }
    if (a >= 127) {
        return 32767;
    }
    const uns_1: u8 = @as(u8, @bitCast(@as(i8, @intCast(a)))) ^ 0x80;
    const uns_2: u32 = @intCast(uns_1);
    const i = @as(i32, @bitCast((uns_2 << 8) | uns_2)) - 32768;
    return @intCast(i);
}

fn gameAudioInit(game: *Game, callback: GameAudioCallback) void {
    game.audio.callback = callback;
}

fn gameAudioSfxStart(game: *Game) void {
    snd_log.debug("SfxPlayer::start()", .{});
    game.audio.sfx_player.sfx_mod.cur_pos = 0;
}

fn gameAudioSfxSetEventsDelay(game: *Game, delay: u16) void {
    snd_log.debug("SfxPlayer::setEventsDelay({})", .{delay});
    game.audio.sfx_player.delay = delay;
}

fn gameAudioStopSound(game: *Game, channel: u2) void {
    snd_log.debug("Mixer::stopChannel({})", .{channel});
    game.audio.channels[channel].data = null;
}

fn gamePlaySfxMusic(game: *Game) void {
    var player = &game.audio.sfx_player;
    player.playing = true;
    player.samples_left = 0;
    player.channels = std.mem.zeroes(@TypeOf(player.channels));
}

fn gameAudioInitRaw(chan: *GameAudioChannel, data: []const u8, freq: i32, volume: i32, mixingFreq: i32) void {
    chan.data = data[8..];
    chan.pos.reset(freq, mixingFreq);

    const len: u32 = @as(u32, @intCast(util.readBeU16(data[0..]))) * 2;
    chan.loop_len = @as(u32, @intCast(util.readBeU16(data[2..]))) * 2;
    chan.loop_pos = if (chan.loop_len > 0) len else 0;
    chan.len = len;

    chan.volume = volume;
}

fn gameAudioSfxPrepareInstruments(game: *Game, buf: []const u8) void {
    var p = buf;
    var player = &game.audio.sfx_player;
    player.sfx_mod.samples = std.mem.zeroes(@TypeOf(player.sfx_mod.samples));
    for (&player.sfx_mod.samples, 0..) |*ins, i| {
        const res_num = std.mem.readInt(u16, p[0..2], .big);
        p = p[2..];
        if (res_num != 0) {
            ins.volume = util.readBeU16(p);
            const me = &game.res.mem_list[res_num];
            if (me.status == .loaded and me.type == .sound) {
                ins.data = me.buf_ptr;
                snd_log.debug("Loaded instrument 0x{X} n={} volume={}", .{ res_num, i, ins.volume });
            } else {
                snd_log.err("Error loading instrument 0x{X:0>2}", .{res_num});
            }
        }
        p = p[2..]; // skip volume
    }
}

fn gameAudioSfxLoadModule(game: *Game, res_num: u16, delay: u16, pos: u8) void {
    snd_log.debug("SfxPlayer::loadSfxModule(0x{X:0>2}, {}, {})", .{ res_num, delay, pos });
    var player = &game.audio.sfx_player;
    var me = &game.res.mem_list[res_num];
    if (me.status == .loaded and me.type == .music) {
        player.sfx_mod = std.mem.zeroes(@TypeOf(player.sfx_mod));
        player.sfx_mod.cur_order = pos;
        player.sfx_mod.num_order = me.buf_ptr[0x3F];
        snd_log.debug("SfxPlayer::loadSfxModule() curOrder = 0x{X} numOrder = 0x{X}", .{ player.sfx_mod.cur_order, player.sfx_mod.num_order });
        player.sfx_mod.order_table = me.buf_ptr[0x40..];
        if (delay == 0) {
            player.delay = util.readBeU16(me.buf_ptr);
        } else {
            player.delay = delay;
        }
        player.sfx_mod.data = me.buf_ptr[0xC0..];
        snd_log.debug("SfxPlayer::loadSfxModule() eventDelay = {} ms", .{player.delay});
        gameAudioSfxPrepareInstruments(game, me.buf_ptr[2..]);
    } else {
        snd_log.warn("SfxPlayer::loadSfxModule() ec=0xF8", .{});
    }
}

fn getSoundFreq(period: u8) i32 {
    return @divTrunc(GAME_PAULA_FREQ, @as(i32, @intCast(period_table[period])) * 2);
}

fn gameAudioPlaySoundRaw(game: *Game, channel: u2, data: []const u8, freq: i32, volume: u8) void {
    const chan = &game.audio.channels[channel];
    gameAudioInitRaw(chan, data, freq, volume, GAME_MIX_FREQ);
}

fn gameAudioStopSfxMusic(game: *Game) void {
    snd_log.debug("SfxPlayer::stop()", .{});
    game.audio.sfx_player.playing = false;
}

fn gameAudioStopAll(game: *Game) void {
    for (0..GAME_MIX_CHANNELS) |i| {
        gameAudioStopSound(game, @intCast(i));
    }
    gameAudioStopSfxMusic(game);
}

fn gameAudioMixRaw(chan: *GameAudioChannel, sample: *i16) void {
    if (chan.data) |data| {
        var pos = chan.pos.getInt();
        chan.pos.offset = @intCast(chan.pos.offset +% chan.pos.inc);
        if (chan.loop_len != 0) {
            if (pos >= chan.loop_pos + chan.loop_len) {
                pos = chan.loop_pos;
                chan.pos.offset = @intCast((chan.loop_pos << GameFrac.bits) +% chan.pos.inc);
            }
        } else if (pos >= chan.len) {
            chan.data = null;
            return;
        }
        sample.* = mixi16(sample.*, @divTrunc(@as(i32, toRawi16(data[pos] ^ 0x80)) * chan.volume, 64));
    }
}

fn gameAudioMixChannels(game: *Game, samples: []i16) void {
    var smp = samples;
    // TODO: kAmigaStereoChannels ?
    //     if (kAmigaStereoChannels) {
    //      for (int i = 0; i < count; i += 2) {
    //         _game_audio_mix_raw(&game.audio.channels[0], samples);
    //         _game_audio_mix_raw(&game.audio.channels[3], samples);
    //        ++samples;
    //        _game_audio_mix_raw(&game.audio.channels[1], samples);
    //        _game_audio_mix_raw(&game.audio.channels[2], samples);
    //        ++samples;
    //      }
    //    } else
    {
        while (smp.len > 0) {
            for (&game.audio.channels) |*channel| {
                gameAudioMixRaw(channel, &smp[0]);
            }
            smp[1] = smp[0];
            smp = smp[2..];
        }
    }
}

fn gameAudioSfxHandlePattern(game: *Game, channel: u2, data: []const u8) void {
    var player = &game.audio.sfx_player;
    var pat = std.mem.zeroes(GameAudioSfxPattern);
    pat.note_1 = util.readBeU16(data);
    pat.note_2 = util.readBeU16(data[2..]);
    if (pat.note_1 != 0xFFFD) {
        const sample: u16 = (pat.note_2 & 0xF000) >> 12;
        if (sample != 0) {
            const ptr = player.sfx_mod.samples[sample - 1].data;
            if (ptr.len > 0) {
                snd_log.debug("SfxPlayer::handlePattern() preparing sample {}", .{sample});
                pat.sample_volume = player.sfx_mod.samples[sample - 1].volume;
                pat.sample_start = 8;
                pat.sample_buffer = ptr;
                pat.sample_len = util.readBeU16(ptr) *% 2;
                const loop_len: u16 = util.readBeU16(ptr[2..]) *% 2;
                if (loop_len != 0) {
                    pat.loop_pos = pat.sample_len;
                    pat.loop_data = ptr;
                    pat.loop_len = loop_len;
                } else {
                    pat.loop_pos = 0;
                    pat.loop_data = null;
                    pat.loop_len = 0;
                }
                var m: i16 = @bitCast(pat.sample_volume);
                const effect: u8 = @truncate((@as(u16, @intCast(pat.note_2)) & 0x0F00) >> 8);
                if (effect == 5) { // volume up
                    const volume: u8 = @intCast(pat.note_2 & 0xFF);
                    m += volume;
                    if (m > 0x3F) {
                        m = 0x3F;
                    }
                } else if (effect == 6) { // volume down
                    const volume: u8 = @intCast(pat.note_2 & 0xFF);
                    m -= volume;
                    if (m < 0) {
                        m = 0;
                    }
                }
                player.channels[channel].volume = @bitCast(m);
                pat.sample_volume = @bitCast(m);
            }
        }
    }
    if (pat.note_1 == 0xFFFD) {
        snd_log.debug("SfxPlayer::handlePattern() _syncVar = 0x{X}", .{pat.note_2});
        game.vm.vars[GAME_VAR_MUSIC_SYNC] = @bitCast(pat.note_2);
    } else if (pat.note_1 != 0) {
        pat.period_arpeggio = pat.note_1;
        if (pat.period_arpeggio == 0xFFFE) {
            player.channels[channel] = std.mem.zeroes(@TypeOf(player.channels[channel]));
        } else if (pat.sample_buffer) |buf| {
            // TODO: fix and activate this: assert(pat.note_1 >= 0x37 and pat.note_1 < 0x1000);
            // convert Amiga period value to hz
            const freq: i32 = @divTrunc(GAME_PAULA_FREQ, @as(i32, @intCast(pat.note_1)) * 2);
            snd_log.debug("SfxPlayer::handlePattern() adding sample freq = 0x{X}", .{freq});
            var ch = &player.channels[channel];
            ch.sample_data = buf[pat.sample_start..];
            ch.sample_len = pat.sample_len;
            ch.sample_loop_pos = pat.loop_pos;
            ch.sample_loop_len = pat.loop_len;
            ch.volume = pat.sample_volume;
            ch.pos.offset = 0;
            ch.pos.inc = @divTrunc(@as(u64, @intCast(freq)) << GameFrac.bits, @as(u64, @intCast(GAME_MIX_FREQ)));
        }
    }
}

fn gameAudioSfxHandleEvents(game: *Game) void {
    var player = &game.audio.sfx_player;
    var order: usize = player.sfx_mod.order_table[player.sfx_mod.cur_order];
    var pattern_data = player.sfx_mod.data[@as(usize, player.sfx_mod.cur_pos) + order * 1024 ..];
    inline for (0..4) |ch| {
        gameAudioSfxHandlePattern(game, @intCast(ch), pattern_data);
        pattern_data = pattern_data[4..];
    }
    player.sfx_mod.cur_pos += 4 * 4;
    snd_log.debug("SfxPlayer::handleEvents() order = 0x{X} curPos = 0x{X}", .{ order, player.sfx_mod.cur_pos });
    if (player.sfx_mod.cur_pos >= 1024) {
        player.sfx_mod.cur_pos = 0;
        order = player.sfx_mod.cur_order + 1;
        if (order == player.sfx_mod.num_order) {
            gameAudioStopAll(game);
            order = 0;
            player.playing = false;
        }
        player.sfx_mod.cur_order = @truncate(order);
    }
}

fn gameAudioSfxMixChannel(s: *i16, ch: *GameAudioSfxChannel) void {
    if (ch.sample_len == 0) {
        return;
    }
    const pos1: i32 = @intCast(ch.pos.offset >> GameFrac.bits);
    ch.pos.offset = @intCast(ch.pos.offset +% ch.pos.inc);
    var pos2: i32 = pos1 + 1;
    if (ch.sample_loop_len != 0) {
        if (pos1 >= ch.sample_loop_pos +% ch.sample_loop_len - 1) {
            pos2 = ch.sample_loop_pos;
            ch.pos.offset = @bitCast(pos2 << GameFrac.bits);
        }
    } else if (pos1 >= ch.sample_len - 1) {
        ch.sample_len = 0;
        return;
    }
    const s1 = @as(i8, @bitCast(ch.sample_data[@intCast(pos1)]));
    const s2 = @as(i8, @bitCast(ch.sample_data[@intCast(pos2)]));
    var sample: i32 = ch.pos.interpolate(s1, s2);
    sample = s.* +% @as(i32, @intCast(toi16(@divTrunc(sample * ch.volume, 64))));
    s.* = if (sample < -32768) -32768 else if (sample > 32767) 32767 else @as(i16, @intCast(sample));
}

fn gameAudioSfxMixSamples(game: *Game, buffer: []i16) void {
    var buf = buffer;
    var len: i32 = @divTrunc(@as(i32, @intCast(buf.len)), 2);
    var player = &game.audio.sfx_player;
    while (len != 0) {
        if (player.samples_left == 0) {
            gameAudioSfxHandleEvents(game);
            const samples_per_tick = @divTrunc(GAME_MIX_FREQ * @divTrunc(@as(i32, @intCast(player.delay)) * 60 * 1000, GAME_PAULA_FREQ), 1000);
            player.samples_left = samples_per_tick;
        }
        var count = player.samples_left;
        if (count > len) {
            count = len;
        }
        player.samples_left -= count;
        len -= count;
        for (0..@intCast(count)) |_| {
            gameAudioSfxMixChannel(&buf[0], &player.channels[0]);
            gameAudioSfxMixChannel(&buf[0], &player.channels[3]);
            gameAudioSfxMixChannel(&buf[1], &player.channels[1]);
            gameAudioSfxMixChannel(&buf[1], &player.channels[2]);
            buf = buf[2..];
        }
    }
}

fn gameAudioSfxReadSamples(game: *Game, buf: []i16) void {
    const player = &game.audio.sfx_player;
    if (player.delay != 0) {
        gameAudioSfxMixSamples(game, buf);
    }
}

fn gameAudioUpdate(game: *Game, num_samples: usize) void {
    assert(num_samples < GAME_MIX_BUF_SIZE);
    assert(num_samples < GAME_MAX_AUDIO_SAMPLES);
    @memset(&game.audio.samples, 0);
    gameAudioMixChannels(game, game.audio.samples[0..num_samples]);
    gameAudioSfxReadSamples(game, game.audio.samples[0..num_samples]);
    for (game.audio.samples[0..num_samples], 0..) |sample, i| {
        game.audio.sample_buffer[i] = ((@as(f32, @floatFromInt(sample)) + 32768.0) / 32768.0) - 1.0;
    }
    if (game.audio.callback) |cb| {
        cb(game.audio.sample_buffer[0..num_samples]);
    }
}

pub fn gameKeyDown(game: *Game, input: GameInput) void {
    //assert(game && game->valid);
    switch (input) {
        .left => game.input.dir_mask.left = true,
        .right => game.input.dir_mask.right = true,
        .up => game.input.dir_mask.up = true,
        .down => game.input.dir_mask.down = true,
        .action => game.input.action = true,
        .back => game.input.back = true,
        .code => game.input.code = true,
        .pause => game.input.pause = true,
    }
}

pub fn gameKeyUp(game: *Game, input: GameInput) void {
    // assert(game && game->valid);
    switch (input) {
        .left => game.input.dir_mask.left = false,
        .right => game.input.dir_mask.right = false,
        .up => game.input.dir_mask.up = false,
        .down => game.input.dir_mask.down = false,
        .action => game.input.action = false,
        .back => game.input.back = false,
        .code => game.input.code = false,
        .pause => game.input.pause = false,
    }
}

pub fn gameCharPressed(game: *Game, c: u8) void {
    // GAME_ASSERT(game && game->valid);
    game.input.last_char = c;
}

fn sndPlaySound(game: *Game, resNum: u16, frequency: u8, volume: u8, channel: u2) void {
    var vol = volume;
    var freq = frequency;
    var chan = channel;
    snd_log.debug("snd_playSound(0x{X}, {}, {}, {})", .{ resNum, freq, vol, chan });
    if (vol == 0) {
        gameAudioStopSound(game, chan);
        return;
    }
    if (vol > 63) {
        vol = 63;
    }
    if (freq > 39) {
        freq = 39;
    }
    chan &= 3;
    const me = &game.res.mem_list[resNum];
    if (me.status == .loaded) {
        gameAudioPlaySoundRaw(game, chan, me.buf_ptr, getSoundFreq(freq), vol);
    }
}

fn opMovConst(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const n: i16 = @bitCast(game.vm.ptr.fetchWord());
    vm_log.debug("Script::op_movConst(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = n;
}

fn opMov(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const j = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_mov(0x{X:0>2}, 0x{X:0>2})", .{ i, j });
    game.vm.vars[i] = game.vm.vars[j];
}

fn opAdd(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const j = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_add(0x{X:0>2}, 0x{X:0>2})", .{ i, j });
    game.vm.vars[i] +%= game.vm.vars[j];
}

fn opAddConst(game: *Game) void {
    if (game.res.current_part == .luxe and game.vm.ptr.pc == 0x6D48) {
        vm_log.warn("Script::op_addConst() workaround for infinite looping gun sound", .{});
        // The script 0x27 slot 0x17 doesn't stop the gun sound from looping.
        // This is a bug in the original game code, confirmed by Eric Chahi and
        // addressed with the anniversary editions.
        // For older releases (DOS, Amiga), we play the 'stop' sound like it is
        // done in other part of the game code.
        //
        //  6D43: jmp(0x6CE5)
        //  6D46: break
        //  6D47: VAR(0x06) -= 50
        //
        sndPlaySound(game, 0x5B, 1, 63, 1);
    }
    const i = game.vm.ptr.fetchByte();
    const n: i16 = @bitCast(game.vm.ptr.fetchWord());
    vm_log.debug("Script::op_addConst(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = game.vm.vars[i] +% n;
}

fn opCall(game: *Game) void {
    const off = game.vm.ptr.fetchWord();
    vm_log.debug("Script::op_call(0x{X})", .{off});
    if (game.vm.stack_ptr == 0x40) {
        vm_log.err("Script::op_call() ec=0x8F stack overflow", .{});
    }
    game.vm.stack_calls[game.vm.stack_ptr] = game.vm.ptr.pc;
    game.vm.stack_ptr += 1;
    game.vm.ptr.pc = off;
}

fn opRet(game: *Game) void {
    vm_log.debug("Script::op_ret()", .{});
    if (game.vm.stack_ptr == 0) {
        vm_log.err("Script::op_ret() ec=0x8F stack underflow", .{});
    }
    game.vm.stack_ptr -= 1;
    game.vm.ptr.pc = game.vm.stack_calls[game.vm.stack_ptr];
}

fn opYieldTask(game: *Game) void {
    vm_log.debug("Script::op_yieldTask()", .{});
    game.vm.paused = true;
}

fn opJmp(game: *Game) void {
    const off = game.vm.ptr.fetchWord();
    vm_log.debug("Script::op_jmp(0x{X})", .{off});
    game.vm.ptr.pc = off;
}

fn opInstallTask(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const n = game.vm.ptr.fetchWord();
    vm_log.debug("Script::op_installTask(0x{X}, 0x{X})", .{ i, n });
    game.vm.tasks[i].next_pc = n;
}

fn opJmpIfVar(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_jmpIfVar(0x{X})", .{i});
    game.vm.vars[i] -= 1;
    if (game.vm.vars[i] != 0) {
        opJmp(game);
    } else {
        _ = game.vm.ptr.fetchWord();
    }
}

fn fixupPaletteChangeScreen(game: *Game, part: GamePart, screen: i32) void {
    var pal: ?u8 = null;
    switch (part) {
        .cite => if (screen == 0x47) { // bitmap resource #68
            pal = 8;
        },
        .luxe => if (screen == 0x4A) { // bitmap resources #144, #145
            pal = 1;
        },
        else => {},
    }
    if (pal) |p| {
        vm_log.debug("Setting palette {} for part {} screen {}", .{ p, part, screen });
        game.video.changePal(game.res.seg_video_pal, p);
    }
}

fn opCondJmp(game: *Game) void {
    const op = game.vm.ptr.fetchByte();
    const variable = game.vm.ptr.fetchByte();
    const b = game.vm.vars[variable];
    var a: i16 = undefined;
    if ((op & 0x80) != 0) {
        a = game.vm.vars[game.vm.ptr.fetchByte()];
    } else if ((op & 0x40) != 0) {
        a = @bitCast(game.vm.ptr.fetchWord());
    } else {
        a = @intCast(game.vm.ptr.fetchByte());
    }
    vm_log.debug("Script::op_condJmp({}, 0x{X:0>2}, 0x{X:0>2}) var=0x{X:0>2}", .{ op, @as(u16, @bitCast(b)), @as(u16, @bitCast(a)), variable });
    var expr = false;
    switch (op & 7) {
        0 => {
            expr = (b == a);
            if (!game.enable_protection) {
                if (game.res.current_part == .copy_protection) {
                    //
                    // 0CB8: jmpIf(VAR(0x29) == VAR(0x1E), @0CD3)
                    // ...
                    //
                    if (variable == 0x29 and (op & 0x80) != 0) {
                        // 4 symbols
                        game.vm.vars[0x29] = game.vm.vars[0x1E];
                        game.vm.vars[0x2A] = game.vm.vars[0x1F];
                        game.vm.vars[0x2B] = game.vm.vars[0x20];
                        game.vm.vars[0x2C] = game.vm.vars[0x21];
                        // counters
                        game.vm.vars[0x32] = 6;
                        game.vm.vars[0x64] = 20;
                        vm_log.warn("Script::op_condJmp() bypassing protection", .{});
                        expr = true;
                    }
                }
            }
        },
        1 => expr = (b != a),
        2 => expr = (b > a),
        3 => expr = (b >= a),
        4 => expr = (b < a),
        5 => expr = (b <= a),
        else => vm_log.warn("Script::op_condJmp() invalid condition {}", .{op & 7}),
    }
    if (expr) {
        opJmp(game);
        if (variable == GAME_VAR_SCREEN_NUM and game.vm.screen_num != game.vm.vars[GAME_VAR_SCREEN_NUM]) {
            fixupPaletteChangeScreen(game, game.res.current_part, game.vm.vars[GAME_VAR_SCREEN_NUM]);
            game.vm.screen_num = game.vm.vars[GAME_VAR_SCREEN_NUM];
        }
    } else {
        _ = game.vm.ptr.fetchWord();
    }
}

fn opSetPalette(game: *Game) void {
    const i = game.vm.ptr.fetchWord();
    const num = i >> 8;
    vm_log.debug("Script::op_changePalette({})", .{num});
    if (!game.gfx.fix_up_palette or game.res.current_part != .intro or (num != 10 and num != 16)) {
        game.video.next_pal = @intCast(num);
    }
}

fn opChangeTasksState(game: *Game) void {
    const start = game.vm.ptr.fetchByte();
    const end = game.vm.ptr.fetchByte();
    if (end < start) {
        vm_log.warn("Script::op_changeTasksState() ec=0x880 (end < start)", .{});
        return;
    }
    const state = game.vm.ptr.fetchByte();

    vm_log.debug("Script::op_changeTasksState({}, {}, {})", .{ start, end, state });

    if (state == 2) {
        for (start..end + 1) |i| {
            game.vm.tasks[i].next_pc = GAME_INACTIVE_TASK - 1;
        }
    } else if (state < 2) {
        for (start..end + 1) |i| {
            game.vm.tasks[i].next_state = state;
        }
    }
}

fn opSelectPage(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_selectPage({})", .{i});
    game.video.setWorkPagePtr(i);
}

fn opFillPage(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const color = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_fillPage({}, {})", .{ i, color });
    game.video.fillPage(i, color);
}

fn opCopyPage(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const j = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_copyPage({}, {})", .{ i, j });
    game.video.copyPage(i, j, game.vm.vars[GAME_VAR_SCROLL_Y]);
}

fn inpHandleSpecialKeys(game: *Game) void {
    if (game.input.pause) {
        if (game.res.current_part != .copy_protection and game.res.current_part != .intro) {
            game.input.pause = false;
        }
        game.input.pause = false;
    }
    if (game.input.back) {
        game.input.back = false;
    }
    if (game.input.code) {
        game.input.code = false;
        if (game.res.has_password_screen) {
            if (game.res.current_part != .password and game.res.current_part != .copy_protection) {
                game.res.next_part = .password;
            }
        }
    }
}

fn opUpdateDisplay(game: *Game) void {
    const page = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_updateDisplay({})", .{page});
    inpHandleSpecialKeys(game);

    if (game.enable_protection) {
        // entered protection symbols match the expected values
        if (game.res.current_part == .copy_protection and game.vm.vars[0x67] == 1) {
            game.vm.vars[0xDC] = 33;
        }
    }

    const frame_hz: i32 = 50;
    if (game.vm.vars[GAME_VAR_PAUSE_SLICES] != 0) {
        const delay: i32 = @as(i32, @intCast(game.elapsed)) - @as(i32, @intCast(game.vm.time_stamp));
        const pause = @divTrunc(@as(i32, @intCast(game.vm.vars[GAME_VAR_PAUSE_SLICES])) * 1000, frame_hz) - delay;
        if (pause > 0) {
            game.sleep += @as(u32, @intCast(pause));
        }
    }
    game.vm.time_stamp = game.elapsed;
    game.vm.vars[0xF7] = 0;

    game.video.updateDisplay(game.res.seg_video_pal, page);
}

fn opRemoveTask(game: *Game) void {
    vm_log.debug("Script::op_removeTask()", .{});
    game.vm.ptr.pc = 0xFFFF;
    game.vm.paused = true;
}

fn opDrawString(game: *Game) void {
    const strId = game.vm.ptr.fetchWord();
    const x: u16 = game.vm.ptr.fetchByte();
    const y: u16 = game.vm.ptr.fetchByte();
    const col: u16 = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_drawString(0x{X}, {}, {}, {})", .{ strId, x, y, col });
    const str = game.strings_table.find(strId);
    game.video.drawString(@truncate(col), x, y, str);
}

fn opSub(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const j = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_sub(0x{X}, 0x{X})", .{ i, j });
    game.vm.vars[i] -= game.vm.vars[j];
}

fn opAnd(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const n: u16 = game.vm.ptr.fetchWord();
    vm_log.debug("Script::op_and(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @bitCast(game.vm.vars[i])) & n);
}

fn opOr(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const n: i16 = @bitCast(game.vm.ptr.fetchWord());
    vm_log.debug("Script::op_or(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = game.vm.vars[i] | n;
}

fn opShl(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const n: u4 = @intCast(game.vm.ptr.fetchWord());
    vm_log.debug("Script::op_shl(0x{X:0>2}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @bitCast(game.vm.vars[i])) << n);
}

fn opShr(game: *Game) void {
    const i = game.vm.ptr.fetchByte();
    const n: u4 = @intCast(game.vm.ptr.fetchWord());
    vm_log.debug("Script::op_shr(0x{X:0>2}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @intCast(game.vm.vars[i])) >> n);
}

fn opPlaySound(game: *Game) void {
    const res_num = game.vm.ptr.fetchWord();
    const freq = game.vm.ptr.fetchByte();
    const vol: u8 = @truncate(game.vm.ptr.fetchByte());
    const channel = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_playSound(0x{X}, {}, {}, {})", .{ res_num, freq, vol, channel });
    sndPlaySound(game, res_num, freq, vol, @intCast(channel));
}

fn opUpdateResources(game: *Game) void {
    const num = game.vm.ptr.fetchWord();
    vm_log.debug("Script::op_updateResources({})", .{num});
    if (num == 0) {
        gameAudioStopAll(game);
        gameResInvalidate(game);
    } else {
        gameResUpdate(game, num);
    }
}

fn sndPlayMusic(game: *Game, resNum: u16, delay: u16, pos: u8) void {
    snd_log.debug("snd_playMusic(0x{X}, {}, {})", .{ resNum, delay, pos });
    // DT_AMIGA, DT_ATARI, DT_DOS
    if (resNum != 0) {
        gameAudioSfxLoadModule(game, resNum, delay, pos);
        gameAudioSfxStart(game);
        gamePlaySfxMusic(game);
    } else if (delay != 0) {
        gameAudioSfxSetEventsDelay(game, delay);
    } else {
        gameAudioStopSfxMusic(game);
    }
}

fn opPlayMusic(game: *Game) void {
    const res_num = game.vm.ptr.fetchWord();
    const delay = game.vm.ptr.fetchWord();
    const pos = game.vm.ptr.fetchByte();
    vm_log.debug("Script::op_playMusic(0x{X}, {}, {})", .{ res_num, delay, pos });
    sndPlayMusic(game, res_num, delay, pos);
}

const OpFunc = *const fn (*Game) void;
const op_table = [_]OpFunc{
    // 0x00
    &opMovConst,
    &opMov,
    &opAdd,
    &opAddConst,
    // 0x04
    &opCall,
    &opRet,
    &opYieldTask,
    &opJmp,
    // 0x08
    &opInstallTask,
    &opJmpIfVar,
    &opCondJmp,
    &opSetPalette,
    // 0x0C
    &opChangeTasksState,
    &opSelectPage,
    &opFillPage,
    &opCopyPage,
    // 0x10
    &opUpdateDisplay,
    &opRemoveTask,
    &opDrawString,
    &opSub,
    // 0x14
    &opAnd,
    &opOr,
    &opShl,
    &opShr,
    // 0x18
    &opPlaySound,
    &opUpdateResources,
    &opPlayMusic,
};
