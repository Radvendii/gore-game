const std = @import("std");
const sdl = @import("sdl");
const gl = @import("zgl");
const shader = @import("shader_program.zig");
const Obj = @import("object.zig");

const log = std.log.scoped(.rendering);

const Self = @This();

prog: gl.Program,
aspect_ratio: f32 = 1.0,

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

pub fn init(context: sdl.gl.Context) !Self {
    try initGL(context);
    return .{
        .prog = try shader.init("./shaders/vert.glsl", "./shaders/frag.glsl"),
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn resize(self: *Self, w: u32, h: u32) void {
    self.aspect_ratio = @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
    gl.viewport(0, 0, w, h);
}
pub fn clear(_: *const Self) void {
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(.{ .color = true });
}

pub fn render(self: *const Self, objects: []Obj) void {
    self.prog.use();
    const transform = self.prog.uniformLocation("transform").?;
    const vao = gl.genVertexArray();
    vao.bind();
    const vbo = gl.genBuffer();
    vbo.bind(.array_buffer);
    vertexAttribPointersFromLayout(self.prog, Obj.Vertex);
    const ebo = gl.genBuffer();
    ebo.bind(.element_array_buffer);

    const projection: Transform = .{
        .{ 1, 0, 0 },
        .{ 0, self.aspect_ratio, 0 },
        .{ 0, 0, 1 },
    };

    for (objects) |obj| {
        const data = Obj.data.get(obj.tag);
        vbo.data(Obj.Vertex, data.vertices, .dynamic_draw);
        ebo.data(u32, data.indices, .dynamic_draw);

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
        const t = t_mul(projection, t_mul(trans_t, rot_t));
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

inline fn vertexAttribPointersFromLayout(prog: gl.Program, layout: type) void {
    const normalized = false;
    if (@typeInfo(layout) != .@"struct")
        @compileError(std.fmt.comptimePrint("Attrib layout must be a struct, found '{s}'", .{@typeName(layout)}));

    inline for (@typeInfo(layout).@"struct".fields) |field| {
        if (@typeInfo(field.type) != .array)
            @compileError(std.fmt.comptimePrint("Attrib must be an array, '{s}' is a '{}'", .{ field.name, @typeName(field.type) }));

        const len = @typeInfo(field.type).array.len;

        if (len > 4) @compileError(std.fmt.comptimePrint("Attrib size cannot be more than 4. '{s}' has len {}", .{ field.name, len }));

        const child = std.meta.Child(field.type);
        // TODO: figure out how these should actually be used
        const attrib_type: gl.Type = ty: switch (@typeInfo(child)) {
            .float => |f| {
                switch (f.bits) {
                    16 => break :ty .half_float,
                    32 => break :ty .float,
                    64 => break :ty .double,
                    else => {},
                }
            },
            else => @compileError(std.fmt.comptimePrint("Attrib types are highly restricted. '{s}' has disallowed type '{s}'", .{ field.name, @typeName(child) })),
        };

        if (prog.attribLocation(field.name)) |loc| {
            gl.vertexAttribPointer(
                loc,
                len,
                attrib_type,
                normalized,
                @sizeOf(layout),
                @offsetOf(layout, field.name),
            );
            gl.enableVertexAttribArray(loc);
        } else {
            log.err("vertex attribute '{s}' not found in shader program", .{field.name});
        }
    }
}
