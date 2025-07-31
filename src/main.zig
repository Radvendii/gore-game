const std = @import("std");
const sdl = @import("sdl");
const gl = @import("zgl");
const shader_program = @import("shader_program.zig");

var window: sdl.Window = undefined;
var window_w: u32 = 640;
var window_h: u32 = 480;
var quit: bool = false;

const Transform: type = [2][2]f32; // 2x2 matrix

const ObjData = struct {
    // TODO: make indices point into giant list of vertices instead
    vertices: []const f32,
    indices: []const u32,
};

const obj_data: std.enums.EnumArray(Obj.Tag, ObjData) = .init(.{
    .player = .{
        .vertices = &.{
            -0.2, -0.2, 1.0, 0.0, 0.0,
            0.2,  -0.2, 1.0, 0.0, 0.0,
            0.2,  0.2,  1.0, 0.0, 0.0,
            -0.2, 0.2,  1.0, 0.0, 0.0,
        },
        .indices = &.{
            0, 1, 3,
            1, 2, 3,
        },
    },
    .enemy = .{
        .vertices = &.{
            -0.2, -0.1, 1.0, 1.0, 0.0,
            0.2,  -0.1, 1.0, 1.0, 0.0,
            0.0,  0.1,  1.0, 1.0, 0.0,
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
    t: Transform,
};

const objects: []const Obj = &.{
    .{
        .tag = .player,
        .t = .{
            .{ 1, 0 },
            .{ 0, 1 },
        },
    },
    .{
        .tag = .enemy,
        .t = .{
            .{ 1, 0 },
            .{ 0, 1 },
        },
    },
};

var prog: gl.Program = undefined;

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
    }
}

// TODO: get a real matrix type
fn m2_mul(m1: [2][2]f32, m2: [2][2]f32) [2][2]f32 {
    var ret: [2][2]f32 = .{
        .{ 0, 0 },
        .{ 0, 0 },
    };
    for (0..2) |i| {
        for (0..2) |j| {
            for (0..2) |k| {
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
    const ebo = gl.genBuffer();
    ebo.bind(.element_array_buffer);

    const aspect: f32 = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));
    const projection: Transform = .{
        .{ 1, 0 },
        .{ 0, aspect },
    };
    for (objects) |obj| {
        const data = obj_data.get(obj.tag);
        vbo.data(f32, data.vertices, .dynamic_draw);
        ebo.data(u32, data.indices, .dynamic_draw);
        gl.vertexAttribPointer(aPos, 2, .float, false, 5 * @sizeOf(f32), 0);
        gl.vertexAttribPointer(aColor, 2, .float, false, 5 * @sizeOf(f32), 2 * @sizeOf(f32));
        gl.enableVertexAttribArray(aPos);
        gl.enableVertexAttribArray(aColor);
        const t = m2_mul(projection, obj.t);
        gl.uniformMatrix2fv(transform, false, &.{t});

        gl.drawElements(.triangles, 6, .unsigned_int, 0);
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
