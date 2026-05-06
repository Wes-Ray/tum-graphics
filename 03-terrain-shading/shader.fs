#version 300 es

// required for raylib build, can remove for VM
precision mediump float; 

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

void main() {
    finalColor = vec4(.8, .8, .8, 1.);
}
