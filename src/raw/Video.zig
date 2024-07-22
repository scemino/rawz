const std = @import("std");
const GamePc = @import("GamePc.zig");
const Gfx = @import("Gfx.zig");
const util = @import("util.zig");
const mementries = @import("mementries.zig");
const assert = std.debug.assert;

data_type: mementries.GameDataType,
next_pal: u8,
current_pal: u8,
buffers: [3]u2 = undefined,
p_data: GamePc = undefined,
data_buf: []u8 = undefined,
use_ega: bool,
gfx: *Gfx,
const Self = @This();

const video_log = std.log.scoped(.video);

const palette_ega = [_]u8{
    0x00, 0x00, 0x00, // black #0
    0x00, 0x00, 0xAA, // blue #1
    0x00, 0xAA, 0x00, // green #2
    0x00, 0xAA, 0xAA, // cyan #3
    0xAA, 0x00, 0x00, // red #4
    0xAA, 0x00, 0xAA, // magenta #5
    0xAA, 0x55, 0x00, // yellow, brown #20
    0xAA, 0xAA, 0xAA, // white, light gray #7
    0x55, 0x55, 0x55, // dark gray, bright black #56
    0x55, 0x55, 0xFF, // bright blue #57
    0x55, 0xFF, 0x55, // bright green #58
    0x55, 0xFF, 0xFF, // bright cyan #59
    0xFF, 0x55, 0x55, // bright red #60
    0xFF, 0x55, 0xFF, // bright magenta #61
    0xFF, 0xFF, 0x55, // bright yellow #62
    0xFF, 0xFF, 0xFF, // bright white #63
};

pub fn init(gfx: *Gfx, data_type: mementries.GameDataType, use_ega: bool) Self {
    var self = Self{
        .next_pal = 0xFF,
        .current_pal = 0xFF,
        .gfx = gfx,
        .data_type = data_type,
        .use_ega = use_ega,
    };
    self.setWorkPagePtr(0xfe);
    return self;
}

fn getPagePtr(self: *Self, page: u8) u2 {
    if (page <= 3) {
        return @truncate(page);
    }

    switch (page) {
        0xFF => return self.buffers[2],
        0xFE => return self.buffers[1],
        else => {
            std.log.warn("Video::getPagePtr() p != [0,1,2,3,0xFF,0xFE] == 0x{X}", .{page});
            return 0; // XXX check
        },
    }
}

pub fn setWorkPagePtr(self: *Self, page: u8) void {
    video_log.debug("Video::setWorkPagePtr({})", .{page});
    self.buffers[0] = self.getPagePtr(page);
}

pub fn fillPage(self: *Self, page: u8, color: u8) void {
    video_log.debug("Video::fillPage({}, {})", .{ page, color });
    self.gfx.clearBuffer(self.getPagePtr(page), color);
}

pub fn updateDisplay(self: *Self, seg_video_pal: []u8, page: u8) void {
    video_log.debug("Video::updateDisplay({})", .{page});
    if (page != 0xFE) {
        if (page == 0xFF) {
            swap(&self.buffers[1], &self.buffers[2]);
        } else {
            self.buffers[1] = self.getPagePtr(page);
        }
    }
    if (self.next_pal != 0xFF) {
        self.changePal(seg_video_pal, self.next_pal);
        self.next_pal = 0xFF;
    }
    self.gfx.drawBuffer(self.buffers[1]);
}

