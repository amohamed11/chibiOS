const std = @import("std");

pub fn build(b: *std.Build) void {
    // 1. Assemble bootsector using NASM
    const nasm_cmd = b.addSystemCommand(&.{"nasm"});
    nasm_cmd.addArgs(&.{ "-f", "bin" });
    nasm_cmd.addFileArg(b.path("src/boot.asm"));
    nasm_cmd.addArg("-o");
    const boot_bin = nasm_cmd.addOutputFileArg("boot.bin");

    // 2. Compile freestanding 32-bit x86 kernel
    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = kernel_target,
            .optimize = .ReleaseSmall,
        }),
    });
    kernel.setLinkerScript(b.path("linker.ld"));

    // 3. Extract flat binary kernel.bin from kernel.elf
    const kernel_bin = kernel.addObjCopy(.{
        .format = .bin,
    });

    // 4. Combine boot.bin + kernel.bin into disk.img and pad to 65 sectors (33280 bytes)
    const img_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        "cat \"$1\" \"$2\" > \"$3\" && truncate -s 33280 \"$3\"",
        "--",
    });
    img_cmd.addFileArg(boot_bin);
    img_cmd.addFileArg(kernel_bin.getOutput());
    const disk_img = img_cmd.addOutputFileArg("disk.img");

    // 5. Install disk.img to zig-out/bin/disk.img
    const install_disk = b.addInstallBinFile(disk_img, "disk.img");
    b.getInstallStep().dependOn(&install_disk.step);

    // 6. Run step: launch QEMU with disk.img
    const run_step = b.step("run", "Run the OS in QEMU");
    const qemu_cmd = b.addSystemCommand(&.{
        "qemu-system-i386",
        "-drive",
        "format=raw,file=zig-out/bin/disk.img",
    });
    qemu_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&qemu_cmd.step);
}
