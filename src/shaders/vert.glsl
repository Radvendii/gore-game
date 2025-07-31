#version 330 core
#extension GL_ARB_explicit_uniform_location : require
layout (location=0) in vec2 aPos;
layout (location=1) in vec3 aColor;

layout (location=2) uniform mat2x2 transform;

out vec3 color;

void main() {
    vec2 transformed = transform * aPos;
    color = aColor;
    gl_Position = vec4(transformed, 0.0, 1.0);
}
