# Notes from Creating chibiOS

chibiOS follows Philipp Oppermann's fantastic [Writing an OS in Rust](https://os.phil-opp.com/), as such these notes are merely my summarization of said guide. Tangent sections are from my further exploration of certain concepts.

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

### Tangent: Stacks in Operating Systems

- A stack is used to add, track, and carry out OS operations. The core of `push` & `pop` are used to add/remove values from the stack itself (and registers as well). Other calls can use these values that are on the stack for their operations.
- The primary stack used to run operations for the OS is called the *run-time stack* and is stored on the primary memory.
- Many operations omit arguments and can instead just utilize the immediate previously pushed values for carrying out desired operation. 
- A great demonstration of stack machines [source](https://en.wikipedia.org/wiki/Stack_machine):

```
                 # stack contents (leftmost = top = most recent):
 push A          #           A
 push B          #     B     A
 push C          # C   B     A
 subtract        #     B-C   A
 multiply        #           A*(B-C)
 push D          #     D     A*(B-C)
 push E          # E   D     A*(B-C)
 add             #     D+E   A*(B-C)
 add             #           A*(B-C)+(D+E)
```

- Related fact, typically a stack frame diagram is represented in reverse, so the top of the diagram is the bottom of the stack, the bottom is the top (why is this?).

## CPU Exceptions

- Exceptions signal that something is wrong with the current instruction.  
- When an exception occurs, the CPU **interrupts** its current work and immediately calls a specific exception handler function.
- Few of x86's 20 exception types are:
  - Page Fault: Occurs on illegal memory accesses.  
  - Invalid Opcode: Occurs when the current instruction is invalid.
  - General Protection Fault: This is the exception with the broadest range of causes. It occurs on various kinds of access violations such as trying to execute a privileged instruction in user level code or writing reserved fields in configuration registers.
  - Double Fault: Occurs if another exception occurs while calling the exception handler, orif there is no handler function registered for an exception.
  - Triple Fault: If an exception occurs while the CPU tries to call the double fault handler function, it issues a fatal triple fault. We can't catch or handle a triple fault. Most processors react by resetting themselves and rebooting the operating system. *It's faults all the way down baby*.
- To handle exceptions properly, we setup an Interrupt Descriptor Table (IDT). In this table we can specify a handler function for each CPU exception. The processor uses this table directly, so we need to follow a predefined format.

Type| Name                     | Description
----|--------------------------|-----------------------------------
u16 | Function Pointer [0:15]  | The lower bits of the pointer to the handler function.
u16 | GDT selector             | Selector of a code segment in the [global descriptor table](https://en.wikipedia.org/wiki/Global_Descriptor_Table).
u16 | Options                  | see [here](https://wiki.osdev.org/Interrupt_Descriptor_Table#Gate_Descriptor_2)
u16 | Function Pointer [16:31] | The middle bits of the pointer to the handler function.
u32 | Function Pointer [32:63] | The remaining bits of the pointer to the handler function.
u32 | Reserved     

- Nah fam, can't summarize this one. Read on from [here](https://os.phil-opp.com/cpu-exceptions/#the-interrupt-calling-convention)
- The Interrupt stack frame (which differs from typical stack frames)

<img src="https://os.phil-opp.com/cpu-exceptions/exception-stack-frame.svg" />

- 

### Tangent: Registers

- Registers accesible locations in a processor that is used to store small data very quickly. Registers have specific hardware functions and may be read/write only.
- In short, registers carry out very specific instructions with given values & addresses at the atomic (OS speaking) level. These instructions serve as the building blocks for greater abstractions.
- There are various types of general registers, with each serving different purpose depending on the instruction set. The number of registers also vary by processor.
- The most essential types (a larger list ([here](https://en.wikipedia.org/wiki/Processor_register#Types))) of registers are *address* and *data* registers. The first serves to hold addresses to the primary memory used by an instruction (such as a pointer to the run-time stack). The latter serves to hold the values (integers, floats, characters) used by an instructions.

## Double Faults

- Double faults can occur for multiple reasons. Typically it occurs following a series of two
  exceptions going unhandled, such as a page fault leading to another page fault, divide by zero
  fault followed by general-protection fault, etc.
- A corrupted stack during an expection handler (say a failed page fault handling), can lead to
  failed double fault, thus resulting in a triple fault. We want to avoid this as much as possible.
- We can define as set of known valid stack using x86\_64 ability to switch to a predefine stack
  from the *Interrupt Stack Table* (IST). The IST can hold pointers to 7 good stacks. 
- The IST is part of a struture called *Task State Segment* (TSS), alongside a Privilege Stack
  Table that is used to privilege level changes during exception handling.
- To inform our CPU to use our TSS (which has our IST), we add it to the *Global Descriptor Table*

## Handling Interrupts
```
                                    ____________             _____
               Timer ------------> |            |           |     |
               Keyboard ---------> | Interrupt  |---------> | CPU |
               Other Hardware ---> | Controller |           |_____|
               Etc. -------------> |____________|

```

- Interrupts are how the CPU is notified by atthaced hardware devices of events.
- Since the 0-15 interrupt range is in-use for CPU execptions, we will use the 32-47 range for our
  selected PIC (Programmable Interrupt Controller), the Intel 8259.
