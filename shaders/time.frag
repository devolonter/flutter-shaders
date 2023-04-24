out vec4 fragColor;

uniform float uTime;
uniform float uOffset;

void main() {
    fragColor = vec4(1.0, 0.0, 1.0, 1.0) * fract(uTime - uOffset);
}