const std = @import("std");

const gl = @import("zgl");
const sdl = @import("sdl");

const Obj = @import("object.zig");
const Renderer = @import("rendering.zig");
const Windower = @import("windowing.zig");

var quit: bool = false;

var objects: []Obj = undefined;

var renderer: Renderer = undefined;
var windower: Windower = undefined;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    objects = try allocator.alloc(Obj, 2);
    defer allocator.free(objects);

    objects[0] = .{ .tag = .player };
    objects[1] = .{ .tag = .enemy };

    windower = try .init();

    renderer = try .init(windower.context);
    renderer.resize(windower.window_w, windower.window_h);

    while (!quit) {
        pollEvents();
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(.{ .color = true });
        renderer.render(objects);
        sdl.gl.swapWindow(windower.window);
    }
}

fn pollEvents() void {
    while (sdl.pollEvent()) |ev| switch (ev) {
        .window => |wev| switch (wev.type) {
            .size_changed => |size| {
                _ = size;
                // window_w = @intCast(size.width);
                // window_h = @intCast(size.height);
                // gl.viewport(0, 0, window_w, window_h);
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
