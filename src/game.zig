const std = @import("std");
const Obj = @import("object.zig");

const Self = @This();

const SPEED: f32 = 0.001;

objects: []Obj,
pi: u32,

pub fn init(allocator: std.mem.Allocator) !Self {
    const self: Self = .{
        .objects = try allocator.alloc(Obj, 2),
        .pi = 0,
    };

    errdefer allocator.free(self.objects);

    self.objects[self.pi] = .{ .tag = .player };
    self.objects[1] = .{ .tag = .enemy };
    return self;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.objects);
}

pub fn tick(self: *Self) void {
    for (self.objects) |*obj| {
        obj.x += SPEED * obj.velocity.speed * std.math.cos(obj.velocity.dir);
        obj.y += SPEED * obj.velocity.speed * std.math.sin(obj.velocity.dir);
    }
}
