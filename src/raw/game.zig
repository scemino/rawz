const std = @import("std");
const saudio = @import("sokol").audio;
const glue = @import("common").glue;
const DemoJoy = @import("DemoJoy.zig");
const Strings = @import("Strings.zig");
const GameFrac = @import("GameFrac.zig");
pub const GameRes = @import("Res.zig");
const GamePc = @import("GamePc.zig");
const GameData = @import("GameData.zig");
const Gfx = @import("Gfx.zig");
const Video = @import("Video.zig");
const Vm = @import("Vm.zig");
const audio = @import("audio.zig");
pub const mementries = @import("mementries.zig");
pub const util = @import("util.zig");
pub const byteKillerUnpack = @import("unpack.zig").byteKillerUnpack;
pub const GameDataType = mementries.GameDataType;
pub const GameLang = Strings.GameLang;
const assert = std.debug.assert;

const GAME_QUAD_STRIP_MAX_VERTICES = 70;

const restart_pos = [36 * 2]i16{ 16008, 0, 16001, 0, 16002, 10, 16002, 12, 16002, 14, 16003, 20, 16003, 24, 16003, 26, 16004, 30, 16004, 31, 16004, 32, 16004, 33, 16004, 34, 16004, 35, 16004, 36, 16004, 37, 16004, 38, 16004, 39, 16004, 40, 16004, 41, 16004, 42, 16004, 43, 16004, 44, 16004, 45, 16004, 46, 16004, 47, 16004, 48, 16004, 49, 16006, 64, 16006, 65, 16006, 66, 16006, 67, 16006, 68, 16005, 50, 16006, 60, 16007, 0 };

const GAME_TITLE_EU = "Another World";
const GAME_TITLE_US = "Out Of This World";

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

const GameInputDir = packed struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
};