fn fillPolygon(self: *Self, color: u16, zoom: u16, pt: Gfx.GamePoint) void {
    var pc = self.p_data;

    const bbw: u16 = pc.data[pc.pc] * zoom / 64;
    const bbh: u16 = pc.data[pc.pc + 1] * zoom / 64;
    pc.pc += 2;

    const x1: i16 = @intCast(pt.x - @as(i16, @intCast(bbw / 2)));
    const x2: i16 = @intCast(pt.x + @as(i16, @intCast(bbw / 2)));
    const y1: i16 = @intCast(pt.y - @as(i16, @intCast(bbh / 2)));
    const y2: i16 = @intCast(pt.y + @as(i16, @intCast(bbh / 2)));

    if (x1 >= Gfx.GAME_WIDTH or x2 < 0 or y1 >= Gfx.GAME_HEIGHT or y2 < 0)
        return;

    var qs: Gfx.GameQuadStrip = undefined;
    qs.num_vertices = pc.data[pc.pc];
    pc.pc += 1;
    if ((qs.num_vertices & 1) != 0) {
        std.log.warn("Unexpected number of vertices {}", .{qs.num_vertices});
        return;
    }
    assert(qs.num_vertices < Gfx.GAME_QUAD_STRIP_MAX_VERTICES);

    for (0..qs.num_vertices) |i| {
        qs.vertices[i] = .{
            .x = @intCast(@as(i32, x1) + @as(i32, pc.data[pc.pc] * zoom / 64)),
            .y = @intCast(@as(i32, y1) + @as(i32, pc.data[pc.pc + 1] * zoom / 64)),
        };
        pc.pc += 2;
    }

    if (qs.num_vertices == 4 and bbw == 0 and bbh <= 1) {
        self.gfx.drawPointPage(self.buffers[0], @truncate(color), pt);
    } else {
        self.gfx.drawQuadStrip(self.buffers[0], @truncate(color), &qs);
    }
}

pub fn drawString(self: *Self, color: u8, xx: u16, yy: u16, str: []const u8) void {
    var x = xx;
    var y = yy;
    const escapedChars = false;

    video_log.debug("drawString({}, {}, {}, '{s}')", .{ color, x, y, str });
    const len = str.len;
    for (0..len) |i| {
        if (str[i] == '\n' or str[i] == '\r') {
            y += 8;
            x = xx;
        } else if (str[i] == '\\' and escapedChars) {
            i += 1;
            if (i < len) {
                switch (str[i]) {
                    'n' => {
                        y += 8;
                        x = xx;
                    },
                }
            }
        } else {
            const pt: Gfx.GamePoint = .{ .x = @as(i16, @bitCast(x * 8)), .y = @as(i16, @bitCast(y)) };
            self.gfx.drawStringChar(self.buffers[0], color, str[i], pt);
            x += 1;
        }
    }
}

fn readPaletteEga(buf: []const u8, num: u8, pal: *[16]u32) void {
    var p = buf[@as(usize, @intCast(num)) * 16 * @sizeOf(u16) ..];
    p = p[1024..]; // EGA colors are stored after VGA (Amiga)
    inline for (0..16) |i| {
        const color: usize = util.readBeU16(p);
        p = p[2..];
        const ega = palette_ega[3 * ((color >> 12) & 15) ..][0..3];
        pal[i] = 0xFF000000 | @as(u32, @intCast(ega[0])) | (@as(u32, @intCast(ega[1])) << 8) | (@as(u32, @intCast(ega[2])) << 16);
    }
}

fn readPaletteAmiga(buf: []const u8, num: u8, pal: *[16]u32) void {
    var p = buf[@as(usize, @intCast(num)) * 16 * @sizeOf(u16) ..];
    inline for (0..16) |i| {
        const color = util.readBeU16(p[i * 2 ..]);
        var r: u32 = (color >> 8) & 0xF;
        var g: u32 = (color >> 4) & 0xF;
        var b: u32 = color & 0xF;
        r = (r << 4) | r;
        g = (g << 4) | g;
        b = (b << 4) | b;
        pal[i] = 0xFF000000 | r | (g << 8) | (b << 16);
    }
}

pub fn changePal(self: *Self, seg_video_pal: []u8, pal_num: u8) void {
    if (pal_num < 32 and pal_num != self.current_pal) {
        var pal: [16]u32 = [1]u32{0} ** 16;
        if (self.data_type == .dos and self.use_ega) {
            readPaletteEga(seg_video_pal, pal_num, &pal);
        } else {
            readPaletteAmiga(seg_video_pal, pal_num, &pal);
        }
        self.gfx.setPalette(pal);
        self.current_pal = pal_num;
    }
}

pub fn copyPage(self: *Self, s: u8, dst: u8, vscroll: i16) void {
    var src = s;
    video_log.debug("Video::copyPage({}, {})", .{ src, dst });
    if (src < 0xFE) {
        src = src & 0xBF; //~0x40
    }
    if (src >= 0xFE or (src & 0x80) == 0) { // no vscroll
        self.gfx.copyBuffer(self.getPagePtr(dst), self.getPagePtr(src), 0);
    } else {
        const sl = self.getPagePtr(src & 3);
        const dl = self.getPagePtr(dst);
        if (sl != dl and vscroll >= -199 and vscroll <= 199) {
            self.gfx.copyBuffer(dl, sl, vscroll);
        }
    }
}

