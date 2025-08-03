#version 330 core
#extension GL_ARB_explicit_uniform_location : require
layout(location = 0) in vec2 aPos;
layout(location = 1) in vec3 aColor;

layout(location = 2) uniform mat3x3 transform;

out vec3 color;

void main() {
    color = aColor;

    vec3 transformed = transform * vec3(aPos, 1.0);
    // normalize
    // transformed.xy /= transformed.z;
    gl_Position = vec4(transformed.xy, 0.0, 1.0);
}
