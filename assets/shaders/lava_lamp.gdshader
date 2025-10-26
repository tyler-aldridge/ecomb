shader_type canvas_item;

// Lava lamp shader for GrooveBar
// Rainbow when filling (use_rainbow = true)
// Grayscale when missing (use_rainbow = false)

uniform bool use_rainbow = true;
uniform float speed = 0.3;

// Simple noise function
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise
float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise for lava lamp effect
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        value += amplitude * smooth_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Rainbow gradient
vec3 rainbow(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

// Grayscale gradient
vec3 grayscale(float t) {
    float gray = 0.3 + t * 0.4; // Range from 0.3 to 0.7
    return vec3(gray);
}

void fragment() {
    vec2 uv = UV;

    // Animate the noise over time
    float time = TIME * speed;
    vec2 offset1 = vec2(time * 0.5, time * 0.3);
    vec2 offset2 = vec2(-time * 0.4, time * 0.6);

    // Create lava lamp effect with multiple noise layers
    float n1 = fbm(uv * 3.0 + offset1);
    float n2 = fbm(uv * 2.5 + offset2);
    float n = (n1 + n2) * 0.5;

    // Add some vertical flow
    n += sin(uv.y * 10.0 + time * 2.0) * 0.1;

    // Create color based on rainbow or grayscale
    vec3 color;
    if (use_rainbow) {
        color = rainbow(n);
    } else {
        color = grayscale(n);
    }

    // Add some brightness variation
    float brightness = 0.8 + n * 0.4;
    color *= brightness;

    COLOR = vec4(color, 1.0);
}
