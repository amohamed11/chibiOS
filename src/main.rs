#![no_std]
#![no_main]
#![feature(custom_test_frameworks)]
#![test_runner(chibi_os::test_runner)]
#![reexport_test_harness_main = "test_main"]

use core::panic::PanicInfo;
use chibi_os::{println, print};

#[no_mangle]
pub extern "C" fn _start() -> ! {
    println!("Hello World{}", "!");

    chibi_os::init();

    #[cfg(test)]
    test_main();

    println!("It did not crash");

    chibi_os::hlt_loop();
}

#[cfg(not(test))]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    println!("{}", info);
    chibi_os::hlt_loop();
}

#[cfg(test)]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    chibi_os::test_panic_handler(info)
}
