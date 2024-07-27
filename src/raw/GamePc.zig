const std = @import("std");

data: []u8 = &[0]u8{},
pc: u16 = 0,
const Self = @This();

pub fn fetchByte(pc: *Self) u8 {
    const res = pc.data[pc.pc];
    pc.pc += 1;
    return res;
}

pub fn fetchWord(pc: *Self) u16 {
    const res = std.mem.readInt(u16, pc.data[pc.pc..][0..2], .big);
    pc.pc += 2;
    return res;
}
