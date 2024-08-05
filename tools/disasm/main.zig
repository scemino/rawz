const std = @import("std");
const Reader = std.io.Reader;
const Writer = std.io.Writer;
const raw = @import("raw");
const GameData = raw.GameData;

pub fn Context(comptime ReaderType: type, comptime WriterType: type) type {
    return struct {
        pc: u16,
        reader: ReaderType,
        writer: WriterType,
        const Self = @This();

        const digits = "0123456789";

        pub fn init(pc: u16, reader: ReaderType, writer: WriterType) Self {
            return .{
                .pc = pc,
                .reader = reader,
                .writer = writer,
            };
        }

        pub fn fetch_u8(self: *Self) u8 {
            const v = self.reader.readByte() catch @panic("failed to read");
            self.pc += 1;
            return v;
        }

        pub fn fetch_u16(self: *Self) u16 {
            const v1: u16 = self.reader.readByte() catch @panic("failed to read");
            const v2: u16 = self.reader.readByte() catch @panic("failed to read");
            self.pc += 2;
            return (v1 << 8) | v2;
        }

        // function to output string
        pub fn write(self: *Self, str: []const u8) void {
            for (str) |c| {
                self.writer.writeByte(c) catch @panic("failed to write");
            }
        }

        fn writeHex(self: *Self, val: u16) void {
            var buf: [5]u8 = undefined;
            const buf2 = std.fmt.bufPrint(&buf, "${X:0>4}", .{val}) catch @panic("format error");
            self.write(buf2);
        }

        fn writeInt(self: *Self, comptime T: type, value: T) void {
            self.writer.print("{}", .{value}) catch @panic("format to write");
        }

        pub fn writeByte(self: *Self, val: u8) void {
            self.writer.writeByte(val) catch @panic("failed to write");
        }
    };
}

const getTextFunc = *const fn (id: u16) []const u8;

