const std = @import("std");
const Disasm = @import("Disasm.zig");

// the get string callback type
const raw_getstrt_t = *const fn (id: u16, user_data: ?*anyopaque) []const u8;

const Context = struct {
    pc: u16,
    in_cb: Disasm.ui_dasm_input_t,
    out_cb: ?Disasm.ui_dasm_output_t,
    user_data: ?*anyopaque,

    const digits = "0123456789";

    pub fn fetch_u8(self: *Context) u8 {
        const v = self.in_cb(self.user_data);
        self.pc += 1;
        return v;
    }

    pub fn fetch_u16(self: *Context) u16 {
        const v1: u16 = self.in_cb(self.user_data);
        const v2: u16 = self.in_cb(self.user_data);
        self.pc += 2;
        return (v1 << 8) | v2;
    }

    pub fn fetch_i16(self: *Context) i16 {
        return @bitCast(self.fetch_u16());
    }

    // function to output string
    pub fn write(self: *Context, str: []const u8) void {
        if (self.out_cb) |out_cb| {
            for (str) |c| {
                out_cb(c, self.user_data);
            }
        }
    }

    fn writeHex(self: *Context, val: u16) void {
        var buf: [5]u8 = undefined;
        const buf2 = std.fmt.bufPrint(&buf, "${X:0>4}", .{val}) catch @panic("format error");
        self.write(buf2);
    }

    // function to output an unsigned 8-bit value as decimal string
    pub fn writeDec(self: *Context, val: u8) void {
        if (self.out_cb) |out_cb| {
            if (val == 0) {
                out_cb(digits[0], self.user_data);
            } else {
                var div: u8 = 100;
                var b: bool = false;
                inline for (0..3) |_| {
                    const v: u8 = (val / div) % 10;
                    if (b or (v > 0)) {
                        b = true;
                        out_cb(digits[v & 0xF], self.user_data);
                    }
                    div /= 10;
                }
            }
        }
    }

    pub fn writeChr(self: *Context, val: u8) void {
        if (self.out_cb) |out_cb| {
            out_cb(val, self.user_data);
        }
    }
};

