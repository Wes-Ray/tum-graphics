
#version 330 core

// Input variables coming from the vertex shader / Raylib
in vec2 fragTexCoord;
in vec4 fragColor;

// Uniforms passed from our Odin code
uniform float time;

// Output color
out vec4 finalColor;

void main() {
    // Create a simple pulsing effect using the sine of the time uniform
    float r = (sin(time) + 1.0) / 2.0;
    float g = (cos(time * 1.5) + 1.0) / 2.0;
    float b = 0.8;
    
    finalColor = vec4(r, g, b, 1.0);
}

