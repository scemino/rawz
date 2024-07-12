keymask: u8,
counter: u8,
buf_ptr: []const u8,
buf_pos: isize,

const Self = @This();

pub fn start(demo_joy: *Self) bool {
    if (demo_joy.buf_ptr.len > 0) {
        demo_joy.keymask = demo_joy.buf_ptr[0];
        demo_joy.counter = demo_joy.buf_ptr[1];
        demo_joy.buf_pos = 2;
        return true;
    }
    return false;
}

pub fn read(demo_joy: *Self, buf: []const u8) void {
    demo_joy.buf_ptr = buf;
    demo_joy.buf_pos = -1;
}

pub fn update(demo_joy: *Self) u8 {
    if (demo_joy.buf_pos >= 0 and demo_joy.buf_pos < demo_joy.buf_ptr.len) {
        if (demo_joy.counter == 0) {
            demo_joy.keymask = demo_joy.buf_ptr[@intCast(demo_joy.buf_pos)];
            demo_joy.buf_pos += 1;
            demo_joy.counter = demo_joy.buf_ptr[@intCast(demo_joy.buf_pos)];
            demo_joy.buf_pos += 1;
        } else {
            demo_joy.counter -= 1;
        }
        return demo_joy.keymask;
    }
    return 0;
}