pub fn setDataBuffer(self: *Self, dataBuf: []u8, offset: u16) void {
    self.data_buf = dataBuf;
    self.p_data = .{ .data = dataBuf, .pc = offset };
}

fn drawShapeParts(self: *Self, zoom: u16, pgc: Gfx.GamePoint) void {
    const pt = Gfx.GamePoint{
        .x = pgc.x - @as(i16, @intCast(self.p_data.fetchByte() * zoom / 64)),
        .y = pgc.y - @as(i16, @intCast(self.p_data.fetchByte() * zoom / 64)),
    };
    const n: usize = @intCast(self.p_data.fetchByte());
    video_log.debug("Video::drawShapeParts n={}", .{n});
    for (0..n + 1) |_| {
        var offset = self.p_data.fetchWord();
        const po = Gfx.GamePoint{
            .x = @intCast(@as(i32, @intCast(pt.x)) + @divTrunc(@as(i32, @intCast(self.p_data.fetchByte())) * zoom, 64)),
            .y = @intCast(@as(i32, @intCast(pt.y)) + @divTrunc(@as(i32, @intCast(self.p_data.fetchByte())) * zoom, 64)),
        };
        var color: u16 = 0xFF;
        if ((offset & 0x8000) != 0) {
            color = self.p_data.fetchByte();
            _ = self.p_data.fetchByte();
            color &= 0x7F;
        }
        offset <<= 1;
        const bak = self.p_data.pc;
        self.p_data = .{ .data = self.data_buf, .pc = offset };
        self.drawShape(@truncate(color), zoom, po);
        self.p_data.pc = bak;
    }
}

pub fn drawShape(self: *Self, c: u8, zoom: u16, pt: Gfx.GamePoint) void {
    var color = c;
    var i = self.p_data.fetchByte();
    if (i >= 0xC0) {
        if ((color & 0x80) != 0) {
            color = i & 0x3F;
        }
        self.fillPolygon(color, zoom, pt);
    } else {
        i &= 0x3F;
        if (i == 1) {
            std.log.warn("Video::drawShape() ec=0xF80 (i != 2)", .{});
        } else if (i == 2) {
            self.drawShapeParts(zoom, pt);
        } else {
            std.log.warn("Video::drawShape() ec=0xFBB (i != 2)", .{});
        }
    }
}

fn swap(x: anytype, y: anytype) void {
    const tmp = y.*;
    y.* = x.*;
    x.* = tmp;
}

fn scaleBitmap(self: *Self, src: []const u8, fmt: Gfx.Format) void {
    self.gfx.drawBitmap(self.buffers[0], src, Gfx.GAME_WIDTH, Gfx.GAME_HEIGHT, fmt);
}

pub fn copyBitmapPtr(self: *Self, src: []const u8) void {
    if (self.data_type == .dos or self.data_type == .amiga) {
        var temp_bitmap: [Gfx.GAME_WIDTH * Gfx.GAME_HEIGHT]u8 = undefined;
        decodeAmiga(src, &temp_bitmap);
        self.scaleBitmap(temp_bitmap[0..], .clut);
    } else if (self.data_type == .atari) {
        var temp_bitmap: [Gfx.GAME_WIDTH * Gfx.GAME_HEIGHT]u8 = undefined;
        decodeAtari(src, &temp_bitmap);
        self.scaleBitmap(&temp_bitmap, .clut);
    } else { // .BMP
        var w: u16 = undefined;
        var h: u16 = undefined;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        if (decodeBitmap(src, &w, &h, gpa.allocator())) |buf| {
            self.gfx.drawBitmap(self.buffers[0], buf, w, h, .rgb);
            gpa.allocator().free(buf);
        }
    }
}

