# Notes from Creating chibiOS

chibiOS follows Philipp Oppermann's fantastic [Writing an OS in Rust](https://os.phil-opp.com/), these notes are just for documenting my learnings following that guide.

## A Freestanding Rust Binary

- OS handle a whole lot of things that are used in the standard library such as heap allocation, standard output, etc. We can have none of that cake when creating the OS ourself, so we use `#![no_std]`.
- Rust does have a runtime, just a really minimal one. It's responsible for *small things such as setting up stack overflow guards or printing a backtrace on panic*. We have to remove those responsiblities or take them up for an OS kernel.
- Stack unwinding is the process of *removing entries* from the call stack [source](https://www.bogotobogo.com/cplusplus/stackunwinding.php). Rust utilizes *unwinding to run the destructors of all live stack variables in case of a panic*. As such we disable this unwinding and simply abort on panic.
- Since we can't use the C runtime, the default entry point `main` can't be utilized. Instead we override the entry point such that our operating system entry point is the `_start` function.
- Rust by default compiles for the host system. This leads to many a linker errors in the process of creating the binary. Instead of targeting `x86_64` system, we instead target an bare-metal ARM system `thumbv7em-none-eabihf`.
  - Bare-metal here refers to enviornment with no OS.
- Tada, we have a minimal Rust binary that compiles for a bare-metal system target.

## A Minimal Rust Kernel

- On power on, the motherboard executes firmware code before booting up the OS kernel from disk. The two x86 firmwares are:
  - BIOS (Basic Input/Output System): Legacy standard that runs in 16-bit (real mode) before booting up the OS.
  - UEFI (Universial Extensible Firmware Interface): Modern standard that runs in 32-bit.
- When booting up the OS, BIOS transfers control to the bootloard, a 512-byte exectuable stored in the disk's begining. Larger bootloaders are split into smaller 512-byte chunks which sequentially load each other.
- For complete target system configuration we use `x86_64-chibi_os.json` to define our target [source](https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#build-std).
  - We add the option for disabling the redzone which is an optimization that allows functions *to temporarily use the 128 bytes below its stack frame* [source](https://os.phil-opp.com/red-zone/).
  <img src="https://os.phil-opp.com/red-zone/red-zone.svg" />
- Since our bare-metal target will not have a precompiled Rust compiler, the `core` library will not be available. To recompile the `core` library for our target system, we can use the `build-std` feature in cargo. Now the `core` library & its dependency `compiler_builtins` are both compiled on each build along our OS.
- Lastly to avoid writing our own memory-intrinsic function `memset`, `memcpy`, `memcmp`, we simply enable the existing implementations that come with `compiler_builtins` by adding the `compiler_builtins-mem` cargo feature.
