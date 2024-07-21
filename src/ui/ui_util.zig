const std = @import("std");
const ig = @import("cimgui");

// draw an 16-bit hex text input field
pub fn ui_util_input_u16(label: [:0]const u8, value: u16) u16 {
    var val = value;
    var buf: [5:0]u8 = undefined;
    inline for (0..4) |i| {
        buf[i] = "0123456789ABCDEF"[val >> ((3 - i) * 4) & 0xF];
    }
    buf[4] = 0;
    const flags = ig.ImGuiInputTextFlags_CharsHexadecimal | ig.ImGuiInputTextFlags_CharsUppercase | ig.ImGuiInputTextFlags_EnterReturnsTrue;
    ig.igPushItemWidth(38);
    defer ig.igPopItemWidth();
    if (ig.igInputText(label, &buf, buf.len, flags, null, null)) {
        val = std.fmt.parseInt(u16, &buf, 16) catch return val;
    }
    return val;
}
