const std = @import("std");
const sdl = @import("sdl");
const gl = @import("zgl");

var window: sdl.Window = undefined;
var window_w: u32 = 640;
var window_h: u32 = 480;

pub fn main() !void {
    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();

    try sdl.gl.setAttribute(.{ .context_major_version = 3 });
    try sdl.gl.setAttribute(.{ .context_minor_version = 3 });
    try sdl.gl.setAttribute(.{ .context_profile_mask = .core });
    try sdl.gl.setAttribute(.{ .doublebuffer = true });

    window = try sdl.createWindow(
        "SDL.zig Basic Demo",
        .{ .centered = {} },
        .{ .centered = {} },
        window_w,
        window_h,
        .{ .vis = .shown, .context = .opengl },
    );
    defer window.destroy();

    sdl.delay(10 * 1000);
}
