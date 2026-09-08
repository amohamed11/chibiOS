# Notes: MBR Bootloader (`src/boot.asm`)

The Master Boot Record (MBR) is the first 512-byte sector on disk, loaded by the BIOS at memory address `0x7C00` in 16-bit Real Mode.

---

## 1. Directives & Setup
* `[bits 16]`: Tells the assembler to emit 16-bit machine instructions.
* `[org 0x7c00]`: Sets the origin address. All memory labels are offset relative to `0x7C00`.
* `cli`: Clears the interrupt flag, disabling CPU hardware interrupts while configuring hardware.
* `xor ax, ax` + `mov ds/es/ss, ax`: Zeroes out data, extra, and stack segment registers so memory addresses match physical RAM without offsets.
* `mov sp, 0x7c00`: Sets the 16-bit stack pointer just below the bootloader code (grows downward safely).

---

## 2. Fast A20 Gate
* `in al, 0x92` / `or al, 2` / `out 0x92, al`:
  * Old 8086 CPUs only had 20 address lines (1 MB max). Addresses > 1 MB wrapped to 0 by default.
  * Writing `1` to bit 1 of hardware I/O port `0x92` enables address line 20, unlocking access to memory above 1 MB.

---

## 3. BIOS Disk Read
In 16-bit mode, memory is addressed as `Physical = (Segment * 16) + Offset`:
* `mov bx, 0x1000` / `mov es, bx` / `xor bx, bx`: Points destination buffer `ES:BX` to `(0x1000 * 16) + 0 = 0x10000`.
* `mov ah, 0x02`: BIOS interrupt `0x13` function "Read Sectors".
* `mov al, 16`: Number of sectors to read (16 × 512 bytes = 8 KB).
* `mov cl, 2`: Start reading at Sector 2 (Sector 1 is the MBR itself).
* `mov ch, 0` / `mov dh, 0`: Cylinder 0, Head 0.
* `int 0x13`: Triggers the BIOS disk service to copy kernel sectors into RAM at `0x10000`.

---

## 4. Switching to 32-bit Protected Mode
* `lgdt [gdt_descriptor]`: Loads the GDT size and memory location into the CPU's `GDTR` register.
* `mov eax, cr0` / `or eax, 1` / `mov cr0, eax`:
  * `CR0` (Control Register 0) controls system execution modes.
  * Bit 0 is `PE` (Protection Enable). We read `CR0` into scratchpad `EAX`, flip bit 0 to `1`, and write it back.
  * Instantly switches CPU into 32-bit Protected Mode.
* `jmp 0x08:init_32`: A **far jump**.
  * Flushes the CPU's 16-bit prefetch pipeline.
  * Loads code selector `0x08` into the `CS` (Code Segment) register.

---

## 5. Entering 32-bit Mode & Hand-off
* `[bits 32]`: Emits 32-bit machine code.
* `mov ax, 0x10` / `mov ds/es/fs/gs/ss, ax`: Loads data selector `0x10` into all data segment registers.
* `mov esp, 0x90000`: Sets the 32-bit stack pointer to safe, unused RAM.
* `jmp 0x10000`: Jumps to the kernel entry point loaded in RAM.

---

## 6. GDT (Global Descriptor Table)
Defines memory segment boundaries and access permissions:
* **Null Descriptor (0x00):** Mandatory 8 zero bytes.
* **Code Segment (0x08):** Base `0x00000000`, Limit `4 GB`, Executable, Readable.
* **Data Segment (0x10):** Base `0x00000000`, Limit `4 GB`, Writable, Readable.
* **Descriptor Pointer:** 6-byte structure (2 bytes for size - 1, 4 bytes for memory address).

---

## 7. MBR Boot Signature
* `times 510 - ($ - $$) db 0`: Zero-pads the remaining space up to 510 bytes.
* `dw 0xaa55`: Magic 2-byte signature (`0x55, 0xAA`) required by BIOS to recognize the disk as bootable.
