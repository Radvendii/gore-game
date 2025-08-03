const std = @import("std");
const sdl = @import("sdl");

const Self = @This();

window: sdl.Window,
context: sdl.gl.Context,
window_w: u32 = 1640,
window_h: u32 = 1480,

pub fn init() !Self {
    var self: Self = .{
        .window = undefined,
        .context = undefined,
    };

    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    errdefer sdl.quit();

    try sdl.gl.setAttribute(.{ .context_major_version = 3 });
    try sdl.gl.setAttribute(.{ .context_minor_version = 3 });
    try sdl.gl.setAttribute(.{ .context_profile_mask = .core });
    try sdl.gl.setAttribute(.{ .doublebuffer = true });

    self.window = try sdl.createWindow(
        "Gore Game",
        .{ .centered = {} },
        .{ .centered = {} },
        self.window_w,
        self.window_h,
        .{ .vis = .shown, .context = .opengl },
    );
    errdefer self.window.destroy();

    self.context = try sdl.gl.createContext(self.window);

    // NOTE: this must get called before we initialize rendering
    try self.context.makeCurrent(self.window);

    return self;
}

pub fn deinit(self: Self) void {
    self.window.destroy();
    sdl.quit();
}
