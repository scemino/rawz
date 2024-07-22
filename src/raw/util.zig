const std = @import("std");

pub fn readBeU16(buf: []const u8) u16 {
    return std.mem.readInt(u16, buf[0..2], .big);
}

pub fn readLeU16(buf: []const u8) u32 {
    return std.mem.readInt(u16, buf[0..2], .little);
}

pub fn readLeU32(buf: []const u8) u32 {
    return std.mem.readInt(u32, buf[0..4], .little);
}
