const std = @import("std");
const sdl = @import("sdl");
const gl = @import("zgl");
const shader = @import("shader_program.zig");
const Obj = @import("object.zig");

const Self = @This();

const Transform: type = [3][3]f32; // 3x3 matrix

fn print_transform(t: Transform) void {
    std.debug.print("⌈ {} {} {} ⌉\n", .{ t[0][0], t[0][1], t[0][2] });
    std.debug.print("⎪ {} {} {} ⎪\n", .{ t[1][0], t[1][1], t[1][2] });
    std.debug.print("⌊ {} {} {} ⌋\n", .{ t[2][0], t[2][1], t[2][2] });
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

prog: gl.Program,
aspect_ratio: f32 = 1.0,

pub fn init(context: sdl.gl.Context) !Self {
    try initGL(context);
    return .{
        .prog = try shader.init("./shaders/vert.glsl", "./shaders/frag.glsl"),
    };
}

pub fn resize(self: *Self, w: u32, h: u32) void {
    self.aspect_ratio = @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
    gl.viewport(0, 0, w, h);
}

pub fn render(self: *const Self, objects: []Obj) void {
    self.prog.use();
    const aPos = self.prog.attribLocation("aPos").?;
    const aColor = self.prog.attribLocation("aColor").?;
    const transform = self.prog.uniformLocation("transform").?;
    const vao = gl.genVertexArray();
    vao.bind();
    const vbo = gl.genBuffer();
    vbo.bind(.array_buffer);
    gl.vertexAttribPointer(aPos, 2, .float, false, 5 * @sizeOf(f32), 0);
    const ebo = gl.genBuffer();
    ebo.bind(.element_array_buffer);
    gl.vertexAttribPointer(aColor, 2, .float, false, 5 * @sizeOf(f32), 2 * @sizeOf(f32));

    const projection: Transform = .{
        .{ 1, 0, 0 },
        .{ 0, self.aspect_ratio, 0 },
        .{ 0, 0, 1 },
    };

    for (objects) |obj| {
        const data = Obj.data.get(obj.tag);
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

fn getProcAddressWrapper(comptime _: type, symbolName: [:0]const u8) ?*const anyopaque {
    return sdl.c.SDL_GL_GetProcAddress(symbolName);
}

fn initGL(context: sdl.gl.Context) !void {
    // must be called after the context is current
    // SEE: https://wiki.libsdl.org/SDL2/SDL_GL_GetProcAddress
    _ = context;
    try gl.loadExtensions(void, getProcAddressWrapper);
}
