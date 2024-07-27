const std = @import("std");
const GamePc = @import("GamePc.zig");
const Res = @import("Res.zig");
const GamePart = Res.GamePart;
const DefaultPrng = std.rand.DefaultPrng;

pub const GAME_NUM_TASKS = 64;
pub const GAME_INACTIVE_TASK = 0xFFFF;
pub const GAME_VAR_RANDOM_SEED = 0x3C;
const GAME_VAR_SCREEN_NUM = 0x67;
pub const GAME_VAR_LAST_KEYCHAR = 0xDA;
pub const GAME_VAR_HERO_POS_UP_DOWN = 0xE5;
pub const GAME_VAR_MUSIC_SYNC = 0xF4;
const GAME_VAR_SCROLL_Y = 0xF9;
pub const GAME_VAR_HERO_ACTION = 0xFA;
pub const GAME_VAR_HERO_POS_JUMP_DOWN = 0xFB;
pub const GAME_VAR_HERO_POS_LEFT_RIGHT = 0xFC;
pub const GAME_VAR_HERO_POS_MASK = 0xFD;
pub const GAME_VAR_HERO_ACTION_POS_MASK = 0xFE;
pub const GAME_VAR_PAUSE_SLICES = 0xFF;

const Task = struct {
    pc: u16 = 0,
    next_pc: u16 = 0,
    state: u8 = 0,
    next_state: u8 = 0,
};

const Context = struct {
    data_type: Res.GameDataType,
    enable_protection: bool,
    user_data: ?*anyopaque,
    sndPlaySound: *const fn (user_data: ?*anyopaque, resNum: u16, frequency: u8, volume: u8, chan: u3) void,
    sndPlayMusic: *const fn (user_data: ?*anyopaque, resNum: u16, delay: u16, pos: u8) void,
    updateResources: *const fn (user_data: ?*anyopaque, num: u16) void,
    setPalette: *const fn (user_data: ?*anyopaque, pal: u8) void,
    changePal: *const fn (user_data: ?*anyopaque, pal: u8) void,
    setVideoWorkPagePtr: *const fn (user_data: ?*anyopaque, page: u8) void,
    fillPage: *const fn (user_data: ?*anyopaque, page: u8, color: u8) void,
    copyPage: *const fn (user_data: ?*anyopaque, src: u8, dst: u8, vscroll: i16) void,
    drawString: *const fn (user_data: ?*anyopaque, color: u8, xx: u16, yy: u16, str_id: u16) void,
    getCurrentPart: *const fn (user_data: ?*anyopaque) GamePart,
    updateDisplay: *const fn (user_data: ?*anyopaque, page: u8) void,
};

vars: [256]i16 = [1]i16{0} ** 256,
stack_calls: [64]u16 = [1]u16{0} ** 64,

tasks: [GAME_NUM_TASKS]Task = [1]Task{.{}} ** GAME_NUM_TASKS,
ptr: GamePc = .{},
stack_ptr: u8 = 0,
paused: bool = false,
screen_num: i32 = 0,
start_time: u32 = 0,
time_stamp: u32 = 0,
current_task: u8 = 0,
context: Context,
const Self = @This();

const vm_log = std.log.scoped(.vm);
const snd_log = std.log.scoped(.sound);

pub fn init(context: Context) Self {
    var self = Self{ .context = context };
    var rnd = DefaultPrng.init(0);
    self.vars[GAME_VAR_RANDOM_SEED] = rnd.random().int(i16);
    if (!context.enable_protection) {
        self.vars[0xBC] = 0x10;
        self.vars[0xC6] = 0x80;
        self.vars[0xF2] = if (context.data_type == .amiga or context.data_type == .atari) 6000 else 4000;
        self.vars[0xDC] = 33;
    }
    if (context.data_type == .dos) {
        self.vars[0xE4] = 20;
    }
    return self;
}

pub fn setupTasks(self: *Self) void {
    for (0..GAME_NUM_TASKS) |i| {
        self.tasks[i].state = self.tasks[i].next_state;
        const n = self.tasks[i].next_pc;
        if (n != GAME_INACTIVE_TASK) {
            self.tasks[i].pc = if (n == GAME_INACTIVE_TASK - 1) GAME_INACTIVE_TASK else n;
            self.tasks[i].next_pc = GAME_INACTIVE_TASK;
        }
    }
}

fn opMovConst(self: *Self) void {
    const i = self.ptr.fetchByte();
    const n: i16 = @bitCast(self.ptr.fetchWord());
    vm_log.debug("Script::op_movConst(0x{X}, {})", .{ i, n });
    self.vars[i] = n;
}

fn opMov(self: *Self) void {
    const i = self.ptr.fetchByte();
    const j = self.ptr.fetchByte();
    vm_log.debug("Script::op_mov(0x{X:0>2}, 0x{X:0>2})", .{ i, j });
    self.vars[i] = self.vars[j];
}

fn opAdd(self: *Self) void {
    const i = self.ptr.fetchByte();
    const j = self.ptr.fetchByte();
    vm_log.debug("Script::op_add(0x{X:0>2}, 0x{X:0>2})", .{ i, j });
    self.vars[i] +%= self.vars[j];
}

