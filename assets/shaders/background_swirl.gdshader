shader_type canvas_item;

// Slow-moving swirling background shader
// Dark purples, reds, blues for visual interest without affecting white text contrast

uniform float speed = 0.15;

// Noise function for organic movement
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
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

// Fractal Brownian Motion for swirling patterns
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 5; i++) {
        value += amplitude * smooth_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Color palette - dark purples, reds, blues
vec3 get_color(float t) {
    // Three color stops for smooth transitions
    vec3 color1 = vec3(0.15, 0.05, 0.25);  // Dark purple
    vec3 color2 = vec3(0.2, 0.05, 0.15);   // Dark red-purple
    vec3 color3 = vec3(0.05, 0.1, 0.3);    // Dark blue

    // Create smooth color transitions
    float step1 = smoothstep(0.0, 0.5, t);
    float step2 = smoothstep(0.5, 1.0, t);

    vec3 mix1 = mix(color1, color2, step1);
    vec3 mix2 = mix(color2, color3, step2);

    return mix(mix1, mix2, step2);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * speed;

    // Create multiple layers of swirling patterns at different scales
    vec2 offset1 = vec2(cos(time * 0.3) * 0.3, sin(time * 0.2) * 0.3);
    vec2 offset2 = vec2(sin(time * 0.4) * 0.5, cos(time * 0.3) * 0.5);
    vec2 offset3 = vec2(cos(time * 0.5) * 0.2, sin(time * 0.4) * 0.2);

    // Combine noise layers for swirling effect
    float n1 = fbm(uv * 2.0 + offset1);
    float n2 = fbm(uv * 3.0 + offset2);
    float n3 = fbm(uv * 1.5 + offset3);

    // Blend noise layers
    float noise_val = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2);

    // Add some slow rotation effect
    float rotation = sin(time * 0.5 + uv.x * 2.0) * 0.5 + 0.5;
    noise_val = mix(noise_val, rotation, 0.3);

    // Get color from palette
    vec3 color = get_color(noise_val);

    // Add slight brightness variation for depth
    float brightness = 0.8 + noise_val * 0.4;
    color *= brightness;

    COLOR = vec4(color, 1.0);
}
