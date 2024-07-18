const std = @import("std");
const assert = std.debug.assert;

pub fn byteKillerUnpack(dst: []u8, src: []const u8) bool {
    var uc = UnpackContext{
        .src_buf = src,
        .src_i = @intCast(src.len - 8),
        .size = @intCast(std.mem.readInt(u32, src[src.len - 4 ..][0..4], .big)),
        .dst_buf = dst,
        .dst_i = 0,
        .crc = 0,
        .bits = 0,
    };
    if (uc.size > dst.len) {
        std.log.warn("Unexpected unpack size {}, buffer size {}", .{ uc.size, dst.len });
        return false;
    }
    uc.dst_i = uc.size - 1;
    uc.crc = std.mem.readInt(u32, src[@intCast(uc.src_i)..][0..4], .big);
    uc.src_i -= 4;
    uc.bits = std.mem.readInt(u32, src[@intCast(uc.src_i)..][0..4], .big);
    uc.src_i -= 4;
    uc.crc ^= uc.bits;
    while (uc.size > 0) {
        if (!next_bit(&uc)) {
            if (!next_bit(&uc)) {
                copy_literal(&uc, 3, 0);
            } else {
                copy_reference(&uc, 8, 2);
            }
        } else {
            const code = get_bits(&uc, 2);
            switch (code) {
                3 => copy_literal(&uc, 8, 8),
                2 => copy_reference(&uc, 12, @intCast(get_bits(&uc, 8) + 1)),
                1 => copy_reference(&uc, 10, 4),
                0 => copy_reference(&uc, 9, 3),
                else => unreachable,
            }
        }
    }
    assert(uc.size == 0);
    return uc.crc == 0;
}

const UnpackContext = struct {
    size: isize,
    crc: u32,
    bits: u32,
    dst_buf: []u8,
    dst_i: isize,
    src_buf: []const u8,
    src_i: isize,
};

fn next_bit(uc: *UnpackContext) bool {
    var carry = (uc.bits & 1) != 0;
    uc.bits >>= 1;
    if (uc.bits == 0) { // getnextlwd
        uc.bits = std.mem.readInt(u32, uc.src_buf[@intCast(uc.src_i)..][0..4], .big);
        uc.src_i -= 4;
        uc.crc ^= uc.bits;
        carry = (uc.bits & 1) != 0;
        uc.bits = (1 << 31) | (uc.bits >> 1);
    }
    return carry;
}

fn get_bits(uc: *UnpackContext, count: isize) i32 { // rdd1bits
    var bits: i32 = 0;
    for (0..@intCast(count)) |_| {
        bits <<= 1;
        if (next_bit(uc)) {
            bits |= 1;
        }
    }
    return bits;
}

fn copy_literal(uc: *UnpackContext, bits_count: isize, len: i32) void { // getd3chr
    var count: isize = @intCast(get_bits(uc, bits_count) + len + 1);
    uc.size -= count;
    if (uc.size < 0) {
        count += uc.size;
        uc.size = 0;
    }
    for (0..@intCast(count)) |i| {
        uc.dst_buf[@as(usize, @intCast(uc.dst_i)) - i] = @intCast(get_bits(uc, 8));
    }
    uc.dst_i -= count;
}

fn copy_reference(uc: *UnpackContext, bits_count: isize, count: isize) void { // copyd3bytes
    var c = count;
    uc.size -= c;
    if (uc.size < 0) {
        c += uc.size;
        uc.size = 0;
    }
    const offset: usize = @intCast(get_bits(uc, bits_count));
    for (0..@intCast(c)) |i| {
        uc.dst_buf[@as(usize, @intCast(uc.dst_i)) - i] = uc.dst_buf[@as(usize, @intCast(uc.dst_i)) - i + offset];
    }
    uc.dst_i -= c;
}
