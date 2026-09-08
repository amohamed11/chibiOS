[bits 16]
[org 0x7c00]

start:
    ; 1. Disable interrupts and initialize segment registers
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; 2. Enable Fast A20 gate
    in al, 0x92
    or al, 2
    out 0x92, al

    ; 3. Read kernel sectors from disk into RAM at 0x10000
    mov bx, 0x1000      ; Segment 0x1000 * 16 = physical 0x10000
    mov es, bx
    xor bx, bx          ; Offset 0 -> ES:BX = 0x1000:0x0000

    mov ah, 0x02        ; BIOS read sector function
    mov al, 64          ; Read 64 sectors (32 KB headroom)
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Sector 2 (Sector 1 is MBR)
    mov dh, 0           ; Head 0
    ; DL is preserved from BIOS boot drive
    int 0x13

    ; 4. Load GDT
    lgdt [gdt_descriptor]

    ; 5. Switch to 32-bit Protected Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; 6. Far jump to flush CPU pipeline into 32-bit mode
    jmp 0x08:init_32

[bits 32]
init_32:
    ; 7. Set 32-bit segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; 8. Set up stack pointer and jump to Zig kernel
    mov esp, 0x90000
    jmp 0x10000

; --- Global Descriptor Table (GDT) ---
gdt_start:
    ; Null Descriptor (8 bytes)
    dd 0x0
    dd 0x0

    ; 32-bit Code Segment Descriptor (Selector 0x08)
    dw 0xffff           ; Limit (bits 0-15)
    dw 0x0000           ; Base (bits 0-15)
    db 0x00             ; Base (bits 16-23)
    db 10011010b        ; Access: Present, Ring 0, Executable, Readable
    db 11001111b        ; Flags: 4KB gran, 32-bit + Limit (bits 16-19)
    db 0x00             ; Base (bits 24-31)

    ; 32-bit Data Segment Descriptor (Selector 0x10)
    dw 0xffff           ; Limit (bits 0-15)
    dw 0x0000           ; Base (bits 0-15)
    db 0x00             ; Base (bits 16-23)
    db 10010010b        ; Access: Present, Ring 0, Writable
    db 11001111b        ; Flags: 4KB gran, 32-bit + Limit (bits 16-19)
    db 0x00             ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; --- Boot Signature ---
times 510 - ($ - $$) db 0
dw 0xaa55
