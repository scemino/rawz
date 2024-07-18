pub const bits = 16;
const mask = (1 << bits) - 1;

inc: u64 = 0,
offset: u32 = 0,
const Self = @This();

pub fn reset(frac: *Self, n: i32, d: i32) void {
    // TODO: check this
    frac.inc = @as(u64, @bitCast(@divTrunc((@as(i64, n) << bits), d)));
    frac.offset = 0;
}

pub fn getInt(frac: Self) u32 {
    return @truncate(frac.offset >> bits);
}

fn getFrac(frac: Self) u32 {
    return @truncate(frac.offset & mask);
}

pub fn interpolate(frac: Self, sample1: i32, sample2: i32) i32 {
    const fp = getFrac(frac);
    return @truncate(((@as(i64, @intCast(sample1)) * (mask - fp)) + (@as(i64, @intCast(sample2)) * fp)) >> bits);
}