fn opAddConst(self: *Self) void {
    if (self.context.getCurrentPart(self.context.user_data) == .luxe and self.ptr.pc == 0x6D48) {
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
        self.context.sndPlaySound(self.context.user_data, 0x5B, 1, 63, 1);
    }
    const i = self.ptr.fetchByte();
    const n: i16 = @bitCast(self.ptr.fetchWord());
    vm_log.debug("Script::op_addConst(0x{X}, {})", .{ i, n });
    self.vars[i] = self.vars[i] +% n;
}

fn opCall(self: *Self) void {
    const off = self.ptr.fetchWord();
    vm_log.debug("Script::op_call(0x{X})", .{off});
    if (self.stack_ptr == 0x40) {
        vm_log.err("Script::op_call() ec=0x8F stack overflow", .{});
    }
    self.stack_calls[self.stack_ptr] = self.ptr.pc;
    self.stack_ptr += 1;
    self.ptr.pc = off;
}

fn opRet(self: *Self) void {
    vm_log.debug("Script::op_ret()", .{});
    if (self.stack_ptr == 0) {
        vm_log.err("Script::op_ret() ec=0x8F stack underflow", .{});
    }
    self.stack_ptr -= 1;
    self.ptr.pc = self.stack_calls[self.stack_ptr];
}

fn opYieldTask(self: *Self) void {
    vm_log.debug("Script::op_yieldTask()", .{});
    self.paused = true;
}

fn opJmp(self: *Self) void {
    const off = self.ptr.fetchWord();
    vm_log.debug("Script::op_jmp(0x{X})", .{off});
    self.ptr.pc = off;
}

fn opInstallTask(self: *Self) void {
    const i = self.ptr.fetchByte();
    const n = self.ptr.fetchWord();
    vm_log.debug("Script::op_installTask(0x{X}, 0x{X})", .{ i, n });
    self.tasks[i].next_pc = n;
}

fn opJmpIfVar(self: *Self) void {
    const i = self.ptr.fetchByte();
    vm_log.debug("Script::op_jmpIfVar(0x{X})", .{i});
    self.vars[i] -= 1;
    if (self.vars[i] != 0) {
        opJmp(self);
    } else {
        _ = self.ptr.fetchWord();
    }
}

fn fixupPaletteChangeScreen(self: *Self, part: GamePart, screen: i32) void {
    const pal: ?u8 = switch (part) {
        .cite => if (screen == 0x47) 8 else null, // bitmap resource #68
        .luxe => if (screen == 0x4A) 1 else null, // bitmap resources #144, #145
        else => null,
    };
    if (pal) |p| {
        vm_log.debug("Setting palette {} for part {} screen {}", .{ p, part, screen });
        self.context.changePal(self.context.user_data, p);
    }
}

