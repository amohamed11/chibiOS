const vga = @import("vga.zig");

export fn _start() callconv(.naked) noreturn {
   asm volatile (
       \\ push %ebp
       \\ jmp %[start:P]
       :
       : [start] "X" (&main),
   );
}

pub fn main() noreturn {
    var terminal = vga.Terminal{};
    terminal.setup();
    terminal.write("yare yare daze");
    while (true) {
        asm volatile ("hlt");
    }
}

