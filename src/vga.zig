const VGA_WIDTH: u8 = 80;
const VGA_HEIGHT: u8 = 25;
const VGA_MEMORY = 0xB8000;

pub const VGA_Color = enum(u8) {
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGrey,
    DarkGrey,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    Pink,
    Yellow,
    White,
};

fn getColorByte(fg: VGA_Color, bg: VGA_Color) u8 {
    return @as(u16, (@intFromEnum(fg) | @intFromEnum(bg) << 4));
}

fn getScreenEntry(char: u8, colorByte: u8) u16 {
    return @as(u16, char) | (@as(u16, colorByte) << 8);
}

pub const Terminal = struct {
    row: usize = 0,
    column: usize = 0,
    color: u8 = getColorByte(VGA_Color.White, VGA_Color.Cyan),
    buffer: [*]volatile u16 = @ptrFromInt(VGA_MEMORY),

    pub fn setup(self: *Terminal) void {
        for (0..VGA_HEIGHT) |y| {
            for (0..VGA_WIDTH) |x| {
                const idx = y * VGA_WIDTH + x;
                self.buffer[idx] = getScreenEntry(' ', self.color);
            }
        }
    }

    pub fn putEntryAt(self: *Terminal, char: u8, color: u8, x: usize, y: usize) void {
        const idx = y * VGA_WIDTH + x;
        self.buffer[idx] = getScreenEntry(char, color);
    }

    pub fn putChar(self: *Terminal, char: u8) void {
        self.putEntryAt(char, self.color, self.column, self.row);
        self.column += 1;
        if (self.column == VGA_WIDTH) {
            self.column = 0;
            self.row += 1;
            if (self.row == VGA_HEIGHT) {
                // Reached top right, rest to bottom left
                self.row = 0;
            }
        }
    }

    pub fn write(self: *Terminal, data: []const u8) void {
        for (data) |c| {
            self.putChar(c);
        }
    }
};

