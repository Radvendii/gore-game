const std = @import("std");

const gl = @import("zgl");
const sdl = @import("sdl");

const Obj = @import("object.zig");
const Renderer = @import("rendering.zig");
const Windower = @import("windowing.zig");
const Game = @import("game.zig");

var quit: bool = false;

var renderer: Renderer = undefined;
var windower: Windower = undefined;
var game: Game = undefined;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    windower = try .init();
    defer windower.deinit();

    game = try .init(allocator);
    defer game.deinit(allocator);

    renderer = try .init(windower.context);
    defer renderer.deinit();
    renderer.resize(windower.window_w, windower.window_h);

    while (!quit) {
        pollEvents();
        game.tick();
        renderer.clear();
        renderer.render(game.objects);
        windower.swap();
    }
}

fn pollEvents() void {
    while (sdl.pollEvent()) |ev| switch (ev) {
        .window => |wev| switch (wev.type) {
            .size_changed => |size| {
                const w: u32 = @intCast(size.width);
                const h: u32 = @intCast(size.height);
                windower.window_w = w;
                windower.window_h = h;
                renderer.resize(w, h);
            },
            .close => {
                quit = true;
            },
            else => {},
        },
        .mouse_motion => |mev| {
            const mx: f32 = (@as(f32, @floatFromInt(mev.x)) / @as(f32, @floatFromInt(windower.window_w)) * 2 - 1);
            const my: f32 = -(@as(f32, @floatFromInt(mev.y)) / @as(f32, @floatFromInt(windower.window_h)) * 2 - 1);
            const px: f32 = game.objects[game.pi].x;
            const py: f32 = game.objects[game.pi].y;
            game.objects[game.pi].rot = std.math.atan2(my - py, mx - px);
        },
        .key_down => |kev| switch (kev.keycode) {
            .escape => quit = true,
            .w => game.objects[game.pi].velocity = .{
                .speed = 1.0,
                .dir = game.objects[game.pi].rot,
            },
            else => {},
        },
        .key_up => |kev| switch (kev.keycode) {
            .w => game.objects[game.pi].velocity.speed = 0,
            else => {},
        },
        else => {},
    };
}