pub fn disasmOp(pc: u16, in_cb: Disasm.ui_dasm_input_t, out_cb: Disasm.ui_dasm_output_t, get_str_cb: raw_getstrt_t, user_data: ?*anyopaque) u16 {
    var ctx = Context{ .pc = pc, .in_cb = in_cb, .out_cb = out_cb, .user_data = user_data };
    const op: u8 = ctx.fetch_u8();

    // opcode name
    switch (op) {
        0x00 => {
            ctx.write("set v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.writeChr(' ');
            ctx.writeHex(ctx.fetch_u16()); // value
        }, // mov const
        0x01 => {
            ctx.write("seti v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(" v");
            ctx.writeDec(ctx.fetch_u8()); // var
        }, // mov
        0x02 => {
            ctx.write("addi v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(" v");
            ctx.writeDec(ctx.fetch_u8()); // var
        }, // add
        0x03 => {
            ctx.write("addi v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.writeChr(' ');
            ctx.writeHex(ctx.fetch_u16()); // value
        }, // add const
        0x04 => {
            ctx.write("jsr ");
            ctx.writeHex(ctx.fetch_u16()); // address
        }, // call
        0x05 => ctx.write("return"), // ret
        0x06 => ctx.write("break"), // yield task
        0x07 => {
            ctx.write("jmp ");
            ctx.writeHex(ctx.fetch_u16()); // address
        }, // jmp
        0x08 => {
            ctx.write("setvec ");
            ctx.writeDec(ctx.fetch_u8()); // channel
            ctx.writeChr(' ');
            ctx.writeHex(ctx.fetch_u16()); // address
        }, // install task
        0x09 => {
            ctx.write("dbra v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.writeChr(' ');
            ctx.writeHex(ctx.fetch_u16()); // address
        }, // jmpIfVar
        0x0a => {
            const op2 = ctx.fetch_u8();
            ctx.write("si (v");
            ctx.writeDec(ctx.fetch_u8()); // var
            switch (op2 & 7) {
                0 => ctx.write(" == "),
                1 => ctx.write(" != "),
                2 => ctx.write(" > "),
                3 => ctx.write(" >= "),
                4 => ctx.write(" < "),
                5 => ctx.write(" <= "),
                else => ctx.write("???"),
            }
            if ((op & 0x80) != 0) {
                const a = ctx.fetch_u8();
                ctx.write("v");
                ctx.writeDec(a); // var
            } else if ((op & 0x40) != 0) {
                ctx.writeHex(ctx.fetch_u16()); // value
            } else {
                const a = ctx.fetch_u8();
                ctx.writeHex(a); // var
            }
            ctx.write(") jmp ");
            ctx.writeHex(ctx.fetch_u16()); // address
        },
        0x0b => {
            ctx.write("fade ");
            ctx.writeDec(@truncate(ctx.fetch_u16() >> 8)); // palette
        }, // setPalette
        0x0c => {
            ctx.write("vec ");
            ctx.writeDec(ctx.fetch_u8()); // start
            ctx.writeChr(',');
            ctx.writeDec(ctx.fetch_u8()); // end
            ctx.writeChr(',');
            ctx.writeDec(ctx.fetch_u8()); // type
        }, // changeTasksState
        0x0d => {
            ctx.write("setws ");
            ctx.writeDec(ctx.fetch_u8()); // screen number
        }, // selectPage
        0x0e => {
            ctx.write("clr ");
            ctx.writeDec(ctx.fetch_u8()); // screen number
            ctx.writeChr(' ');
            ctx.writeDec(ctx.fetch_u8()); // color
        }, // fillPage
        0x0f => {
            ctx.write("copy ");
            ctx.writeDec(ctx.fetch_u8()); // screen number (src)
            ctx.writeChr(' ');
            ctx.writeDec(ctx.fetch_u8()); // screen number (dst)
        }, // copyPage
        0x10 => {
            ctx.write("show ");
            ctx.writeDec(ctx.fetch_u8()); // screen number
        }, // updateDisplay
        0x11 => ctx.write("bigend"), // removeTask
        0x12 => {
            const text_num = ctx.fetch_u16();
            ctx.write("text ");
            ctx.writeChr('\"');
            ctx.write(get_str_cb(text_num, user_data)); // text
            ctx.write("\" ");
            ctx.writeHex(text_num); // text number
            ctx.write(", ");
            ctx.writeDec(ctx.fetch_u8()); // x
            ctx.write(", ");
            ctx.writeDec(ctx.fetch_u8()); // y
            ctx.write(", ");
            ctx.writeDec(ctx.fetch_u8()); // color
        }, // text "text number", x, y, color
        0x13 => {
            ctx.write("sub v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(", v");
            ctx.writeDec(ctx.fetch_u8()); // var
        }, // sub
        0x14 => {
            ctx.write("andi v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeHex(ctx.fetch_u16()); // value
        }, // and
        0x15 => {
            ctx.write("ori v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeHex(ctx.fetch_u16()); // value
        }, // or
        0x16 => {
            ctx.write("shl v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeHex(ctx.fetch_u16()); // value
        }, // shl
        0x17 => {
            ctx.write("shr v");
            ctx.writeDec(ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeHex(ctx.fetch_u16()); // value
        }, // shr
        0x18 => {
            ctx.write("play ");
            ctx.writeHex(ctx.fetch_u16()); // file num
            ctx.writeChr(' ');
            ctx.writeDec(ctx.fetch_u8()); // note
            ctx.write(", ");
            ctx.writeDec(ctx.fetch_u8()); // volume
            ctx.write(", ");
            ctx.writeDec(ctx.fetch_u8()); // channel
        }, // playSound
        0x19 => {
            ctx.write("load ");
            ctx.writeHex(ctx.fetch_u16()); // file num
        }, // updateResource
        0x1a => {
            ctx.write("song ");
            ctx.writeHex(ctx.fetch_u16()); // file num
            ctx.writeChr(' ');
            ctx.writeHex(ctx.fetch_u16()); // tempo
            ctx.writeChr(' ');
            ctx.writeDec(ctx.fetch_u8()); // pos
        }, // playMusic
        else => {
            if ((op & 0x80) != 0) {
                const off: u16 = ((@as(u16, @intCast(op)) << 8) | ctx.fetch_u8()) << 1;
                ctx.write("spr ");
                ctx.writeHex(off);
                ctx.writeChr(' ');
                ctx.writeDec(ctx.fetch_u8());
                ctx.write(" ");
                ctx.writeDec(ctx.fetch_u8());
                ctx.writeChr(' ');
            } else if ((op & 0x40) != 0) {
                const off: u16 = ((@as(u16, @intCast(ctx.fetch_u8())) << 8) | ctx.fetch_u8()) << 1;
                ctx.write("spr ");
                ctx.writeHex(off);
                ctx.writeChr(' ');
                if ((op & 0x20) == 0) {
                    if ((op & 0x10) == 0) {
                        ctx.writeHex(ctx.fetch_u16());
                    } else {
                        ctx.write("v");
                        ctx.writeDec(ctx.fetch_u8());
                    }
                } else {
                    var x: i16 = ctx.fetch_u8();
                    if ((op & 0x10) != 0) {
                        x += 0x100;
                    }
                    ctx.writeHex(@bitCast(x));
                }
                ctx.write(" ");
                var y: i16 = ctx.fetch_u8();
                if ((op & 8) == 0) {
                    if ((op & 4) == 0) {
                        y = (y << 8) | ctx.fetch_u8();
                        ctx.writeHex(@bitCast(y));
                    } else {
                        ctx.write("v");
                        ctx.writeDec(ctx.fetch_u8());
                    }
                } else {
                    ctx.writeHex(@bitCast(y));
                }
                ctx.write(" ");
                if ((op & 2) == 0) {
                    if ((op & 1) != 0) {
                        ctx.write("v");
                        ctx.writeDec(ctx.fetch_u8());
                    } else {
                        ctx.write("64");
                    }
                } else {
                    if ((op & 1) == 0) {
                        ctx.writeDec(ctx.fetch_u8());
                    } else {
                        ctx.write("64");
                    }
                }
            } else {
                ctx.write("???");
            }
        },
    }
    return pc;
}