pub fn disasmOp(pc: u16, reader: anytype, writer: anytype, context: anytype) u16 {
    var ctx = Context(@TypeOf(reader), @TypeOf(writer)){ .pc = pc, .reader = reader, .writer = writer };
    const op: u8 = ctx.fetch_u8();

    // opcode name
    switch (op) {
        0x00 => {
            ctx.write("set v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.writeByte(' ');
            ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
        }, // mov const
        0x01 => {
            ctx.write("seti v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(" v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
        }, // mov
        0x02 => {
            ctx.write("addi v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(" v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
        }, // add
        0x03 => {
            ctx.write("addi v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.writeByte(' ');
            ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
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
            ctx.writeInt(u8, ctx.fetch_u8()); // channel
            ctx.writeByte(' ');
            ctx.writeHex(ctx.fetch_u16()); // address
        }, // install task
        0x09 => {
            ctx.write("dbra v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.writeByte(' ');
            ctx.writeHex(ctx.fetch_u16()); // address
        }, // jmpIfVar
        0x0a => {
            const op2 = ctx.fetch_u8();
            ctx.write("si (v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            switch (op2 & 7) {
                0 => ctx.write(" == "),
                1 => ctx.write(" != "),
                2 => ctx.write(" > "),
                3 => ctx.write(" >= "),
                4 => ctx.write(" < "),
                5 => ctx.write(" <= "),
                else => ctx.write("???"),
            }
            if ((op2 & 0x80) != 0) {
                const a = ctx.fetch_u8();
                ctx.write("v");
                ctx.writeInt(u8, a); // var
            } else if ((op2 & 0x40) != 0) {
                ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
            } else {
                ctx.writeInt(u8, ctx.fetch_u8());
            }
            ctx.write(") jmp ");
            ctx.writeHex(ctx.fetch_u16()); // address
        },
        0x0b => {
            ctx.write("fade ");
            ctx.writeInt(u8, @truncate(ctx.fetch_u16() >> 8)); // palette
        }, // setPalette
        0x0c => {
            ctx.write("vec ");
            ctx.writeInt(u8, ctx.fetch_u8()); // start
            ctx.writeByte(',');
            ctx.writeInt(u8, ctx.fetch_u8()); // end
            ctx.writeByte(',');
            ctx.writeInt(u8, ctx.fetch_u8()); // type
        }, // changeTasksState
        0x0d => {
            ctx.write("setws ");
            ctx.writeInt(u8, ctx.fetch_u8()); // screen number
        }, // selectPage
        0x0e => {
            ctx.write("clr ");
            ctx.writeInt(u8, ctx.fetch_u8()); // screen number
            ctx.writeByte(' ');
            ctx.writeInt(u8, ctx.fetch_u8()); // color
        }, // fillPage
        0x0f => {
            ctx.write("copy ");
            ctx.writeInt(u8, ctx.fetch_u8()); // screen number (src)
            ctx.writeByte(' ');
            ctx.writeInt(u8, ctx.fetch_u8()); // screen number (dst)
        }, // copyPage
        0x10 => {
            ctx.write("show ");
            ctx.writeInt(u8, ctx.fetch_u8()); // screen number
        }, // updateDisplay
        0x11 => ctx.write("bigend"), // removeTask
        0x12 => {
            const text_num = ctx.fetch_u16();
            ctx.write("text ");
            ctx.writeByte('\"');
            ctx.write(context.find(text_num)); // text
            ctx.write("\" ");
            ctx.writeHex(text_num); // text number
            ctx.write(", ");
            ctx.writeInt(u8, ctx.fetch_u8()); // x
            ctx.write(", ");
            ctx.writeInt(u8, ctx.fetch_u8()); // y
            ctx.write(", ");
            ctx.writeInt(u8, ctx.fetch_u8()); // color
        }, // text "text number", x, y, color
        0x13 => {
            ctx.write("sub v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(", v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
        }, // sub
        0x14 => {
            ctx.write("andi v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
        }, // and
        0x15 => {
            ctx.write("ori v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
        }, // or
        0x16 => {
            ctx.write("shl v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
        }, // shl
        0x17 => {
            ctx.write("shr v");
            ctx.writeInt(u8, ctx.fetch_u8()); // var
            ctx.write(", ");
            ctx.writeInt(i16, @bitCast(ctx.fetch_u16())); // value
        }, // shr
        0x18 => {
            ctx.write("play ");
            ctx.writeHex(ctx.fetch_u16()); // file num
            ctx.writeByte(' ');
            ctx.writeInt(u8, ctx.fetch_u8()); // note
            ctx.write(", ");
            ctx.writeInt(u8, ctx.fetch_u8()); // volume
            ctx.write(", ");
            ctx.writeInt(u8, ctx.fetch_u8()); // channel
        }, // playSound
        0x19 => {
            ctx.write("load ");
            ctx.writeHex(ctx.fetch_u16()); // file num
        }, // updateResource
        0x1a => {
            ctx.write("song ");
            ctx.writeHex(ctx.fetch_u16()); // file num
            ctx.writeByte(' ');
            ctx.writeInt(u16, ctx.fetch_u16()); // tempo
            ctx.writeByte(' ');
            ctx.writeInt(u8, ctx.fetch_u8()); // pos
        }, // playMusic
        else => {
            if ((op & 0x80) != 0) {
                const off: u16 = ((@as(u16, @intCast(op)) << 8) | ctx.fetch_u8()) << 1;
                ctx.write("spr ");
                ctx.writeHex(off);
                ctx.writeByte(' ');
                ctx.writeInt(u8, ctx.fetch_u8());
                ctx.write(" ");
                ctx.writeInt(u8, ctx.fetch_u8());
                ctx.writeByte(' ');
            } else if ((op & 0x40) != 0) {
                const off: u16 = ((@as(u16, @intCast(ctx.fetch_u8())) << 8) | ctx.fetch_u8()) << 1;
                ctx.write("spr ");
                ctx.writeHex(off);
                ctx.writeByte(' ');
                if ((op & 0x20) == 0) {
                    if ((op & 0x10) == 0) {
                        ctx.writeHex(ctx.fetch_u16());
                    } else {
                        ctx.write("v");
                        ctx.writeInt(u8, ctx.fetch_u8());
                    }
                } else {
                    var x: i16 = ctx.fetch_u8();
                    if ((op & 0x10) != 0) {
                        x += 0x100;
                    }
                    ctx.writeHex(@bitCast(x));
                }
                ctx.write(" ");
                if ((op & 8) == 0) {
                    if ((op & 4) == 0) {
                        const y: u16 = (@as(u16, @intCast(ctx.fetch_u8())) << 8) | ctx.fetch_u8();
                        ctx.writeHex(@bitCast(y));
                    } else {
                        ctx.write("v");
                        ctx.writeInt(u8, ctx.fetch_u8());
                    }
                } else {
                    ctx.writeInt(u8, ctx.fetch_u8());
                }
                ctx.write(" ");
                if ((op & 2) == 0) {
                    if ((op & 1) != 0) {
                        ctx.write("v");
                        ctx.writeInt(u8, ctx.fetch_u8());
                    } else {
                        ctx.write("64");
                    }
                } else {
                    if ((op & 1) == 0) {
                        ctx.writeInt(u8, ctx.fetch_u8());
                    } else {
                        ctx.write("64");
                    }
                }
            } else {
                ctx.write("???");
            }
        },
    }
    return ctx.pc;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var args_arr = std.ArrayList([]const u8).init(gpa.allocator());
    defer args_arr.deinit();

    var args = std.process.args();
    while (args.next()) |arg| {
        try args_arr.append(arg);
    }

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const strings_table = raw.Strings.init(.fr);

    // read game data
    const data_option = GameData.readData(args_arr.items[1], arena.allocator());
    if (data_option) |data| {
        var res = try raw.Res.init(.{
            .lang = .fr,
            .data = data,
        });
        // for all resources
        for (0..res.num_mem_list) |i| {
            const buf = try arena.allocator().alloc(u8, res.mem_list[i].unpacked_size);
            defer arena.allocator().free(buf);

            // read its data
            if (!res.readBank(&res.mem_list[i], buf)) continue;

            // write into file
            var name: [16]u8 = undefined;
            _ = try std.fmt.bufPrint(&name, "data{X:0>2}_{X:0>2}", .{ @intFromEnum(res.mem_list[i].type), i });
            const data_file = try std.fs.cwd().createFile(name[0..9], .{});
            defer data_file.close();
            try data_file.writeAll(buf);

            // for all script data
            if (res.mem_list[i].type != .bytecode) continue;

            // creates a file
            _ = try std.fmt.bufPrint(&name, "data{X:0>2}_{X:0>2}.disasm", .{ @intFromEnum(res.mem_list[i].type), i });
            const disasm_file = try std.fs.cwd().createFile(name[0..], .{});
            defer disasm_file.close();

            // dump its disassembly into it
            var fbs = std.io.fixedBufferStream(buf);
            var pc: u16 = 0;
            while (pc < res.mem_list[i].unpacked_size) {
                const pc_name = try std.fmt.bufPrint(&name, "{X:0>4}: ", .{pc});
                _ = try disasm_file.writer().write(pc_name);
                pc = disasmOp(pc, fbs.reader(), disasm_file.writer(), strings_table);
                try disasm_file.writer().writeByte('\n');
            }
        }
    }
}
