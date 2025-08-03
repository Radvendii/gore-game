const std = @import("std");

const gl = @import("zgl");
const sdl = @import("sdl");

const Obj = @import("object.zig");
const Renderer = @import("render.zig");

var window: sdl.Window = undefined;
var window_w: u32 = 1640;
var window_h: u32 = 1480;
var quit: bool = false;

var objects: []Obj = undefined;

var renderer: Renderer = undefined;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    objects = try allocator.alloc(Obj, 2);
    defer allocator.free(objects);

    objects[0] = .{ .tag = .player };
    objects[1] = .{ .tag = .enemy };

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
        "Gore Game",
        .{ .centered = {} },
        .{ .centered = {} },
        window_w,
        window_h,
        .{ .vis = .shown, .context = .opengl },
    );
    defer window.destroy();

    const context = try sdl.gl.createContext(window);
    try context.makeCurrent(window);

    // must be called after the context is current
    // SEE: https://wiki.libsdl.org/SDL2/SDL_GL_GetProcAddress
    try initGL();

    renderer = try .init();
    renderer.update_aspect_ratio(@as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h)));

    gl.viewport(0, 0, window_w, window_h);

    while (!quit) {
        pollEvents();
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(.{ .color = true });
        renderer.render(objects);
        sdl.gl.swapWindow(window);
    }
}

fn pollEvents() void {
    while (sdl.pollEvent()) |ev| switch (ev) {
        .window => |wev| switch (wev.type) {
            .size_changed => |size| {
                window_w = @intCast(size.width);
                window_h = @intCast(size.height);
                gl.viewport(0, 0, window_w, window_h);
            },
            .close => {
                quit = true;
            },
            else => {},
        },
        .key_down => |kev| switch (kev.keycode) {
            .escape => quit = true,
            else => {},
        },
        else => {},
    };
}

fn getProcAddressWrapper(comptime _: type, symbolName: [:0]const u8) ?*const anyopaque {
    return sdl.c.SDL_GL_GetProcAddress(symbolName);
}

fn initGL() !void {
    try gl.loadExtensions(void, getProcAddressWrapper);
}
