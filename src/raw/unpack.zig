const std = @import("std");
const assert = std.debug.assert;

pub fn byteKillerUnpack(dst: []u8, src: []const u8) !void {
    var uc = try UnpackContext.init(dst, src);

    while (uc.size > 0) {
        if (!uc.nextBit()) {
            if (!uc.nextBit()) {
                uc.copyLiteral(3, 0);
            } else {
                uc.copyReference(8, 2);
            }
        } else {
            const code = uc.getBits(2);
            switch (code) {
                3 => uc.copyLiteral(8, 8),
                2 => uc.copyReference(12, @intCast(uc.getBits(8) + 1)),
                1 => uc.copyReference(10, 4),
                0 => uc.copyReference(9, 3),
                else => return error.UnexpectedCode,
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

    fn init(dst: []u8, src: []const u8) !UnpackContext {
        const size: usize = @intCast(std.mem.readInt(u32, src[src.len - 4 ..][0..4], .big));
        if (size > dst.len) return error.UnexpectedUnpackSize;

        const src_i: usize = @intCast(src.len - 8);
        const bits = std.mem.readInt(u32, src[src_i - 4 ..][0..4], .big);
        const crc = std.mem.readInt(u32, src[src_i..][0..4], .big) ^ bits;

        return UnpackContext{
            .src_buf = src,
            .src_i = src_i - 4,
            .size = size,
            .dst_buf = dst,
            .dst_i = size,
            .crc = crc,
            .bits = bits,
        };
    }

    fn nextBit(uc: *UnpackContext) bool {
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

    fn getBits(uc: *UnpackContext, count: usize) u32 { // rdd1bits
        var bits: u32 = 0;
        for (0..count) |_| {
            bits <<= 1;
            if (nextBit(uc)) {
                bits |= 1;
            }
        }
        return bits;
    }

    fn copyLiteral(uc: *UnpackContext, bits_count: usize, len: u32) void { // getd3chr
        var count: usize = @intCast(getBits(uc, bits_count) + len + 1);
        uc.size -= count;
        if (uc.size < 0) {
            count += uc.size;
            uc.size = 0;
        }
        for (0..count) |_| {
            uc.dst_i -= 1;
            uc.dst_buf[uc.dst_i] = @intCast(getBits(uc, 8));
        }
    }

    fn copyReference(uc: *UnpackContext, bits_count: usize, count: usize) void { // copyd3bytes
        var c = count;
        uc.size -= c;
        if (uc.size < 0) {
            c += uc.size;
            uc.size = 0;
        }
        const offset: usize = @intCast(getBits(uc, bits_count));
        for (0..c) |_| {
            uc.dst_i -= 1;
            uc.dst_buf[uc.dst_i] = uc.dst_buf[uc.dst_i + offset];
        }
    }
};
