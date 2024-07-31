const std = @import("std");
const GameData = @import("GameData.zig");
const Gfx = @import("Gfx.zig");
const mementries = @import("mementries.zig");
const Strings = @import("Strings.zig");
pub const GameDataType = mementries.GameDataType;
pub const GameLang = Strings.GameLang;
pub const byteKillerUnpack = @import("unpack.zig").byteKillerUnpack;
pub const detectAmigaAtari = mementries.detectAmigaAtari;

const assert = std.debug.assert;

pub const GAME_MEM_BLOCK_SIZE = 1 * 1024 * 1024;
pub const GAME_ENTRIES_COUNT = 146;

pub const mem_list_parts = [_][4]u8{
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

const bank_log = std.log.scoped(.bank);

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

pub const GameResStatus = enum(u8) {
    null,
    loaded,
    toload,
    uninit = 0xff,
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

mem_list: [GAME_ENTRIES_COUNT]GameMemEntry = undefined,
num_mem_list: u16 = 0,
mem: [GAME_MEM_BLOCK_SIZE]u8 = undefined,
current_part: GamePart = undefined,
next_part: ?GamePart = null,
script_bak: usize = 0,
script_cur: usize = 0,
vid_cur: usize = GAME_MEM_BLOCK_SIZE - (Gfx.GAME_WIDTH * Gfx.GAME_HEIGHT / 2), // 4bpp bitmap,
use_seg_video2: bool = false,
seg_video_pal: []u8 = undefined,
seg_code: []u8 = undefined,
seg_code_size: u16 = 0,
seg_video1: []u8 = undefined,
seg_video2: []u8 = undefined,
has_password_screen: bool = true,
data_type: GameDataType = undefined,
data: GameData,
user_data: ?*anyopaque,
copy_bitmap: *const fn (user_data: ?*anyopaque, src: []const u8) void,
set_palette: *const fn (user_data: ?*anyopaque, pal: u8) void,
lang: GameLang,
const Self = @This();

const Context = struct {
    lang: GameLang,
    data: GameData,
    user_data: ?*anyopaque,
    copy_bitmap: *const fn (user_data: ?*anyopaque, src: []const u8) void,
    set_palette: *const fn (user_data: ?*anyopaque, pal: u8) void,
};

pub fn init(context: Context) !Self {
    var self = Self{
        .lang = context.lang,
        .data = context.data,
        .user_data = context.user_data,
        .copy_bitmap = context.copy_bitmap,
        .set_palette = context.set_palette,
    };
    self.detectVersion();
    try self.readEntries();
    return self;
}

pub fn readBank(self: *Self, me: *const GameMemEntry, dst_buf: []u8) bool {
    if (me.bank_num > 0xd)
        return false;

    if (self.data.banks.get(me.bank_num - 1)) |bank| {
        if (me.packed_size != me.unpacked_size) {
            if (byteKillerUnpack(dst_buf[0..me.unpacked_size], bank[me.bank_pos..][0..me.packed_size])) {
                return true;
            } else |_| {
                return false;
            }
        } else {
            @memcpy(dst_buf[0..me.unpacked_size], bank[me.bank_pos..][0..me.packed_size]);
        }

        return true;
    }
    return false;
}

pub fn load(self: *Self) void {
    while (true) {
        var me_found: ?*GameMemEntry = null;

        // get resource with max rank_num
        var max_num: u8 = 0;
        var resource_num: usize = 0;
        for (0..self.num_mem_list) |i| {
            const it = &self.mem_list[i];
            if (it.status == .toload and max_num <= it.rank_num) {
                max_num = it.rank_num;
                me_found = it;
                resource_num = i;
            }
        }
        if (me_found) |me| {
            var mem_ptr: []u8 = undefined;
            if (me.type == .bitmap) {
                mem_ptr = self.mem[self.vid_cur..];
            } else {
                mem_ptr = self.mem[self.script_cur..];
                const avail: usize = (self.vid_cur - self.script_cur);
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
                bank_log.debug("Resource::load() bufPos=0x{X} size={} type={} pos=0x{X} bankNum={}", .{ self.mem.len - mem_ptr.len, me.packed_size, me.type, me.bank_pos, me.bank_num });
                if (self.readBank(me, mem_ptr)) {
                    if (me.type == .bitmap) {
                        self.copy_bitmap(self.user_data, self.mem[self.vid_cur..]);
                        me.status = .null;
                    } else {
                        me.buf_ptr = mem_ptr;
                        me.status = .loaded;
                        self.script_cur += me.unpacked_size;
                    }
                } else {
                    if (self.data_type == .dos and me.bank_num == 12 and me.type == .bank) {
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

pub fn readEntries(self: *Self) !void {
    switch (self.data_type) {
        .amiga, .atari => {
            assert(self.num_mem_list > 0);
        },
        .dos => {
            self.has_password_screen = false; // DOS demo versions do not have the resources
            const mem_list = self.data.mem_list orelse @panic("mem list is mandatory for pc version");
            var stream = std.io.fixedBufferStream(mem_list);
            var reader = stream.reader();
            while (true) {
                const status: GameResStatus = @enumFromInt(try reader.readByte());
                if (status == .uninit) {
                    self.has_password_screen = self.data.banks.bank08 != null;
                    return;
                }
                assert(self.num_mem_list < self.mem_list.len);
                var me = &self.mem_list[self.num_mem_list];
                me.status = status;
                me.type = @enumFromInt(try reader.readByte());
                me.buf_ptr = &[0]u8{};
                _ = try reader.readInt(u32, .big);
                me.rank_num = try reader.readByte();
                me.bank_num = try reader.readByte();
                me.bank_pos = try reader.readInt(u32, .big);
                me.packed_size = try reader.readInt(u32, .big);
                me.unpacked_size = try reader.readInt(u32, .big);
                self.num_mem_list += 1;
            }
        },
    }
}

pub fn invalidate(self: *Self) void {
    for (&self.mem_list) |*me| {
        if (@intFromEnum(me.type) <= 2 or @intFromEnum(me.type) > 6) {
            me.*.status = .null;
        }
    }
    self.script_cur = self.script_bak;
    self.set_palette(self.user_data, 0xFF);
}

pub fn invalidateAll(self: *Self) void {
    for (0..self.num_mem_list) |i| {
        self.mem_list[i].status = .null;
    }
    self.script_cur = 0;
    self.set_palette(self.user_data, 0xFF);
}

pub fn setupPart(self: *Self, id: usize) void {
    if (@as(GamePart, @enumFromInt(id)) != self.current_part) {
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
        self.invalidateAll();
        self.mem_list[ipal].status = .toload;
        self.mem_list[icod].status = .toload;
        self.mem_list[ivd1].status = .toload;
        if (ivd2 != 0) {
            self.mem_list[ivd2].status = .toload;
        }
        self.load();
        self.seg_video_pal = self.mem_list[ipal].buf_ptr;
        self.seg_code = self.mem_list[icod].buf_ptr;
        self.seg_code_size = @intCast(self.mem_list[icod].unpacked_size);
        self.seg_video1 = self.mem_list[ivd1].buf_ptr;
        if (ivd2 != 0) {
            self.seg_video2 = self.mem_list[ivd2].buf_ptr;
        }
        self.current_part = @enumFromInt(id);
    }
    self.script_bak = self.script_cur;
}

pub fn update(self: *Self, num: u16) void {
    if (num > 16000) {
        self.next_part = @enumFromInt(num);
        return;
    }

    var me = &self.mem_list[num];
    if (me.status == .null) {
        me.status = .toload;
        self.load();
    }
}

fn detectVersion(self: *Self) void {
    if (self.data.mem_list) |_| {
        // only DOS game has a memlist.bin file
        self.data_type = .dos;
        std.log.info("Using DOS data files", .{});
    } else {
        const detection = detectAmigaAtari(self.data.banks.bank01.?.len);
        if (detection) |detected| {
            self.data_type = detected.data_type;
            if (detected.data_type == .atari) {
                std.log.info("Using Atari data files", .{});
            } else {
                std.log.info("Using Amiga data files", .{});
            }
            self.num_mem_list = GAME_ENTRIES_COUNT;
            for (0..GAME_ENTRIES_COUNT) |i| {
                self.mem_list[i].type = @enumFromInt(detected.entries[i].type);
                self.mem_list[i].bank_num = detected.entries[i].bank;
                self.mem_list[i].bank_pos = detected.entries[i].offset;
                self.mem_list[i].packed_size = detected.entries[i].packed_size;
                self.mem_list[i].unpacked_size = detected.entries[i].unpacked_size;
            }
        }
    }
}
