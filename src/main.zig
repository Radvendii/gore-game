const std = @import("std");
const sdl = @import("sdl");
const gl = @import("zgl");
const shader_program = @import("shader_program.zig");

var window: sdl.Window = undefined;
var window_w: u32 = 1640;
var window_h: u32 = 1480;
var quit: bool = false;

const Transform: type = [3][3]f32; // 2x2 matrix

fn print_transform(t: Transform) void {
    std.debug.print("⌈ {} {} {} ⌉\n", .{ t[0][0], t[0][1], t[0][2] });
    std.debug.print("⎪ {} {} {} ⎪\n", .{ t[1][0], t[1][1], t[1][2] });
    std.debug.print("⌊ {} {} {} ⌋\n", .{ t[2][0], t[2][1], t[2][2] });
}

const ObjData = struct {
    // TODO: make indices point into giant list of vertices instead
    vertices: []const f32,
    indices: []const u32,
};

const obj_data: std.enums.EnumArray(Obj.Tag, ObjData) = .init(.{
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

const Obj = struct {
    const Tag = enum {
        player,
        enemy,
        barrel,
    };
    tag: Tag,
    x: f32 = 0,
    y: f32 = 0,
    rot: f32 = 0,
    scale: f32 = 1,
};

var objects: []Obj = undefined;

var prog: gl.Program = undefined;

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

    prog = try shader_program.init("./shaders/vert.glsl", "./shaders/frag.glsl");
    gl.viewport(0, 0, window_w, window_h);

    while (!quit) {
        pollEvents();
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(.{ .color = true });
        render();
        sdl.gl.swapWindow(window);
        objects[0].x += 0.002;
    }
}

// TODO: get a real matrix type
fn t_mul(m1: Transform, m2: Transform) Transform {
    var ret: Transform = .{
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    };
    for (0..3) |i| {
        for (0..3) |j| {
            for (0..3) |k| {
                ret[i][j] += m1[i][k] * m2[k][j];
            }
        }
    }
    return ret;
}

fn render() void {
    prog.use();
    const aPos = prog.attribLocation("aPos").?;
    const aColor = prog.attribLocation("aColor").?;
    const transform = prog.uniformLocation("transform").?;
    const vao = gl.genVertexArray();
    vao.bind();
    const vbo = gl.genBuffer();
    vbo.bind(.array_buffer);
    gl.vertexAttribPointer(aPos, 2, .float, false, 5 * @sizeOf(f32), 0);
    const ebo = gl.genBuffer();
    ebo.bind(.element_array_buffer);
    gl.vertexAttribPointer(aColor, 2, .float, false, 5 * @sizeOf(f32), 2 * @sizeOf(f32));

    const aspect: f32 = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));
    const projection: Transform = .{
        .{ 1, 0, 0 },
        .{ 0, aspect, 0 },
        .{ 0, 0, 1 },
    };
    for (objects) |obj| {
        const data = obj_data.get(obj.tag);
        vbo.data(f32, data.vertices, .dynamic_draw);
        ebo.data(u32, data.indices, .dynamic_draw);
        gl.enableVertexAttribArray(aPos);
        gl.enableVertexAttribArray(aColor);

        const rot_t: Transform = .{
            .{ std.math.cos(obj.rot), -std.math.sin(obj.rot), 0 },
            .{ std.math.sin(obj.rot), std.math.cos(obj.rot), 0 },
            .{ 0, 0, 1 },
        };
        const trans_t: Transform = .{
            .{ 1, 0, obj.x },
            .{ 0, 1, obj.y },
            .{ 0, 0, 1 },
        };
        const t = t_mul(projection, t_mul(rot_t, trans_t));
        gl.uniformMatrix3fv(transform, true, &.{t});

        gl.drawElements(.triangles, data.indices.len, .unsigned_int, 0);
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
