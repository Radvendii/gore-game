const std = @import("std");

pub const Tag = enum {
    player,
    enemy,
    barrel,
};
tag: Tag,
x: f32 = 0,
y: f32 = 0,
rot: f32 = 0,
scale: f32 = 1,
velocity: struct {
    speed: f32,
    dir: f32,
} = .{ .speed = 0, .dir = 0 },

pub const Data = struct {
    // TODO: make indices point into giant list of vertices instead
    vertices: []const f32,
    indices: []const u32,
};

pub const data: std.enums.EnumArray(Tag, Data) = .init(.{
    .player = .{
        .vertices = &.{
            -0.06, -0.06, 1.0, 0.0, 0.0,
            0.06,  -0.06, 1.0, 0.0, 0.0,
            0.06,  0.06,  1.0, 0.0, 0.0,
            -0.06, 0.06,  1.0, 0.0, 0.0,
        },
        .indices = &.{
            0, 1, 3,
            1, 2, 3,
        },
    },
    .enemy = .{
        .vertices = &.{
            -0.06, -0.04, 1.0, 1.0, 0.0,
            0.06,  -0.04, 1.0, 1.0, 0.0,
            0.0,   0.04,  1.0, 1.0, 0.0,
        },
        .indices = &.{ 0, 1, 2 },
    },
    .barrel = .{
        .vertices = &.{},
        .indices = &.{},
    },
});
