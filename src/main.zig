const vga = @import("vga.zig");

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ push %ebp
        \\ jmp %[start:P]
        :
        : [start] "X" (&main),
    );
}

pub fn main() !void {
    var terminal = vga.Terminal{};
    terminal.setup();
    terminal.write("yare yare daze");
}
