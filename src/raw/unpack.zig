const std = @import("std");
const assert = std.debug.assert;

pub fn byteKillerUnpack(dst: []u8, src: []const u8) !void {
    const size: usize = @intCast(std.mem.readInt(u32, src[src.len - 4 ..][0..4], .big));
    if (size > dst.len) return error.UnexpectedUnpackSize;

    const src_i: usize = @intCast(src.len - 8);
    const bits = std.mem.readInt(u32, src[src_i - 4 ..][0..4], .big);
    const crc = std.mem.readInt(u32, src[src_i..][0..4], .big) ^ bits;

    var uc = UnpackContext{
        .src_buf = src,
        .src_i = src_i - 4,
        .size = size,
        .dst_buf = dst,
        .dst_i = size,
        .crc = crc,
        .bits = bits,
    };

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
    if (uc.size != 0) return error.UnexpectedFinalSize;
    if (uc.crc != 0) return error.UnexpectedCrc;
}

const UnpackContext = struct {
    size: usize,
    crc: u32,
    bits: u32,
    dst_buf: []u8,
    dst_i: usize,
    src_buf: []const u8,
    src_i: usize,
};

fn next_bit(uc: *UnpackContext) bool {
    var carry = (uc.bits & 1) != 0;
    uc.bits >>= 1;
    if (uc.bits == 0) { // getnextlwd
        uc.src_i -= 4;
        uc.bits = std.mem.readInt(u32, uc.src_buf[uc.src_i..][0..4], .big);
        uc.crc ^= uc.bits;
        carry = (uc.bits & 1) != 0;
        uc.bits = (1 << 31) | (uc.bits >> 1);
    }
    return carry;
}

fn get_bits(uc: *UnpackContext, count: usize) u32 { // rdd1bits
    var bits: u32 = 0;
    for (0..count) |_| {
        bits <<= 1;
        if (next_bit(uc)) {
            bits |= 1;
        }
    }
    return bits;
}

fn copy_literal(uc: *UnpackContext, bits_count: usize, len: u32) void { // getd3chr
    var count: usize = @intCast(get_bits(uc, bits_count) + len + 1);
    uc.size -= count;
    if (uc.size < 0) {
        count += uc.size;
        uc.size = 0;
    }
    for (0..count) |_| {
        uc.dst_i -= 1;
        uc.dst_buf[uc.dst_i] = @intCast(get_bits(uc, 8));
    }
}

fn copy_reference(uc: *UnpackContext, bits_count: usize, count: usize) void { // copyd3bytes
    var c = count;
    uc.size -= c;
    if (uc.size < 0) {
        c += uc.size;
        uc.size = 0;
    }
    const offset: usize = @intCast(get_bits(uc, bits_count));
    for (0..c) |_| {
        uc.dst_i -= 1;
        uc.dst_buf[uc.dst_i] = uc.dst_buf[uc.dst_i + offset];
    }
}
