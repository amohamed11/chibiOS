# Notes from Creating chibiOS

chibiOS follows Philipp Oppermann's fantastic [Writing an OS in Rust](https://os.phil-opp.com/), these notes are just for documenting my learnings following that guide.

## A Freestanding Rust Binary
[Source](https://os.phil-opp.com/freestanding-rust-binary/)

- OS handle a whole lot of things that are used in the standard library such as heap allocation, standard output, etc. We can have none of that cake when creating the OS ourself, so we use `#![no_std]`.
- Rust does have a runtime, just a really minimal one. It's responsible for *small things such as setting up stack overflow guards or printing a backtrace on panic*. We have to remove those responsiblities or take them up for an OS kernel.
- Stack unwinding is the process of *removing entries* from the call stack [source](https://www.bogotobogo.com/cplusplus/stackunwinding.php). Rust utilizes *unwinding to run the destructors of all live stack variables in case of a panic*. As such we disable this unwinding and simply abort on panic.
- Since we can't use the C runtime, the default entry point `main` can't be utilized. Instead we override the entry point such that our operating system entry point is the `_start` function.
- Rust by default compiles for the host system. This leads to many a linker errors in the process of creating the binary. Instead of targeting `x86_64` system, we instead target an bare-metal ARM system `thumbv7em-none-eabihf`.
  - Bare-metal here refers to enviornment with no OS.
- Tada, we have a minimal Rust binary that compiles for a bare-metal system target.

## A Minimal Rust Kernel
[Source](https://os.phil-opp.com/minimal-rust-kernel/)

- On power on, the motherboard executes firmware code before booting up the OS kernel from disk. The two x86 firmwares are:
  - BIOS (Basic Input/Output System): Legacy standard that runs in 16-bit (real mode) before booting up the OS.
  - UEFI (Universial Extensible Firmware Interface): Modern standard that runs in 32-bit.
- When booting up the OS, BIOS transfers control to the bootloard, a 512-byte exectuable stored in the disk's begining. Larger bootloaders are split into smaller 512-byte chunks which sequentially load each other.
- For complete target system configuration we use `x86_64-chibi_os.json` to define our target [source](https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#build-std).
  - We add the option for disabling the redzone which is an optimization that allows functions *to temporarily use the 128 bytes below its stack frame* [source](https://os.phil-opp.com/red-zone/).
  <img src="https://os.phil-opp.com/red-zone/red-zone.svg" />
- Since our bare-metal target will not have a precompiled Rust compiler, the `core` library will not be available. To recompile the `core` library for our target system, we can use the `build-std` feature in cargo. Now the `core` library & its dependency `compiler_builtins` are both compiled on each build along our OS.
- To avoid writing our own memory-intrinsic function `memset`, `memcpy`, `memcmp`, we simply enable the existing implementations that come with `compiler_builtins` by adding the `compiler_builtins-mem` cargo feature.
- Lastly, to print a "Hello World" msg, we use the VGA (Video Graphics Array) text buffer. This buffer is a memory area, located at `0xb8000`, that maps to the VGA hardware which contains displayed content. Each displayed cell consists of an ASCII byte and a color byte.
- We can now use `qemu-system_86_64` to run our OS, and we'll be greeted by a "Hello World" message.

## VGA Text Mode
[Source](https://os.phil-opp.com/vga-text-mode/)

- The VGA text buffer is a 2D array with typically 25 rows and 80 columns. Each entry describes a single character on the screen, using the following 16-bit format:

Bit(s) | Value
------ | ----------------
0-7    | ASCII code point
8-11   | Foreground color
12-14  | Background color
15     | Blink

- 1st byte => the character to be printed from the [code page 437](https://en.wikipedia.org/wiki/Code_page_437) character set.
- 2nd byte => defines how the character is displayed. The first four bits define the foreground color, the next three bits the background color, and the last bit whether the character should blink.
- For the color there are 16 choices

Number | Color      | Number + Bright Bit | Bright Color
------ | ---------- | ------------------- | -------------
0x0    | Black      | 0x8                 | Dark Gray
0x1    | Blue       | 0x9                 | Light Blue
0x2    | Green      | 0xa                 | Light Green
0x3    | Cyan       | 0xb                 | Light Cyan
0x4    | Red        | 0xc                 | Light Red
0x5    | Magenta    | 0xd                 | Pink
0x6    | Brown      | 0xe                 | Yellow
0x7    | Light Gray | 0xf                 | White

- The VGA text buffer is accessible via memory-mapped I/O to the address 0xb8000. This means that reads and writes to that address don't access the RAM, but directly the text buffer on the VGA hardware
- Since `Buffer` writes are to the VGA and not the RAM, the Rust compiler may assume these writes are unnecessary. To avoid this erroneous optimization, we specify that these writes are [volatile](https://en.wikipedia.org/wiki/Volatile_(computer_programming)), which signfies that there is value change even though it may not appear so to the compiler.
- We can now write to the VGA buffer seemlessly.
