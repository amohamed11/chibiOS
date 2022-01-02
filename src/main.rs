#![no_std]
#![no_main]

use core::panic::PanicInfo;

mod vga_buffer;

#[no_mangle] // maintain function name in compilation
pub extern "C" fn _start() -> ! {
    // entry point for chibiOS
    println!("Hello World{}", "!");

    loop {}
}

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    println!("{}", info);

    loop {}
}