const GameAudioDesc = struct {
    callback: audio.GameAudioCallback,
    sample_rate: i32,
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

valid: bool = false,
enable_protection: bool = false,
// TODO: debug:game_debug_t,
res: GameRes = undefined,
strings_table: Strings = undefined,
part_num: u16 = 0,
elapsed: u32 = 0,
sleep: u32 = 0,

gfx: Gfx = .{},
audio: audio.Audio = undefined,
video: Video = undefined,
vm: Vm = undefined,
input: Input = undefined,

title: [:0]const u8 = undefined, // title of the game
const Self = @This();

const video_log = std.log.scoped(.video);
const vm_log = std.log.scoped(.vm);
const snd_log = std.log.scoped(.sound);

pub fn displayInfo(game: ?*Self) glue.DisplayInfo {
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

pub fn init(game: *Self, desc: GameDesc) !void {
    //assert(game and desc);
    //if (desc.debug.callback.func) { GAME_ASSERT(desc.debug.stopped); }
    game.valid = true;
    game.enable_protection = desc.enable_protection;
    // game.debug = desc.debug;
    game.part_num = desc.part_num;
    game.strings_table = Strings.init(desc.lang);
    game.res = try GameRes.init(.{
        .lang = desc.lang,
        .data = desc.data,
        .user_data = &game.video,
        .copy_bitmap = copyBitmap,
        .set_palette = setVideoPalette,
    });
    game.audio.init(desc.audio.callback);

    if (game.res.data.demo3_joy) |demo| {
        game.input.demo_joy.read(demo);
    }

    game.video = Video.init(&game.gfx, game.res.data_type, desc.use_ega);
    game.gfx.setWorkPagePtr(2);
    game.vm = Vm.init(.{
        .data_type = game.res.data_type,
        .user_data = game,
        .enable_protection = game.enable_protection,
        .sndPlaySound = sndPlaySound,
        .sndPlayMusic = sndPlayMusic,
        .updateResources = updateResources,
        .setPalette = setPalette,
        .changePal = changePal,
        .setVideoWorkPagePtr = setVideoWorkPagePtr,
        .fillPage = fillPage,
        .copyPage = copyPage,
        .drawString = drawString,
        .getCurrentPart = getCurrentPart,
        .updateDisplay = updateDisplay,
    });

    if (game.enable_protection and (game.res.data_type != .dos or game.res.has_password_screen)) {
        game.part_num = @intFromEnum(GameRes.GamePart.copy_protection);
    }
    game.audio.sfx_player.callback = &sfxPlayerCallback;
    game.audio.sfx_player.callback_user_data = game;

    const num = game.part_num;
    const part: GameRes.GamePart = if (num < 36) @enumFromInt(restart_pos[num * 2]) else @enumFromInt(num);
    const part_pos = if (num < 36) restart_pos[num * 2 + 1] else -1;
    game.restartAt(part, part_pos);
    game.title = if (game.res.data_type == .dos and game.res.lang == .us) GAME_TITLE_US else GAME_TITLE_EU;
}

pub fn exec(game: *Self, ms: u32) !void {
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
    const num_frames: usize = @intCast(saudio.saudio_expect());
    if (num_frames > 0) {
        const num_samples: usize = num_frames * @as(usize, @intCast(saudio.saudio_channels()));
        game.audio.update(num_samples);
    }

    game.sleep += 20; // wait 20 ms (50 Hz)
}

pub fn restartAt(game: *Self, part: GameRes.GamePart, pos: i16) void {
    game.audio.stopAll();
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
    game.res.setupPart(@intFromEnum(part));
    for (0..Vm.GAME_NUM_TASKS) |i| {
        game.vm.tasks[i].pc = Vm.GAME_INACTIVE_TASK;
        game.vm.tasks[i].next_pc = Vm.GAME_INACTIVE_TASK;
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

pub fn keyDown(game: *Self, input: GameInput) void {
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

pub fn keyUp(game: *Self, input: GameInput) void {
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

pub fn charPressed(game: *Self, c: u8) void {
    // GAME_ASSERT(game && game->valid);
    game.input.last_char = c;
}

pub fn debugSndPlaySound(game: *Self, buf: []const u8, frequency: u8, volume: u8) void {
    if (volume == 0) {
        game.audio.stopSound(4);
        return;
    }
    gameAudioPlaySoundRaw(game, 4, buf, frequency, volume);
}

fn copyBitmap(user_data: ?*anyopaque, src: []const u8) void {
    const video: *Video = @alignCast(@ptrCast(user_data));
    video.copyBitmapPtr(src);
}

fn setVideoPalette(user_data: ?*anyopaque, pal: u8) void {
    const video: *Video = @alignCast(@ptrCast(user_data));
    video.current_pal = pal;
}

fn gameVmSetupTasks(game: *Self) void {
    if (game.res.next_part) |part| {
        restartAt(game, part, -1);
        game.res.next_part = null;
    }
    game.vm.setupTasks();
}

fn gameVmExecuteTask(game: *Self) !void {
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
        const offset_hi = game.vm.ptr.fetchByte();
        const off = ((@as(u16, offset_hi) << 8) | game.vm.ptr.fetchByte()) << 1;
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
        Vm.op_table[opcode](&game.vm);
    }
}

fn gameVmRun(game: *Self) !bool {
    var i = game.vm.current_task;
    if (!game.input.quit and game.vm.tasks[i].state == 0) {
        const n = game.vm.tasks[i].pc;
        if (n != Vm.GAME_INACTIVE_TASK) {
            // execute 1 step of 1 task
            game.vm.ptr = .{ .data = game.res.seg_code, .pc = n };
            game.vm.paused = false;
            vm_log.debug("Script::runTasks() i=0x{X} n=0x{X}", .{ i, n });
            try gameVmExecuteTask(game);
            game.vm.tasks[i].pc = game.vm.ptr.pc;
            vm_log.debug("Script::runTasks() i=0x{X} pos=0x{X}", .{ i, game.vm.tasks[i].pc });
            if (!game.vm.paused and game.vm.tasks[i].pc != Vm.GAME_INACTIVE_TASK) {
                return false;
            }
        }
    }

    var result = false;

    while (true) {
        // go to next active thread
        i = (i + 1) % Vm.GAME_NUM_TASKS;
        if (i == 0) {
            result = true;
            gameVmSetupTasks(game);
            gameVmUpdateInput(game);
        }

        if (game.vm.tasks[i].pc != Vm.GAME_INACTIVE_TASK) {
            game.vm.stack_ptr = 0;
            game.vm.current_task = i;
            break;
        }
    }

    return result;
}

fn gameVmUpdateInput(game: *Self) void {
    if (game.res.current_part == .password) {
        const c = game.input.last_char;
        if (c == 8 or c == 0 or (c >= 'a' and c <= 'z')) {
            game.vm.vars[Vm.GAME_VAR_LAST_KEYCHAR] = c & ~@as(u8, @intCast(0x20));
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
        game.vm.vars[Vm.GAME_VAR_HERO_POS_UP_DOWN] = ud;
    }
    game.vm.vars[Vm.GAME_VAR_HERO_POS_JUMP_DOWN] = jd;
    game.vm.vars[Vm.GAME_VAR_HERO_POS_LEFT_RIGHT] = lr;
    game.vm.vars[Vm.GAME_VAR_HERO_POS_MASK] = m;
    var action: i16 = 0;
    if (game.input.action) {
        action = 1;
        m |= 0x80;
    }
    game.vm.vars[Vm.GAME_VAR_HERO_ACTION] = action;
    game.vm.vars[Vm.GAME_VAR_HERO_ACTION_POS_MASK] = m;
    if (game.res.current_part == .water) {
        const mask = game.input.demo_joy.update();
        if (mask != 0) {
            game.vm.vars[Vm.GAME_VAR_HERO_ACTION_POS_MASK] = mask;
            game.vm.vars[Vm.GAME_VAR_HERO_POS_MASK] = mask & 15;
            game.vm.vars[Vm.GAME_VAR_HERO_POS_LEFT_RIGHT] = 0;
            // TODO: change bit mask
            if ((mask & 1) != 0) {
                game.vm.vars[Vm.GAME_VAR_HERO_POS_LEFT_RIGHT] = 1;
            }
            if ((mask & 2) != 0) {
                game.vm.vars[Vm.GAME_VAR_HERO_POS_LEFT_RIGHT] = -1;
            }
            game.vm.vars[Vm.GAME_VAR_HERO_POS_JUMP_DOWN] = 0;
            if ((mask & 4) != 0) {
                game.vm.vars[Vm.GAME_VAR_HERO_POS_JUMP_DOWN] = 1;
            }
            if ((mask & 8) != 0) {
                game.vm.vars[Vm.GAME_VAR_HERO_POS_JUMP_DOWN] = -1;
            }
            game.vm.vars[Vm.GAME_VAR_HERO_ACTION] = (mask >> 7);
        }
    }
}

fn gameAudioSfxLoadModule(game: *Self, res_num: u16, delay: u16, pos: u8) void {
    snd_log.debug("SfxPlayer::loadSfxModule(0x{X:0>2}, {}, {})", .{ res_num, delay, pos });
    const me = &game.res.mem_list[res_num];
    if (me.status == .loaded and me.type == .music) {
        game.audio.sfx_player.sfxLoadModule(me.buf_ptr, delay, pos, game, resSoundRead);
    } else {
        snd_log.warn("SfxPlayer::loadSfxModule() ec=0xF8", .{});
    }
}

fn gameAudioPlaySoundRaw(game: *Self, channel: u3, data: []const u8, frequency: i32, volume: u8) void {
    const vol = if (volume > 63) 63 else volume;
    const freq = if (frequency > 39) 39 else frequency;
    game.audio.channels[channel].initRaw(data, @intCast(freq), vol, audio.GAME_MIX_FREQ);
}

fn sndPlaySound(user_data: ?*anyopaque, resNum: u16, frequency: u8, volume: u8, chan: u3) void {
    snd_log.debug("snd_playSound(0x{X}, {}, {}, {})", .{ resNum, frequency, volume, chan });
    var game: *Self = @alignCast(@ptrCast(user_data));
    if (volume == 0) {
        game.audio.stopSound(chan);
        return;
    }
    const me = &game.res.mem_list[resNum];
    if (me.status == .loaded) {
        gameAudioPlaySoundRaw(game, chan, me.buf_ptr, frequency, volume);
    }
}

fn sndPlayMusic(user_data: ?*anyopaque, resNum: u16, delay: u16, pos: u8) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    snd_log.debug("snd_playMusic(0x{X}, {}, {})", .{ resNum, delay, pos });
    // DT_AMIGA, DT_ATARI, DT_DOS
    if (resNum != 0) {
        gameAudioSfxLoadModule(game, resNum, delay, pos);
        game.audio.sfxStart();
        game.audio.sfx_player.playSfxMusic();
    } else if (delay != 0) {
        game.audio.sfx_player.sfxSetEventsDelay(delay);
    } else {
        game.audio.sfx_player.stopSfxMusic();
    }
}

fn inpHandleSpecialKeys(game: *Self) void {
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

fn updateResources(user_data: ?*anyopaque, num: u16) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    if (num == 0) {
        game.audio.stopAll();
        game.res.invalidate();
    } else {
        game.res.update(num);
    }
}

fn updateDisplay(user_data: ?*anyopaque, page: u8) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    vm_log.debug("Script::op_updateDisplay({})", .{page});
    inpHandleSpecialKeys(game);

    if (game.enable_protection) {
        // entered protection symbols match the expected values
        if (game.res.current_part == .copy_protection and game.vm.vars[0x67] == 1) {
            game.vm.vars[0xDC] = 33;
        }
    }

    const frame_hz: i32 = 50;
    if (game.vm.vars[Vm.GAME_VAR_PAUSE_SLICES] != 0) {
        const delay: i32 = @as(i32, @intCast(game.elapsed)) - @as(i32, @intCast(game.vm.time_stamp));
        const pause = @divTrunc(@as(i32, @intCast(game.vm.vars[Vm.GAME_VAR_PAUSE_SLICES])) * 1000, frame_hz) - delay;
        if (pause > 0) {
            game.sleep += @as(u32, @intCast(pause));
        }
    }
    game.vm.time_stamp = game.elapsed;
    game.vm.vars[0xF7] = 0;

    game.video.updateDisplay(game.res.seg_video_pal, page);
}

fn setPalette(user_data: ?*anyopaque, pal: u8) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    if (!game.gfx.fix_up_palette or game.res.current_part != .intro or (pal != 10 and pal != 16)) {
        game.video.next_pal = @intCast(pal);
    }
}

fn setVideoWorkPagePtr(user_data: ?*anyopaque, page: u8) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    game.video.setWorkPagePtr(page);
}

fn fillPage(user_data: ?*anyopaque, page: u8, color: u8) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    game.video.fillPage(page, color);
}

fn copyPage(user_data: ?*anyopaque, src: u8, dst: u8, vscroll: i16) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    game.video.copyPage(src, dst, vscroll);
}

fn drawString(user_data: ?*anyopaque, color: u8, x: u16, y: u16, str_id: u16) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    game.video.drawString(color, x, y, game.strings_table.find(str_id));
}

fn getCurrentPart(user_data: ?*anyopaque) GameRes.GamePart {
    const game: *Self = @alignCast(@ptrCast(user_data));
    return game.res.current_part;
}

fn changePal(user_data: ?*anyopaque, pal: u8) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    game.video.changePal(game.res.seg_video_pal, pal);
}

fn sfxPlayerCallback(user_data: ?*anyopaque, pat_note2: u16) void {
    var game: *Self = @alignCast(@ptrCast(user_data));
    game.vm.vars[Vm.GAME_VAR_MUSIC_SYNC] = @bitCast(pat_note2);
}

fn resSoundRead(user_data: ?*anyopaque, id: u16) ?[]const u8 {
    var game: *Self = @alignCast(@ptrCast(user_data));
    const me = &game.res.mem_list[id];
    if (me.status == .loaded and me.type == .sound) {
        return me.buf_ptr;
    }
    return null;
}
