# Extensible x86 OS Blueprint

A modular 32-bit x86 operating system written in Zig.
- **Core Goal:** Boot up, provide an extensible shell interface via keyboard interrupts and VGA display. Initial test command: respond with `"World"` when `"Hello"` is entered, structured for adding further commands and drivers.
- **Architecture:** 32-bit x86 (`i386`)
- **Bootloader:** Custom 512-byte MBR bootsector (supports multi-sector kernel loading up to 32 KB+)
- **Display:** Modular VGA Text Mode Driver (`0xB8000`)
- **Input:** Interrupt-Driven (8259 PIC + IDT + IRQ1) with an event queue

---

## Hardware Structures: GDT & IDT

### 1. Global Descriptor Table (GDT)
Translates logical segment selectors into memory regions and sets access permissions for 32-bit Protected Mode.
- Segments: Null descriptor (required), 32-bit Code Segment (Exec/Read, 4 GB flat), 32-bit Data Segment (Read/Write, 4 GB flat).

### 2. Interrupt Descriptor Table (IDT)
Maps hardware interrupt lines and CPU exceptions to their corresponding Interrupt Service Routine (ISR) addresses.
- Remaps IRQ1 (Keyboard) through the 8259 PIC to vector `0x21`.
- ISR stub saves CPU state (`pusha`), invokes the driver, signals End-Of-Interrupt (`EOI = 0x20`), restores registers (`popa`), and resumes execution (`iret`).
- Designed to allow registering future hardware interrupts (timer, serial) and CPU exceptions.

---

## Implementation Steps (Bottom-Up)

### Step 1: MBR Bootsector (`src/boot.asm`)
- **Role:** First 512-byte sector loaded by BIOS at `0x7C00` in 16-bit Real Mode.
- **Actions:**
  1. Load kernel sectors from disk into RAM at `0x10000` via BIOS `int 0x13` (reads 64 sectors / 32 KB to provide kernel growth headroom).
  2. Enable Fast A20 Gate (I/O Port `0x92`) to access memory above 1MB.
  3. Load GDT via `lgdt`.
  4. Enable Protected Mode (set bit 0 of `CR0`).
  5. Execute far jump (`jmp 0x08:init_32`) to flush CPU pipeline into 32-bit mode.
  6. Set data segments (`DS`, `SS`, `ES`, `FS`, `GS` = `0x10`), initialize stack (`ESP = 0x90000`), and jump to `0x10000`.
  7. Pad to 510 bytes, finish with signature `0x55, 0xAA`.

### Step 2: Zig Freestanding Setup, Linker Script & Build Pipeline
- **Target:** `x86-freestanding-none` (no OS syscalls, no C runtime, no standard `main`).
- **Linker Script (`linker.ld`):**
  - Sets kernel base at `0x10000`.
  - Aligns sections (`ALIGN(4)`).
  - Exports symbols `__bss_start`, `__bss_end`, and `_kernel_end` for memory zeroing and future heap allocation.
  - Discards compiler metadata (`.comment`, `.note.*`, `.eh_frame`).
- **Build System (`build.zig`):**
  - Assembles `src/boot.asm` with `nasm -f bin` -> `boot.bin`.
  - Compiles Zig kernel with `linker.ld` -> `kernel.elf`.
  - Extracts raw machine code via `zig objcopy -O binary` -> `kernel.bin`.
  - Merges `boot.bin` + `kernel.bin` -> `disk.img`.
  - `zig build run`: Launches `qemu-system-i386 -drive format=raw,file=...`.

### Step 3: VGA Text Mode Driver (`src/vga.zig`)
- **Buffer:** Physical memory-mapped address `0xB8000` (80 columns × 25 rows).
- **Cell Structure (2 bytes):**
  - Byte 0: ASCII character (`'H'`).
  - Byte 1: Color attribute (foreground/background, e.g. `0x0F` = White on Black).
- **Features:**
  - Cursor tracking `(row, col)`.
  - `putChar(c: u8)`: Handles printable characters and escape characters (`\n`, `\r`, `\b` for backspace).
  - `print(str: []const u8)`: String printing.
  - `clear()`: Clears screen buffer.
  - `scroll()`: Scrolls buffer upward when reaching bottom row.

### Step 4: Interrupt Controller & IDT (`src/idt.zig`)
- **Port I/O:** Inline assembly helpers for `inb` and `outb`.
- **8259 PIC Remap:**
  - Shift IRQs 0–7 from default vectors `0x08`–`0x0F` to `0x20`–`0x27` to avoid colliding with CPU exceptions.
  - Keyboard IRQ1 becomes vector `0x21`.
- **IDT Configuration:**
  - Array of 256 entries (8 bytes each).
  - Extensible registration function `setGate(vector, handler, flags)`.
  - Register vector `0x21` with keyboard ISR assembly stub.
  - Load table with `lidt` instruction.
  - Enable interrupts via `sti`.

### Step 5: Keyboard Driver (`src/keyboard.zig`)
- **ISR Stub:**
  - Save general registers (`pusha`).
  - Call Zig keyboard interrupt handler.
  - Send End-Of-Interrupt (`EOI = 0x20`) to PIC port `0x20`.
  - Restore general registers (`popa`) and return with `iret`.
- **Decoding & Buffering:**
  - Read scancode from port `0x60`.
  - Filter key releases (ignore break codes where bit 7 is set).
  - Map Scancode Set 1 make codes to ASCII characters.
  - Push character into a thread-safe ring buffer for consumer polling.

### Step 6: Kernel Main & Extensible Shell (`src/main.zig` / `src/shell.zig`)
- **Initialization:**
  - Zero out `.bss` section using linker symbols (`__bss_start` to `__bss_end`).
  - Initialize VGA driver, clear screen, display welcome banner and prompt (`> `).
  - Initialize IDT, remap PIC, register IRQ1, enable CPU interrupts (`sti`).
- **Shell Loop:**
  - Wait for keyboard events (`hlt` loop).
  - Support line editing (typing, backspace `\b`).
  - On `\n` (Enter):
    - Dispatch command against a command registry (e.g., `"hello"` -> `"World\n"`, `"clear"` -> clear screen, `"help"` -> list commands).
    - Print new prompt (`> `).
