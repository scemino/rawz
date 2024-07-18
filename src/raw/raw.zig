const std = @import("std");
const audio = @import("sokol").audio;
const glue = @import("../common/glue.zig");
const DemoJoy = @import("DemoJoy.zig");
const Strings = @import("Strings.zig");
const GameFrac = @import("GameFrac.zig");
pub const mementries = @import("mementries.zig");
pub const byteKillerUnpack = @import("unpack.zig").byteKillerUnpack;
pub const detectAmigaAtari = mementries.detectAmigaAtari;
pub const GameDataType = mementries.GameDataType;
pub const GameLang = Strings.GameLang;
const DefaultPrng = std.rand.DefaultPrng;
const assert = std.debug.assert;

pub const GAME_WIDTH = 320;
pub const GAME_HEIGHT = 200;

const GAME_ENTRIES_COUNT = 146;
const GAME_MEM_BLOCK_SIZE = 1 * 1024 * 1024;
const GAME_NUM_TASKS = 64;

const GAME_MIX_FREQ = 22050;
const GAME_MIX_BUF_SIZE = 4096 * 8;
const GAME_MIX_CHANNELS = 4;
const GAME_SFX_NUM_CHANNELS = 4;
const GAME_MAX_AUDIO_SAMPLES = 2048 * 16; // max number of audio samples in internal sample buffer

const GFX_COL_ALPHA = 0x10; // transparent pixel (OR'ed with 0x8)
const GFX_COL_PAGE = 0x11; // buffer 0 pixel

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