fn decodeBitmap(src: []const u8, w: *u16, h: *u16, allocator: std.mem.Allocator) ?[]u8 {
    if (!std.mem.eql(u8, src[0..2], "BM")) {
        return null;
    }
    const imageOffset: u32 = util.readLeU32(src[0xA..]);
    const width: i32 = @bitCast(util.readLeU32(src[0x12..]));
    const height: i32 = @bitCast(util.readLeU32(src[0x16..]));
    const depth: i32 = @intCast(util.readLeU16(src[0x1C..]));
    const compression: i32 = @bitCast(util.readLeU32(src[0x1E..]));
    if ((depth != 8 and depth != 32) or compression != 0) {
        std.log.warn("Unhandled bitmap depth {} compression {}", .{ depth, compression });
        return null;
    }
    const bpp = 3;
    var dst = allocator.alloc(u8, @intCast(width * height * bpp)) catch {
        std.log.warn("Failed to allocate bitmap buffer, width {} height {} bpp {}", .{ width, height, bpp });
        return null;
    };
    if (depth == 8) {
        const palette = src[14 + 40 ..]; // /BITMAPFILEHEADER + BITMAPINFOHEADER
        const flipY = true;
        clut(src[imageOffset..], palette, width, height, bpp, flipY, -1, dst);
    } else {
        assert(depth == 32 and bpp == 3);
        var p = src[imageOffset..];
        var y: i32 = height - 1;
        while (y >= 0) : (y -= 1) {
            var q = dst[@intCast(y * width * bpp)..];
            for (0..@intCast(width)) |_| {
                const color: u32 = util.readLeU32(p);
                p = p[4..];
                q[0] = @intCast((color >> 16) & 255);
                q[1] = @intCast((color >> 8) & 255);
                q[2] = @intCast(color & 255);
                q = q[3..];
            }
        }
    }
    w.* = @intCast(width);
    h.* = @intCast(height);
    return dst;
}

fn decodeAtari(source: []const u8, dest: []u8) void {
    var src = source;
    var dst = dest;
    for (0..Gfx.GAME_HEIGHT) |_| {
        var x: usize = 0;
        while (x < Gfx.GAME_WIDTH) : (x += 16) {
            inline for (0..16) |b| {
                const mask = 1 << (15 - b);
                var color: u8 = 0;
                inline for (0..4) |p| {
                    if ((util.readBeU16(src[p * 2 ..]) & mask) != 0) {
                        color |= 1 << p;
                    }
                }
                dst[0] = color;
                dst = dst[1..];
            }
            src = src[8..];
        }
    }
}

fn clut(source: []const u8, pal: []const u8, w: i32, h: i32, bpp: i32, flipY: bool, colorKey: i32, dest: []u8) void {
    var src = source;
    var dst = dest;
    var dstPitch = bpp * w;
    if (flipY) {
        dst = dst[@intCast((h - 1) * bpp * w)..];
        dstPitch = -bpp * w;
    }
    for (0..@intCast(h)) |_| {
        for (0..@intCast(w)) |x| {
            const color: usize = src[x];
            const b: i32 = pal[color * 4];
            const g: i32 = pal[color * 4 + 1];
            const r: i32 = pal[color * 4 + 2];
            dst[x * @as(usize, @intCast(bpp))] = @intCast(r);
            dst[x * @as(usize, @intCast(bpp)) + 1] = @intCast(g);
            dst[x * @as(usize, @intCast(bpp)) + 2] = @intCast(b);
            if (bpp == 4) {
                dst[x * @as(usize, @intCast(bpp)) + 3] = if (color == 0 or (colorKey == ((r << 16) | (g << 8) | b))) 0 else 255;
            }
        }
        src = src[@intCast(w)..];
        dst = dst[@intCast(dstPitch)..];
    }
}

fn decodeAmiga(src: []const u8, dst: []u8) void {
    const plane_size = Gfx.GAME_HEIGHT * Gfx.GAME_WIDTH / 8;
    var s: usize = 0;
    var d: usize = 0;
    for (0..Gfx.GAME_HEIGHT) |_| {
        var x: usize = 0;
        while (x < Gfx.GAME_WIDTH) : (x += 8) {
            inline for (0..8) |b| {
                const mask = 1 << (7 - b);
                var color: u8 = 0;
                inline for (0..4) |p| {
                    if ((src[s + p * plane_size] & mask) != 0) {
                        color |= 1 << p;
                    }
                }
                dst[d] = color;
                d += 1;
            }
            s += 1;
        }
    }
}
