#![no_std]
#![no_main]

use core::panic::PanicInfo;
use chibi_os::{ QemuExitCode, exit_qemu, serial_println };

#[no_mangle]
pub extern "C" fn _start() -> ! {
    should_fail();
    serial_println!("[test did not panic]");

    exit_qemu(QemuExitCode::Failure);

    loop {}
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    serial_println!("[ok]");
    exit_qemu(QemuExitCode::Success);

    loop{}
}

fn should_fail() {
    serial_println!("should_panic::should_fail...\t");

    assert_eq!(0, 1);
}