const GameMemEntry = struct {
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

const GameGfxFormat = enum(u2) {
    clut,
    rgb555,
    rgb,
    rgba,
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

const GamePc = struct {
    data: []u8,
    pc: u16,
};

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

const GameBanks = struct {
    bank01: []const u8,
    bank02: ?[]const u8 = null,
    bank03: ?[]const u8 = null,
    bank04: ?[]const u8 = null,
    bank05: ?[]const u8 = null,
    bank06: ?[]const u8 = null,
    bank07: ?[]const u8 = null,
    bank08: ?[]const u8 = null,
    bank09: ?[]const u8 = null,
    bank0A: ?[]const u8 = null,
    bank0B: ?[]const u8 = null,
    bank0C: ?[]const u8 = null,
    bank0D: ?[]const u8 = null,

    fn get(self: GameBanks, i: usize) ?[]const u8 {
        switch (i + 1) {
            0x1 => return self.bank01,
            0x2 => return self.bank02,
            0x3 => return self.bank03,
            0x4 => return self.bank04,
            0x5 => return self.bank05,
            0x6 => return self.bank06,
            0x7 => return self.bank07,
            0x8 => return self.bank08,
            0x9 => return self.bank09,
            0xA => return self.bank0A,
            0xB => return self.bank0B,
            0xC => return self.bank0C,
            0xD => return self.bank0D,
            else => return null,
        }
        unreachable;
    }
};

const GameData = struct {
    mem_list: ?[]const u8 = null,
    banks: GameBanks,
    demo3_joy: ?[]const u8 = null, // contains content of demo3.joy file if present
};

const GameRes = struct {
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
    part_num: GamePart, // indicates the part number where the fame starts
    use_ega: bool, // true to use EGA palette, false to use VGA palette
    lang: GameLang, // language to use
    enable_protection: bool,
    audio: GameAudioDesc,
    //TODO: debug = game_debug_t,
    data: GameData,
};

const GamePoint = struct { x: i16 = 0, y: i16 = 0 };

const GameQuadStrip = struct {
    num_vertices: u8 = 0,
    vertices: [GAME_QUAD_STRIP_MAX_VERTICES]GamePoint,
};

const GameFramebuffer = struct {
    buffer: [GAME_WIDTH * GAME_HEIGHT]u8,
};

const GameStrEntry = struct {
    id: u16,
    str: []const u8,
};

pub const Game = struct {
    const Gfx = struct {
        fb: [GAME_WIDTH * GAME_HEIGHT]u8, // frame buffer: this where is stored the image with indexed color
        fbs: [4]GameFramebuffer,
        palette: [256]u32, // palette containing 16 RGBA colors
        draw_page: u2,
        fix_up_palette: bool, // redraw all primitives on setPal script call
    };

    const Audio = struct {
        sample_buffer: [GAME_MAX_AUDIO_SAMPLES]f32,
        samples: [GAME_MIX_BUF_SIZE]i16,
        channels: [GAME_MIX_CHANNELS]GameAudioChannel,
        sfx_player: GameAudioSfxPlayer,
        callback: GameAudioCallback,
    };

    const Video = struct {
        next_pal: u8,
        current_pal: u8,
        buffers: [3]u2,
        p_data: GamePc,
        data_buf: []u8,
        use_ega: bool,
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
    part_num: GamePart,
    elapsed: u32,
    sleep: u32,

    gfx: Gfx,

    audio: Audio,
    video: Video,

    vm: Vm,

    input: Input,

    title: [:0]const u8, // title of the game
};

pub fn displayInfo(game: ?*Game) glue.DisplayInfo {
    return .{
        .fb = .{
            .dim = .{
                .width = GAME_WIDTH,
                .height = GAME_HEIGHT,
            },
            .buffer = if (game) |self| .{ .Palette8 = &self.gfx.fb } else null,
        },
        .view = .{
            .x = 0,
            .y = 0,
            .width = GAME_WIDTH,
            .height = GAME_HEIGHT,
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
    game.video.use_ega = desc.use_ega;

    game.res.data = desc.data;
    if (game.res.data.demo3_joy) |demo| {
        game.input.demo_joy.read(demo);
    }

    // g_debugMask = GAME_DBG_INFO | GAME_DBG_VIDEO | GAME_DBG_SND | GAME_DBG_SCRIPT | GAME_DBG_BANK;
    gameResDetectVersion(game);
    gameVideoInit(game);
    game.res.has_password_screen = true;
    game.res.script_bak = 0;
    game.res.script_cur = 0;
    game.res.vid_cur = GAME_MEM_BLOCK_SIZE - (GAME_WIDTH * GAME_HEIGHT / 2); // 4bpp bitmap
    try gameResReadEntries(game);

    gameGfxSetWorkPagePtr(game, 2);

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
        game.part_num = .copy_protection;
    }

    const num = @intFromEnum(game.part_num);
    if (num < 36) {
        gameVmRestartAt(game, @enumFromInt(restart_pos[num * 2]), restart_pos[num * 2 + 1]);
    } else {
        gameVmRestartAt(game, @enumFromInt(num), -1);
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

fn gameVmRestartAt(game: *Game, part: GamePart, pos: i16) void {
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
        gameVmRestartAt(game, part, -1);
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
    const opcode = fetchByte(&game.vm.ptr);
    if ((opcode & 0x80) != 0) {
        const off = ((@as(u16, opcode) << 8) | fetchByte(&game.vm.ptr)) << 1;
        game.res.use_seg_video2 = false;
        var pt: GamePoint = .{ .x = fetchByte(&game.vm.ptr), .y = fetchByte(&game.vm.ptr) };
        const h = pt.y - 199;
        if (h > 0) {
            pt.y = 199;
            pt.x += h;
        }
        std.log.debug("vid_opcd_0x80 : opcode=0x{X} off=0x{X} x={} y={}", .{ opcode, off, pt.x, pt.y });
        gameVideoSetDataBuffer(game, game.res.seg_video1, off);
        gameVideoDrawShape(game, 0xFF, 64, pt);
    } else if ((opcode & 0x40) == 0x40) {
        var pt: GamePoint = undefined;
        const offsetHi = fetchByte(&game.vm.ptr);
        const off = ((@as(u16, offsetHi) << 8) | fetchByte(&game.vm.ptr)) << 1;
        pt.x = fetchByte(&game.vm.ptr);
        game.res.use_seg_video2 = false;
        if ((opcode & 0x20) == 0) {
            if ((opcode & 0x10) == 0) {
                pt.x = (pt.x << 8) | fetchByte(&game.vm.ptr);
            } else {
                pt.x = game.vm.vars[@intCast(pt.x)];
            }
        } else {
            if ((opcode & 0x10) != 0) {
                pt.x += 0x100;
            }
        }
        pt.y = fetchByte(&game.vm.ptr);
        if ((opcode & 8) == 0) {
            if ((opcode & 4) == 0) {
                pt.y = (pt.y << 8) | fetchByte(&game.vm.ptr);
            } else {
                pt.y = game.vm.vars[@intCast(pt.y)];
            }
        }
        var zoom: u16 = 64;
        if ((opcode & 2) == 0) {
            if ((opcode & 1) != 0) {
                zoom = @intCast(game.vm.vars[fetchByte(&game.vm.ptr)]);
            }
        } else {
            if ((opcode & 1) != 0) {
                game.res.use_seg_video2 = true;
            } else {
                zoom = fetchByte(&game.vm.ptr);
            }
        }
        std.log.debug("vid_opcd_0x40 : off=0x{X} x={} y={}", .{ off, pt.x, pt.y });
        gameVideoSetDataBuffer(game, if (game.res.use_seg_video2) game.res.seg_video2 else game.res.seg_video1, off);
        gameVideoDrawShape(game, 0xFF, zoom, pt);
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
            // std.log.debug("Script::runTasks() i=0x{X} n=0x{X}", .{ i, n });
            try gameVmExecuteTask(game);
            game.vm.tasks[i].pc = game.vm.ptr.pc;
            // std.log.debug("Script::runTasks() i=0x{X} pos=0x{X}", .{ i, game.vm.tasks[i].pc });
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

fn gameResReadBank(game: *Game, me: *const GameMemEntry, dst_buf: []u8) bool {
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
                std.log.debug("Resource::load() bufPos=0x{X} size={} type={} pos=0x{X} bankNum={}", .{ game.res.mem.len - mem_ptr.len, me.packed_size, me.type, me.bank_pos, me.bank_num });
                if (gameResReadBank(game, me, mem_ptr)) {
                    if (me.type == .bitmap) {
                        gameVideoCopyBitmapPtr(game, game.res.mem[game.res.vid_cur..]);
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
        std.log.debug("Using DOS data files", .{});
    } else {
        const detection = detectAmigaAtari(game.res.data.banks.bank01.len);
        if (detection) |detected| {
            game.res.data_type = detected.data_type;
            if (detected.data_type == .atari) {
                std.log.debug("Using Atari data files", .{});
            } else {
                std.log.debug("Using Amiga data files", .{});
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

fn gameVideoInit(game: *Game) void {
    game.video.next_pal = 0xFF;
    game.video.current_pal = 0xFF;
    game.video.buffers[2] = gameVideoGetPagePtr(game, 1);
    game.video.buffers[1] = gameVideoGetPagePtr(game, 2);
    gameVideoSetWorkPagePtr(game, 0xfe);
}

fn gameVideoGetPagePtr(game: *Game, page: u8) u2 {
    if (page <= 3) {
        return @truncate(page);
    }

    switch (page) {
        0xFF => return game.video.buffers[2],
        0xFE => return game.video.buffers[1],
        else => {
            std.log.warn("Video::getPagePtr() p != [0,1,2,3,0xFF,0xFE] == 0x{X}", .{page});
            return 0; // XXX check
        },
    }
}

fn gameVideoSetWorkPagePtr(game: *Game, page: u8) void {
    std.log.debug("Video::setWorkPagePtr({})", .{page});
    game.video.buffers[0] = gameVideoGetPagePtr(game, page);
}

fn decodeAmiga(src: []const u8, dst: []u8) void {
    const plane_size = GAME_HEIGHT * GAME_WIDTH / 8;
    var s: usize = 0;
    var d: usize = 0;
    for (0..GAME_HEIGHT) |_| {
        var x: usize = 0;
        while (x < GAME_WIDTH) : (x += 8) {
            inline for (0..8) |b| {
                const mask = 1 << (7 - b);
                var color: u8 = 0;
                inline for (0..4) |p| {
                    if ((src[s + p * plane_size] & mask) != 0) {
                        color |= 1 << p;
                    }
                }
                dst[d] = color;
                d += 1;
            }
            s += 1;
        }
    }
}

fn decodeAtari(source: []const u8, dest: []u8) void {
    var src = source;
    var dst = dest;
    for (0..GAME_HEIGHT) |_| {
        var x: usize = 0;
        while (x < GAME_WIDTH) : (x += 16) {
            inline for (0..16) |b| {
                const mask = 1 << (15 - b);
                var color: u8 = 0;
                inline for (0..4) |p| {
                    if ((readBeU16(src[p * 2 ..]) & mask) != 0) {
                        color |= 1 << p;
                    }
                }
                dst[0] = color;
                dst = dst[1..];
            }
            src = src[8..];
        }
    }
}

fn clut(source: []const u8, pal: []const u8, w: i32, h: i32, bpp: i32, flipY: bool, colorKey: i32, dest: []u8) void {
    var src = source;
    var dst = dest;
    var dstPitch = bpp * w;
    if (flipY) {
        dst = dst[@intCast((h - 1) * bpp * w)..];
        dstPitch = -bpp * w;
    }
    for (0..@intCast(h)) |_| {
        for (0..@intCast(w)) |x| {
            const color: usize = src[x];
            const b: i32 = pal[color * 4];
            const g: i32 = pal[color * 4 + 1];
            const r: i32 = pal[color * 4 + 2];
            dst[x * @as(usize, @intCast(bpp))] = @intCast(r);
            dst[x * @as(usize, @intCast(bpp)) + 1] = @intCast(g);
            dst[x * @as(usize, @intCast(bpp)) + 2] = @intCast(b);
            if (bpp == 4) {
                dst[x * @as(usize, @intCast(bpp)) + 3] = if (color == 0 or (colorKey == ((r << 16) | (g << 8) | b))) 0 else 255;
            }
        }
        src = src[@intCast(w)..];
        dst = dst[@intCast(dstPitch)..];
    }
}

fn decodeBitmap(src: []const u8, w: *u16, h: *u16, allocator: std.mem.Allocator) ?[]u8 {
    if (!std.mem.eql(u8, src[0..2], "BM")) {
        return null;
    }
    const imageOffset: u32 = readLeU32(src[0xA..]);
    const width: i32 = @bitCast(readLeU32(src[0x12..]));
    const height: i32 = @bitCast(readLeU32(src[0x16..]));
    const depth: i32 = @intCast(readLeU16(src[0x1C..]));
    const compression: i32 = @bitCast(readLeU32(src[0x1E..]));
    if ((depth != 8 and depth != 32) or compression != 0) {
        std.log.warn("Unhandled bitmap depth {} compression {}", .{ depth, compression });
        return null;
    }
    const bpp = 3;
    var dst = allocator.alloc(u8, @intCast(width * height * bpp)) catch {
        std.log.warn("Failed to allocate bitmap buffer, width {} height {} bpp {}", .{ width, height, bpp });
        return null;
    };
    if (depth == 8) {
        const palette = src[14 + 40 ..]; // /BITMAPFILEHEADER + BITMAPINFOHEADER
        const flipY = true;
        clut(src[imageOffset..], palette, width, height, bpp, flipY, -1, dst);
    } else {
        assert(depth == 32 and bpp == 3);
        var p = src[imageOffset..];
        var y: i32 = height - 1;
        while (y >= 0) : (y -= 1) {
            var q = dst[@intCast(y * width * bpp)..];
            for (0..@intCast(width)) |_| {
                const color: u32 = readLeU32(p);
                p = p[4..];
                q[0] = @intCast((color >> 16) & 255);
                q[1] = @intCast((color >> 8) & 255);
                q[2] = @intCast(color & 255);
                q = q[3..];
            }
        }
    }
    w.* = @intCast(width);
    h.* = @intCast(height);
    return dst;
}

fn gameVideoScaleBitmap(game: *Game, src: []const u8, fmt: GameGfxFormat) void {
    gameGfxDrawBitmap(game, game.video.buffers[0], src, GAME_WIDTH, GAME_HEIGHT, fmt);
}

fn gameVideoCopyBitmapPtr(game: *Game, src: []const u8) void {
    if (game.res.data_type == .dos or game.res.data_type == .amiga) {
        var temp_bitmap: [GAME_WIDTH * GAME_HEIGHT]u8 = undefined;
        decodeAmiga(src, &temp_bitmap);
        gameVideoScaleBitmap(game, temp_bitmap[0..], .clut);
    } else if (game.res.data_type == .atari) {
        var temp_bitmap: [GAME_WIDTH * GAME_HEIGHT]u8 = undefined;
        decodeAtari(src, &temp_bitmap);
        gameVideoScaleBitmap(game, &temp_bitmap, .clut);
    } else { // .BMP
        var w: u16 = undefined;
        var h: u16 = undefined;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        if (decodeBitmap(src, &w, &h, gpa.allocator())) |buf| {
            gameGfxDrawBitmap(game, game.video.buffers[0], buf, w, h, .rgb);
            gpa.allocator().free(buf);
        }
    }
}

const palette_ega = [_]u8{
    0x00, 0x00, 0x00, // black #0
    0x00, 0x00, 0xAA, // blue #1
    0x00, 0xAA, 0x00, // green #2
    0x00, 0xAA, 0xAA, // cyan #3
    0xAA, 0x00, 0x00, // red #4
    0xAA, 0x00, 0xAA, // magenta #5
    0xAA, 0x55, 0x00, // yellow, brown #20
    0xAA, 0xAA, 0xAA, // white, light gray #7
    0x55, 0x55, 0x55, // dark gray, bright black #56
    0x55, 0x55, 0xFF, // bright blue #57
    0x55, 0xFF, 0x55, // bright green #58
    0x55, 0xFF, 0xFF, // bright cyan #59
    0xFF, 0x55, 0x55, // bright red #60
    0xFF, 0x55, 0xFF, // bright magenta #61
    0xFF, 0xFF, 0x55, // bright yellow #62
    0xFF, 0xFF, 0xFF, // bright white #63
};

fn gameVideoReadPaletteEga(buf: []const u8, num: u8, pal: *[16]u32) void {
    var p = buf[@as(usize, @intCast(num)) * 16 * @sizeOf(u16) ..];
    p = p[1024..]; // EGA colors are stored after VGA (Amiga)
    inline for (0..16) |i| {
        const color: usize = readBeU16(p);
        p = p[2..];
        // if (1)
        {
            const ega = palette_ega[3 * ((color >> 12) & 15) ..][0..3];
            pal[i] = 0xFF000000 | @as(u32, @intCast(ega[0])) | (@as(u32, @intCast(ega[1])) << 8) | (@as(u32, @intCast(ega[2])) << 16);
        }
        //  else { // lower 12 bits hold other colors
        // 	uint32_t r = (color >> 8) & 0xF;
        // 	uint32_t g = (color >> 4) & 0xF;
        // 	uint32_t b =  color       & 0xF;
        // 	r = (r << 4) | r;
        // 	g = (g << 4) | g;
        // 	b = (b << 4) | b;
        //     pal[i] = 0xFF000000 | (((uint32_t)r)) | (((uint32_t)g) << 8) | (((uint32_t)b) << 16);
        // }
    }
}

fn gameVideoReadPaletteAmiga(buf: []const u8, num: u8, pal: *[16]u32) void {
    var p = buf[@as(usize, @intCast(num)) * 16 * @sizeOf(u16) ..];
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

fn gameVideoChangePal(game: *Game, pal_num: u8) void {
    if (pal_num < 32 and pal_num != game.video.current_pal) {
        var pal: [16]u32 = [1]u32{0} ** 16;
        if (game.res.data_type == .dos and game.video.use_ega) {
            gameVideoReadPaletteEga(game.res.seg_video_pal, pal_num, &pal);
        } else {
            gameVideoReadPaletteAmiga(game.res.seg_video_pal, pal_num, &pal);
        }
        gameGfxSetPalette(game, pal);
        game.video.current_pal = pal_num;
    }
}

fn gameVideoFillPage(game: *Game, page: u8, color: u8) void {
    std.log.debug("Video::fillPage({}, {})", .{ page, color });
    gameGfxClearBuffer(game, gameVideoGetPagePtr(game, page), color);
}

fn gameVideoCopyPage(game: *Game, s: u8, dst: u8, vscroll: i16) void {
    var src = s;
    std.log.debug("Video::copyPage({}, {})", .{ src, dst });
    if (src < 0xFE) {
        src = src & 0xBF; //~0x40
    }
    if (src >= 0xFE or (src & 0x80) == 0) { // no vscroll
        gameGfxCopyBuffer(game, gameVideoGetPagePtr(game, dst), gameVideoGetPagePtr(game, src), 0);
    } else {
        const sl = gameVideoGetPagePtr(game, src & 3);
        const dl = gameVideoGetPagePtr(game, dst);
        if (sl != dl and vscroll >= -199 and vscroll <= 199) {
            gameGfxCopyBuffer(game, dl, sl, vscroll);
        }
    }
}

fn gameVideoSetDataBuffer(game: *Game, dataBuf: []u8, offset: u16) void {
    game.video.data_buf = dataBuf;
    game.video.p_data = .{ .data = dataBuf, .pc = offset };
}

fn gameVideoDrawShapeParts(game: *Game, zoom: u16, pgc: GamePoint) void {
    const pt = GamePoint{
        .x = pgc.x - @as(i16, @intCast(fetchByte(&game.video.p_data) * zoom / 64)),
        .y = pgc.y - @as(i16, @intCast(fetchByte(&game.video.p_data) * zoom / 64)),
    };
    const n: usize = @intCast(fetchByte(&game.video.p_data));
    std.log.debug("Video::drawShapeParts n={}", .{n});
    for (0..n + 1) |_| {
        var offset = fetchWord(&game.video.p_data);
        const po = GamePoint{
            .x = @intCast(@as(i32, @intCast(pt.x)) + @divTrunc(@as(i32, @intCast(fetchByte(&game.video.p_data))) * zoom, 64)),
            .y = @intCast(@as(i32, @intCast(pt.y)) + @divTrunc(@as(i32, @intCast(fetchByte(&game.video.p_data))) * zoom, 64)),
        };
        var color: u16 = 0xFF;
        if ((offset & 0x8000) != 0) {
            color = fetchByte(&game.video.p_data);
            _ = fetchByte(&game.video.p_data);
            color &= 0x7F;
        }
        offset <<= 1;
        const bak = game.video.p_data.pc;
        game.video.p_data = .{ .data = game.video.data_buf, .pc = offset };
        gameVideoDrawShape(game, @truncate(color), zoom, po);
        game.video.p_data.pc = bak;
    }
}

fn gameVideoDrawShape(game: *Game, c: u8, zoom: u16, pt: GamePoint) void {
    var color = c;
    var i = fetchByte(&game.video.p_data);
    if (i >= 0xC0) {
        if ((color & 0x80) != 0) {
            color = i & 0x3F;
        }
        gameVideoFillPolygon(game, color, zoom, pt);
    } else {
        i &= 0x3F;
        if (i == 1) {
            std.log.warn("Video::drawShape() ec=0xF80 (i != 2)", .{});
        } else if (i == 2) {
            gameVideoDrawShapeParts(game, zoom, pt);
        } else {
            std.log.warn("Video::drawShape() ec=0xFBB (i != 2)", .{});
        }
    }
}

fn gameVideoFillPolygon(game: *Game, color: u16, zoom: u16, pt: GamePoint) void {
    var pc = game.video.p_data;

    const bbw: u16 = pc.data[pc.pc] * zoom / 64;
    const bbh: u16 = pc.data[pc.pc + 1] * zoom / 64;
    pc.pc += 2;

    const x1: i16 = @intCast(pt.x - @as(i16, @intCast(bbw / 2)));
    const x2: i16 = @intCast(pt.x + @as(i16, @intCast(bbw / 2)));
    const y1: i16 = @intCast(pt.y - @as(i16, @intCast(bbh / 2)));
    const y2: i16 = @intCast(pt.y + @as(i16, @intCast(bbh / 2)));

    if (x1 >= GAME_WIDTH or x2 < 0 or y1 >= GAME_HEIGHT or y2 < 0)
        return;

    var qs: GameQuadStrip = undefined;
    qs.num_vertices = pc.data[pc.pc];
    pc.pc += 1;
    if ((qs.num_vertices & 1) != 0) {
        std.log.warn("Unexpected number of vertices {}", .{qs.num_vertices});
        return;
    }
    assert(qs.num_vertices < GAME_QUAD_STRIP_MAX_VERTICES);

    for (0..qs.num_vertices) |i| {
        qs.vertices[i] = .{
            .x = @intCast(@as(i32, x1) + @as(i32, pc.data[pc.pc] * zoom / 64)),
            .y = @intCast(@as(i32, y1) + @as(i32, pc.data[pc.pc + 1] * zoom / 64)),
        };
        pc.pc += 2;
    }

    if (qs.num_vertices == 4 and bbw == 0 and bbh <= 1) {
        gameGfxDrawPointPage(game, game.video.buffers[0], @truncate(color), pt);
    } else {
        gameGfxDrawQuadStrip(game, game.video.buffers[0], @truncate(color), &qs);
    }
}

fn swap(x: anytype, y: anytype) void {
    const tmp = y.*;
    y.* = x.*;
    x.* = tmp;
}

fn gameVideoUpdateDisplay(game: *Game, page: u8) void {
    std.log.debug("Video::updateDisplay({})", .{page});
    if (page != 0xFE) {
        if (page == 0xFF) {
            swap(&game.video.buffers[1], &game.video.buffers[2]);
        } else {
            game.video.buffers[1] = gameVideoGetPagePtr(game, page);
        }
    }
    if (game.video.next_pal != 0xFF) {
        gameVideoChangePal(game, game.video.next_pal);
        game.video.next_pal = 0xFF;
    }
    gameGfxDrawBuffer(game, game.video.buffers[1]);
}

fn gameVideoDrawString(game: *Game, color: u8, xx: u16, yy: u16, strId: u16) void {
    var x = xx;
    var y = yy;
    const escapedChars = false;
    const str = game.strings_table.find(strId);

    std.log.debug("drawString({}, {}, {}, '{s}')", .{ color, x, y, str });
    const len = str.len;
    for (0..len) |i| {
        if (str[i] == '\n' or str[i] == '\r') {
            y += 8;
            x = xx;
        } else if (str[i] == '\\' and escapedChars) {
            i += 1;
            if (i < len) {
                switch (str[i]) {
                    'n' => {
                        y += 8;
                        x = xx;
                    },
                }
            }
        } else {
            const pt: GamePoint = .{ .x = @as(i16, @bitCast(x * 8)), .y = @as(i16, @bitCast(y)) };
            gameGfxDrawStringChar(game, game.video.buffers[0], color, str[i], pt);
            x += 1;
        }
    }
}

fn gameGfxSetPalette(game: *Game, colors: [16]u32) void {
    assert(colors.len <= 16);
    @memcpy(game.gfx.palette[0..16], colors[0..16]);
}

fn gameGfxGetPagePtr(game: *Game, page: u2) *[GAME_WIDTH * GAME_HEIGHT]u8 {
    return &game.gfx.fbs[page].buffer;
}

fn gameGfxSetWorkPagePtr(game: *Game, page: u2) void {
    game.gfx.draw_page = page;
}

fn gameGfxClearBuffer(game: *Game, page: u2, color: u8) void {
    @memset(gameGfxGetPagePtr(game, page), color);
}

fn gameGfxCopyBuffer(game: *Game, dst: u2, src: u2, vscroll: i32) void {
    if (vscroll == 0) {
        @memcpy(gameGfxGetPagePtr(game, dst), gameGfxGetPagePtr(game, src));
    } else if (vscroll >= -199 and vscroll <= 199) {
        const dy = vscroll;
        if (dy < 0) {
            const size: usize = @as(usize, @intCast(GAME_HEIGHT + dy)) * GAME_WIDTH;
            @memcpy(gameGfxGetPagePtr(game, dst)[0..size], gameGfxGetPagePtr(game, src)[@as(usize, @intCast(-dy * GAME_WIDTH))..][0..size]);
        } else {
            const size: usize = @as(usize, @intCast(GAME_HEIGHT - dy)) * GAME_WIDTH;
            @memcpy(gameGfxGetPagePtr(game, dst)[@as(usize, @intCast(dy * GAME_WIDTH))..][0..size], gameGfxGetPagePtr(game, src)[0..size]);
        }
    }
}

fn gameGfxDrawBuffer(game: *Game, num: u2) void {
    const src = gameGfxGetPagePtr(game, num);
    @memcpy(game.gfx.fb[0..], src[0 .. GAME_WIDTH * GAME_HEIGHT]);
}

fn gameGfxDrawChar(game: *Game, c: u8, x: u16, y: u16, color: u8) void {
    if ((x <= GAME_WIDTH - 8) and (y <= GAME_HEIGHT - 8)) {
        const ft = font[(@as(usize, @intCast(c - 0x20))) * 8 ..];
        const offset = (x + y * GAME_WIDTH);
        for (0..8) |j| {
            const ch = ft[j];
            inline for (0..8) |i| {
                if ((ch & (1 << (7 - i))) != 0) {
                    game.gfx.fbs[game.gfx.draw_page].buffer[offset + j * GAME_WIDTH + i] = color;
                }
            }
        }
    }
}

fn gameGfxDrawStringChar(game: *Game, page: u2, color: u8, c: u8, pt: GamePoint) void {
    gameGfxSetWorkPagePtr(game, page);
    gameGfxDrawChar(game, c, @bitCast(pt.x), @bitCast(pt.y), color);
}

fn gameGfxDrawPoint(game: *Game, x: i16, y: i16, color: u8) void {
    const offset = @as(i32, @intCast(y)) * GAME_WIDTH + (@as(i32, @intCast(x)));
    game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)] = switch (color) {
        GFX_COL_ALPHA => game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)] | 8,
        GFX_COL_PAGE => game.gfx.fbs[0].buffer[@intCast(offset)],
        else => color,
    };
}

fn gameGfxDrawPointPage(game: *Game, page: u2, color: u8, pt: GamePoint) void {
    gameGfxSetWorkPagePtr(game, page);
    gameGfxDrawPoint(game, pt.x, pt.y, color);
}

fn calcStep(p1: GamePoint, p2: GamePoint, dy: *u16) u32 {
    dy.* = @intCast(p2.y - p1.y);
    const delta: u16 = if (dy.* <= 1) 1 else dy.*;
    // TODO: check this
    return @bitCast(@as(i32, @intCast(p2.x - p1.x)) * @as(i32, @intCast(0x4000 / delta)) << 2);
}

fn drawLineP(game: *Game, x1: i16, x2: i16, y: i16, _: u8) void {
    if (game.gfx.draw_page == 0) {
        return;
    }
    const xmax = @as(i32, @intCast(@max(x1, x2)));
    const xmin = @as(i32, @intCast(@min(x1, x2)));
    const w: i32 = xmax - xmin + 1;
    const offset = (@as(i32, @intCast(y)) * GAME_WIDTH + xmin);
    std.mem.copyForwards(u8, game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)..][0..@intCast(w)], game.gfx.fbs[0].buffer[@intCast(offset)..][0..@intCast(w)]);
}

fn drawLineN(game: *Game, x1: i16, x2: i16, y: i16, color: u8) void {
    const xmax = @as(i32, @intCast(@max(x1, x2)));
    const xmin = @as(i32, @intCast(@min(x1, x2)));
    const w: i32 = xmax - xmin + 1;
    const offset = (@as(i32, @intCast(y)) * GAME_WIDTH + xmin);
    @memset(game.gfx.fbs[game.gfx.draw_page].buffer[@intCast(offset)..@intCast(offset + w)], color);
}

fn drawLineTrans(game: *Game, x1: i16, x2: i16, y: i16, _: u8) void {
    const xmax = @max(x1, x2);
    const xmin = @min(x1, x2);
    const w: usize = @intCast(xmax - xmin + 1);
    const offset: usize = (@as(usize, @intCast(y)) * GAME_WIDTH + @as(usize, @intCast(xmin)));
    for (0..w) |i| {
        game.gfx.fbs[game.gfx.draw_page].buffer[offset + i] |= 8;
    }
}

fn gameGfxDrawBitmap(game: *Game, page: u2, data: []const u8, w: u16, h: u16, fmt: GameGfxFormat) void {
    if (fmt == .clut and GAME_WIDTH == w and GAME_HEIGHT == h) {
        @memcpy(gameGfxGetPagePtr(game, page)[0 .. w * h], data);
        return;
    }
    unreachable;
}

fn gameGfxDrawPolygon(game: *Game, color: u8, qs: *const GameQuadStrip) void {
    var i: usize = 0;
    var j: usize = qs.num_vertices - 1;

    var x2: i16 = qs.vertices[i].x;
    var x1: i16 = qs.vertices[j].x;
    var hliney: i16 = @min(qs.vertices[i].y, qs.vertices[j].y);

    i += 1;
    j -= 1;

    const draw_func = switch (color) {
        GFX_COL_PAGE => &drawLineP,
        GFX_COL_ALPHA => &drawLineTrans,
        else => &drawLineN,
    };

    var cpt1: u32 = @as(u32, @intCast(@as(u16, @bitCast(x1)))) << 16;
    var cpt2: u32 = @as(u32, @intCast(@as(u16, @bitCast(x2)))) << 16;

    var num_vertices = qs.num_vertices;
    while (true) {
        num_vertices -= 2;
        if (num_vertices == 0) {
            return;
        }
        var h: u16 = undefined;
        const step1 = calcStep(qs.vertices[j + 1], qs.vertices[j], &h);
        const step2 = calcStep(qs.vertices[i - 1], qs.vertices[i], &h);

        i += 1;
        j -= 1;

        cpt1 = (cpt1 & 0xFFFF0000) | 0x7FFF;
        cpt2 = (cpt2 & 0xFFFF0000) | 0x8000;

        if (h == 0) {
            cpt1 +%= step1;
            cpt2 +%= step2;
        } else {
            for (0..h) |_| {
                if (hliney >= 0) {
                    x1 = @bitCast(@as(u16, @truncate(cpt1 >> 16)));
                    x2 = @bitCast(@as(u16, @truncate(cpt2 >> 16)));
                    if (x1 < GAME_WIDTH and x2 >= 0) {
                        if (x1 < 0) x1 = 0;
                        if (x2 >= GAME_WIDTH) x2 = GAME_WIDTH - 1;
                        draw_func(game, x1, x2, hliney, color);
                    }
                }
                cpt1 +%= step1;
                cpt2 +%= step2;
                hliney += 1;
                if (hliney >= GAME_HEIGHT) return;
            }
        }
    }
}

fn gameGfxDrawQuadStrip(game: *Game, buffer: u2, color: u8, qs: *const GameQuadStrip) void {
    gameGfxSetWorkPagePtr(game, buffer);
    gameGfxDrawPolygon(game, color, qs);
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

fn readBeU16(buf: []const u8) u16 {
    return std.mem.readInt(u16, buf[0..2], .big);
}

fn readLeU16(buf: []const u8) u32 {
    return std.mem.readInt(u16, buf[0..2], .little);
}

fn readLeU32(buf: []const u8) u32 {
    return std.mem.readInt(u32, buf[0..4], .little);
}

fn gameAudioInit(game: *Game, callback: GameAudioCallback) void {
    game.audio.callback = callback;
}

fn gameAudioSfxStart(game: *Game) void {
    std.log.debug("SfxPlayer::start()", .{});
    game.audio.sfx_player.sfx_mod.cur_pos = 0;
}

fn gameAudioSfxSetEventsDelay(game: *Game, delay: u16) void {
    std.log.debug("SfxPlayer::setEventsDelay({})", .{delay});
    game.audio.sfx_player.delay = delay;
}

fn gameAudioStopSound(game: *Game, channel: u2) void {
    std.log.debug("Mixer::stopChannel({})", .{channel});
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

    const len: u32 = @as(u32, @intCast(readBeU16(data[0..]))) * 2;
    chan.loop_len = @as(u32, @intCast(readBeU16(data[2..]))) * 2;
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
            ins.volume = readBeU16(p);
            const me = &game.res.mem_list[res_num];
            if (me.status == .loaded and me.type == .sound) {
                ins.data = me.buf_ptr;
                std.log.debug("Loaded instrument 0x{X} n={} volume={}", .{ res_num, i, ins.volume });
            } else {
                std.log.err("Error loading instrument 0x{X:0>2}", .{res_num});
            }
        }
        p = p[2..]; // skip volume
    }
}

fn gameAudioSfxLoadModule(game: *Game, res_num: u16, delay: u16, pos: u8) void {
    std.log.debug("SfxPlayer::loadSfxModule(0x{X:0>2}, {}, {})", .{ res_num, delay, pos });
    var player = &game.audio.sfx_player;
    var me = &game.res.mem_list[res_num];
    if (me.status == .loaded and me.type == .music) {
        player.sfx_mod = std.mem.zeroes(@TypeOf(player.sfx_mod));
        player.sfx_mod.cur_order = pos;
        player.sfx_mod.num_order = me.buf_ptr[0x3F];
        std.log.debug("SfxPlayer::loadSfxModule() curOrder = 0x{X} numOrder = 0x{X}", .{ player.sfx_mod.cur_order, player.sfx_mod.num_order });
        player.sfx_mod.order_table = me.buf_ptr[0x40..];
        if (delay == 0) {
            player.delay = readBeU16(me.buf_ptr);
        } else {
            player.delay = delay;
        }
        player.sfx_mod.data = me.buf_ptr[0xC0..];
        std.log.debug("SfxPlayer::loadSfxModule() eventDelay = {} ms", .{player.delay});
        gameAudioSfxPrepareInstruments(game, me.buf_ptr[2..]);
    } else {
        std.log.warn("SfxPlayer::loadSfxModule() ec=0xF8", .{});
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
    std.log.debug("SfxPlayer::stop()", .{});
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
    pat.note_1 = readBeU16(data);
    pat.note_2 = readBeU16(data[2..]);
    if (pat.note_1 != 0xFFFD) {
        const sample: u16 = (pat.note_2 & 0xF000) >> 12;
        if (sample != 0) {
            const ptr = player.sfx_mod.samples[sample - 1].data;
            if (ptr.len > 0) {
                std.log.debug("SfxPlayer::handlePattern() preparing sample {}", .{sample});
                pat.sample_volume = player.sfx_mod.samples[sample - 1].volume;
                pat.sample_start = 8;
                pat.sample_buffer = ptr;
                pat.sample_len = readBeU16(ptr) *% 2;
                const loop_len: u16 = readBeU16(ptr[2..]) *% 2;
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
        std.log.debug("SfxPlayer::handlePattern() _syncVar = 0x{X}", .{pat.note_2});
        game.vm.vars[GAME_VAR_MUSIC_SYNC] = @bitCast(pat.note_2);
    } else if (pat.note_1 != 0) {
        pat.period_arpeggio = pat.note_1;
        if (pat.period_arpeggio == 0xFFFE) {
            player.channels[channel] = std.mem.zeroes(@TypeOf(player.channels[channel]));
        } else if (pat.sample_buffer) |buf| {
            assert(pat.note_1 >= 0x37 and pat.note_1 < 0x1000);
            // convert Amiga period value to hz
            const freq: i32 = @divTrunc(GAME_PAULA_FREQ, @as(i32, @intCast(pat.note_1)) * 2);
            std.log.debug("SfxPlayer::handlePattern() adding sample freq = 0x{X}", .{freq});
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
    std.log.debug("SfxPlayer::handleEvents() order = 0x{X} curPos = 0x{X}", .{ order, player.sfx_mod.cur_pos });
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
    std.log.debug("snd_playSound(0x{X}, {}, {}, {})", .{ resNum, freq, vol, chan });
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

fn fetchByte(pc: *GamePc) u8 {
    const res = pc.data[pc.pc];
    pc.pc += 1;
    return res;
}

fn fetchWord(pc: *GamePc) u16 {
    const res = std.mem.readInt(u16, pc.data[pc.pc..][0..2], .big);
    pc.pc += 2;
    return res;
}

fn opMovConst(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const n: i16 = @bitCast(fetchWord(&game.vm.ptr));
    std.log.debug("Script::op_movConst(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = n;
}

fn opMov(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const j = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_mov(0x{X:0>2}, 0x{X:0>2})", .{ i, j });
    game.vm.vars[i] = game.vm.vars[j];
}

fn opAdd(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const j = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_add(0x{X:0>2}, 0x{X:0>2})", .{ i, j });
    game.vm.vars[i] +%= game.vm.vars[j];
}

fn opAddConst(game: *Game) void {
    if (game.res.current_part == .luxe and game.vm.ptr.pc == 0x6D48) {
        std.log.warn("Script::op_addConst() workaround for infinite looping gun sound", .{});
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
    const i = fetchByte(&game.vm.ptr);
    const n: i16 = @bitCast(fetchWord(&game.vm.ptr));
    std.log.debug("Script::op_addConst(0x{X}, {})", .{ i, n });
    game.vm.vars[i] += n;
}

fn opCall(game: *Game) void {
    const off = fetchWord(&game.vm.ptr);
    std.log.debug("Script::op_call(0x{X})", .{off});
    if (game.vm.stack_ptr == 0x40) {
        std.log.err("Script::op_call() ec=0x8F stack overflow", .{});
    }
    game.vm.stack_calls[game.vm.stack_ptr] = game.vm.ptr.pc;
    game.vm.stack_ptr += 1;
    game.vm.ptr.pc = off;
}

fn opRet(game: *Game) void {
    std.log.debug("Script::op_ret()", .{});
    if (game.vm.stack_ptr == 0) {
        std.log.err("Script::op_ret() ec=0x8F stack underflow", .{});
    }
    game.vm.stack_ptr -= 1;
    game.vm.ptr.pc = game.vm.stack_calls[game.vm.stack_ptr];
}

fn opYieldTask(game: *Game) void {
    std.log.debug("Script::op_yieldTask()", .{});
    game.vm.paused = true;
}

fn opJmp(game: *Game) void {
    const off = fetchWord(&game.vm.ptr);
    std.log.debug("Script::op_jmp(0x{X})", .{off});
    game.vm.ptr.pc = off;
}

fn opInstallTask(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const n = fetchWord(&game.vm.ptr);
    std.log.debug("Script::op_installTask(0x{X}, 0x{X})", .{ i, n });
    game.vm.tasks[i].next_pc = n;
}

fn opJmpIfVar(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_jmpIfVar(0x{X})", .{i});
    game.vm.vars[i] -= 1;
    if (game.vm.vars[i] != 0) {
        opJmp(game);
    } else {
        _ = fetchWord(&game.vm.ptr);
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
        std.log.debug("Setting palette {} for part {} screen {}", .{ p, part, screen });
        gameVideoChangePal(game, p);
    }
}

fn opCondJmp(game: *Game) void {
    const op = fetchByte(&game.vm.ptr);
    const variable = fetchByte(&game.vm.ptr);
    const b = game.vm.vars[variable];
    var a: i16 = undefined;
    if ((op & 0x80) != 0) {
        a = game.vm.vars[fetchByte(&game.vm.ptr)];
    } else if ((op & 0x40) != 0) {
        a = @bitCast(fetchWord(&game.vm.ptr));
    } else {
        a = @intCast(fetchByte(&game.vm.ptr));
    }
    std.log.debug("Script::op_condJmp({}, 0x{X:0>2}, 0x{X:0>2}) var=0x{X:0>2}", .{ op, @as(u16, @bitCast(b)), @as(u16, @bitCast(a)), variable });
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
                        std.log.warn("Script::op_condJmp() bypassing protection", .{});
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
        else => std.log.warn("Script::op_condJmp() invalid condition {}", .{op & 7}),
    }
    if (expr) {
        opJmp(game);
        if (variable == GAME_VAR_SCREEN_NUM and game.vm.screen_num != game.vm.vars[GAME_VAR_SCREEN_NUM]) {
            fixupPaletteChangeScreen(game, game.res.current_part, game.vm.vars[GAME_VAR_SCREEN_NUM]);
            game.vm.screen_num = game.vm.vars[GAME_VAR_SCREEN_NUM];
        }
    } else {
        _ = fetchWord(&game.vm.ptr);
    }
}

fn opSetPalette(game: *Game) void {
    const i = fetchWord(&game.vm.ptr);
    std.log.debug("Script::op_changePalette({})", .{i});
    const num = i >> 8;
    if (game.gfx.fix_up_palette) {
        if (game.res.current_part == .intro) {
            if (num == 10 or num == 16) {
                return;
            }
        }
        game.video.next_pal = @intCast(num);
    } else {
        game.video.next_pal = @intCast(num);
    }
}

fn opChangeTasksState(game: *Game) void {
    const start = fetchByte(&game.vm.ptr);
    const end = fetchByte(&game.vm.ptr);
    if (end < start) {
        std.log.warn("Script::op_changeTasksState() ec=0x880 (end < start)", .{});
        return;
    }
    const state = fetchByte(&game.vm.ptr);

    std.log.debug("Script::op_changeTasksState({}, {}, {})", .{ start, end, state });

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
    const i = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_selectPage({})", .{i});
    gameVideoSetWorkPagePtr(game, i);
}

fn opFillPage(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const color = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_fillPage({}, {})", .{ i, color });
    gameVideoFillPage(game, i, color);
}

fn opCopyPage(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const j = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_copyPage({}, {})", .{ i, j });
    gameVideoCopyPage(game, i, j, game.vm.vars[GAME_VAR_SCROLL_Y]);
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
    const page = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_updateDisplay({})", .{page});
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

    gameVideoUpdateDisplay(game, page);
}

fn opRemoveTask(game: *Game) void {
    std.log.debug("Script::op_removeTask()", .{});
    game.vm.ptr.pc = 0xFFFF;
    game.vm.paused = true;
}

fn opDrawString(game: *Game) void {
    const strId = fetchWord(&game.vm.ptr);
    const x: u16 = fetchByte(&game.vm.ptr);
    const y: u16 = fetchByte(&game.vm.ptr);
    const col: u16 = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_drawString(0x{X}, {}, {}, {})", .{ strId, x, y, col });
    gameVideoDrawString(game, @truncate(col), x, y, strId);
}

fn opSub(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const j = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_sub(0x{X}, 0x{X})", .{ i, j });
    game.vm.vars[i] -= game.vm.vars[j];
}

fn opAnd(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const n: u16 = fetchWord(&game.vm.ptr);
    std.log.debug("Script::op_and(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @bitCast(game.vm.vars[i])) & n);
}

fn opOr(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const n: i16 = @bitCast(fetchWord(&game.vm.ptr));
    std.log.debug("Script::op_or(0x{X}, {})", .{ i, n });
    game.vm.vars[i] = game.vm.vars[i] | n;
}

fn opShl(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const n: u4 = @intCast(fetchWord(&game.vm.ptr));
    std.log.debug("Script::op_shl(0x{X:0>2}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @intCast(game.vm.vars[i])) << n);
}

fn opShr(game: *Game) void {
    const i = fetchByte(&game.vm.ptr);
    const n: u4 = @intCast(fetchWord(&game.vm.ptr));
    std.log.debug("Script::op_shr(0x{X:0>2}, {})", .{ i, n });
    game.vm.vars[i] = @bitCast(@as(u16, @intCast(game.vm.vars[i])) >> n);
}

fn opPlaySound(game: *Game) void {
    const res_num = fetchWord(&game.vm.ptr);
    const freq = fetchByte(&game.vm.ptr);
    const vol: u8 = @truncate(fetchByte(&game.vm.ptr));
    const channel = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_playSound(0x{X}, {}, {}, {})", .{ res_num, freq, vol, channel });
    sndPlaySound(game, res_num, freq, vol, @intCast(channel));
}

fn opUpdateResources(game: *Game) void {
    const num = fetchWord(&game.vm.ptr);
    std.log.debug("Script::op_updateResources({})", .{num});
    if (num == 0) {
        gameAudioStopAll(game);
        gameResInvalidate(game);
    } else {
        gameResUpdate(game, num);
    }
}

fn sndPlayMusic(game: *Game, resNum: u16, delay: u16, pos: u8) void {
    std.log.debug("snd_playMusic(0x{X}, {}, {})", .{ resNum, delay, pos });
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
    const res_num = fetchWord(&game.vm.ptr);
    const delay = fetchWord(&game.vm.ptr);
    const pos = fetchByte(&game.vm.ptr);
    std.log.debug("Script::op_playMusic(0x{X}, {}, {})", .{ res_num, delay, pos });
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
