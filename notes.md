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