fn opCondJmp(self: *Self) void {
    const op = self.ptr.fetchByte();
    const variable = self.ptr.fetchByte();
    const b = self.vars[variable];
    var a: i16 = undefined;
    if ((op & 0x80) != 0) {
        a = self.vars[self.ptr.fetchByte()];
    } else if ((op & 0x40) != 0) {
        a = @bitCast(self.ptr.fetchWord());
    } else {
        a = @intCast(self.ptr.fetchByte());
    }
    vm_log.debug("Script::op_condJmp({}, 0x{X:0>2}, 0x{X:0>2}) var=0x{X:0>2}", .{ op, @as(u16, @bitCast(b)), @as(u16, @bitCast(a)), variable });
    var expr = false;
    switch (op & 7) {
        0 => {
            expr = (b == a);
            if (!self.context.enable_protection) {
                if (self.context.getCurrentPart(self.context.user_data) == .copy_protection) {
                    //
                    // 0CB8: jmpIf(VAR(0x29) == VAR(0x1E), @0CD3)
                    // ...
                    //
                    if (variable == 0x29 and (op & 0x80) != 0) {
                        // 4 symbols
                        self.vars[0x29] = self.vars[0x1E];
                        self.vars[0x2A] = self.vars[0x1F];
                        self.vars[0x2B] = self.vars[0x20];
                        self.vars[0x2C] = self.vars[0x21];
                        // counters
                        self.vars[0x32] = 6;
                        self.vars[0x64] = 20;
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
        opJmp(self);
        if (variable == GAME_VAR_SCREEN_NUM and self.screen_num != self.vars[GAME_VAR_SCREEN_NUM]) {
            self.fixupPaletteChangeScreen(self.context.getCurrentPart(self.context.user_data), self.vars[GAME_VAR_SCREEN_NUM]);
            self.screen_num = self.vars[GAME_VAR_SCREEN_NUM];
        }
    } else {
        _ = self.ptr.fetchWord();
    }
}

fn opSetPalette(self: *Self) void {
    const i = self.ptr.fetchWord();
    const num = i >> 8;
    self.context.setPalette(self.context.user_data, @truncate(num));
}

fn opChangeTasksState(self: *Self) void {
    const start = self.ptr.fetchByte();
    const end = self.ptr.fetchByte();
    if (end < start) {
        vm_log.warn("Script::op_changeTasksState() ec=0x880 (end < start)", .{});
        return;
    }
    const state = self.ptr.fetchByte();

    vm_log.debug("Script::op_changeTasksState({}, {}, {})", .{ start, end, state });

    if (state == 2) {
        for (start..end + 1) |i| {
            self.tasks[i].next_pc = GAME_INACTIVE_TASK - 1;
        }
    } else if (state < 2) {
        for (start..end + 1) |i| {
            self.tasks[i].next_state = state;
        }
    }
}

fn opSelectPage(self: *Self) void {
    const i = self.ptr.fetchByte();
    vm_log.debug("Script::op_selectPage({})", .{i});
    self.context.setVideoWorkPagePtr(self.context.user_data, i);
}

fn opFillPage(self: *Self) void {
    const i = self.ptr.fetchByte();
    const color = self.ptr.fetchByte();
    vm_log.debug("Script::op_fillPage({}, {})", .{ i, color });
    self.context.fillPage(self.context.user_data, i, color);
}

fn opCopyPage(self: *Self) void {
    const i = self.ptr.fetchByte();
    const j = self.ptr.fetchByte();
    vm_log.debug("Script::op_copyPage({}, {})", .{ i, j });
    self.context.copyPage(self.context.user_data, i, j, self.vars[GAME_VAR_SCROLL_Y]);
}

fn opUpdateDisplay(self: *Self) void {
    const page = self.ptr.fetchByte();
    self.context.updateDisplay(self.context.user_data, page);
}

fn opRemoveTask(self: *Self) void {
    vm_log.debug("Script::op_removeTask()", .{});
    self.ptr.pc = 0xFFFF;
    self.paused = true;
}

fn opDrawString(self: *Self) void {
    const strId = self.ptr.fetchWord();
    const x: u16 = self.ptr.fetchByte();
    const y: u16 = self.ptr.fetchByte();
    const col: u16 = self.ptr.fetchByte();
    vm_log.debug("Script::op_drawString(0x{X}, {}, {}, {})", .{ strId, x, y, col });
    self.context.drawString(self.context.user_data, @truncate(col), x, y, strId);
}

fn opSub(self: *Self) void {
    const i = self.ptr.fetchByte();
    const j = self.ptr.fetchByte();
    vm_log.debug("Script::op_sub(0x{X}, 0x{X})", .{ i, j });
    self.vars[i] -= self.vars[j];
}

fn opAnd(self: *Self) void {
    const i = self.ptr.fetchByte();
    const n: u16 = self.ptr.fetchWord();
    vm_log.debug("Script::op_and(0x{X}, {})", .{ i, n });
    self.vars[i] = @bitCast(@as(u16, @bitCast(self.vars[i])) & n);
}

fn opOr(self: *Self) void {
    const i = self.ptr.fetchByte();
    const n: i16 = @bitCast(self.ptr.fetchWord());
    vm_log.debug("Script::op_or(0x{X}, {})", .{ i, n });
    self.vars[i] = self.vars[i] | n;
}

fn opShl(self: *Self) void {
    const i = self.ptr.fetchByte();
    const n: u4 = @intCast(self.ptr.fetchWord());
    vm_log.debug("Script::op_shl(0x{X:0>2}, {})", .{ i, n });
    self.vars[i] = @bitCast(@as(u16, @bitCast(self.vars[i])) << n);
}

fn opShr(self: *Self) void {
    const i = self.ptr.fetchByte();
    const n: u4 = @intCast(self.ptr.fetchWord());
    vm_log.debug("Script::op_shr(0x{X:0>2}, {})", .{ i, n });
    self.vars[i] = @bitCast(@as(u16, @intCast(self.vars[i])) >> n);
}

fn opPlaySound(self: *Self) void {
    const res_num = self.ptr.fetchWord();
    const freq = self.ptr.fetchByte();
    const vol: u8 = @truncate(self.ptr.fetchByte());
    const channel = self.ptr.fetchByte();
    vm_log.debug("Script::op_playSound(0x{X}, {}, {}, {})", .{ res_num, freq, vol, channel });
    self.context.sndPlaySound(self.context.user_data, res_num, freq, vol, @intCast(channel));
}

fn opUpdateResources(self: *Self) void {
    const num = self.ptr.fetchWord();
    vm_log.debug("Script::op_updateResources({})", .{num});
    self.context.updateResources(self.context.user_data, num);
}

fn opPlayMusic(self: *Self) void {
    const res_num = self.ptr.fetchWord();
    const delay = self.ptr.fetchWord();
    const pos = self.ptr.fetchByte();
    vm_log.debug("Script::op_playMusic(0x{X}, {}, {})", .{ res_num, delay, pos });
    self.context.sndPlayMusic(self.context.user_data, res_num, delay, pos);
}

const OpFunc = *const fn (*Self) void;
pub const op_table = [_]OpFunc{
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
