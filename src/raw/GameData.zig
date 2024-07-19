const std = @import("std");

mem_list: ?[]const u8 = null, // contains content of memlist.bin file if present
banks: GameBanks,
demo3_joy: ?[]const u8 = null, // contains content of demo3.joy file if present

const Self = @This();

const GameBanks = struct {
    bank01: ?[]const u8 = null,
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

    pub fn get(self: GameBanks, i: usize) ?[]const u8 {
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

const Banks = [16]?[]const u8;

pub fn readData(path: []const u8) ?Self {
    const stat = std.fs.cwd().statFile(path) catch return null;
    const maybe_banks: Banks = switch (stat.kind) {
        .directory => readBanksFromDirectory(path),
        .file => readBanksFromTar(path),
        else => return null,
    };
    return toGameData(maybe_banks);
}

fn toGameData(banks: Banks) ?Self {
    return .{
        .banks = .{
            .bank01 = banks[0x1],
            .bank02 = banks[0x2],
            .bank03 = banks[0x3],
            .bank04 = banks[0x4],
            .bank05 = banks[0x5],
            .bank06 = banks[0x6],
            .bank07 = banks[0x7],
            .bank08 = banks[0x8],
            .bank09 = banks[0x9],
            .bank0A = banks[0xA],
            .bank0B = banks[0xB],
            .bank0C = banks[0xC],
            .bank0D = banks[0xD],
        },
        .mem_list = banks[0xE],
        .demo3_joy = banks[0xF],
    };
}

fn readBanksFromTar(path: []const u8) Banks {
    var file = std.fs.cwd().openFile(path, .{}) catch @panic("Failed to open dir");
    const reader = file.reader();
    var filename_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var it = std.tar.iterator(reader, .{
        .file_name_buffer = &filename_buffer,
        .link_name_buffer = &link_name_buffer,
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // yerate through the tar file to see if files match
    var banks: Banks = [1]?[]const u8{null} ** 16;
    while (it.next() catch @panic("Failed to iterate tar")) |entry| {
        var out_str: [16]u8 = undefined;
        var entry_reader = entry.reader();
        if (std.mem.eql(u8, std.ascii.lowerString(&out_str, entry.name[0..4]), "bank")) {
            const index = std.fmt.parseInt(u8, entry.name[4..], 16) catch continue;
            banks[index] = entry_reader.readAllAlloc(gpa.allocator(), 246 * 1024) catch @panic("Failed to read file");
        } else if (std.mem.eql(u8, std.ascii.lowerString(&out_str, entry.name), "memlist.bin")) {
            banks[0xE] = entry_reader.readAllAlloc(gpa.allocator(), 246 * 1024) catch @panic("Failed to read file");
        } else if (std.mem.eql(u8, std.ascii.lowerString(&out_str, entry.name), "demo3.joy")) {
            banks[0xF] = entry_reader.readAllAlloc(gpa.allocator(), 246 * 1024) catch @panic("Failed to read file");
        }
    }
    return banks;
}

fn readBanksFromDirectory(path: []const u8) Banks {
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch @panic("Failed to open dir");
    defer dir.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var banks: Banks = [1]?[]const u8{null} ** 16;
    var it = dir.iterate();
    while (it.next() catch @panic("Failed to iterate dir")) |entry| {
        var out_str: [16]u8 = undefined;
        if (std.mem.eql(u8, std.ascii.lowerString(&out_str, entry.name[0..4]), "bank")) {
            const index = std.fmt.parseInt(u8, entry.name[4..], 16) catch continue;
            banks[index] = dir.readFileAlloc(gpa.allocator(), entry.name, 246 * 1024) catch @panic("Failed to read file");
        } else if (std.mem.eql(u8, std.ascii.lowerString(&out_str, entry.name[0..11]), "memlist.bin")) {
            banks[0xE] = dir.readFileAlloc(gpa.allocator(), entry.name, 246 * 1024) catch @panic("Failed to read file");
        } else if (std.mem.eql(u8, std.ascii.lowerString(&out_str, entry.name[0..9]), "demo3.joy")) {
            banks[0xF] = dir.readFileAlloc(gpa.allocator(), entry.name, 246 * 1024) catch @panic("Failed to read file");
        }
    }
    return banks;
}
