shader_type canvas_item;

// Vaporwave-style swirling background shader
// Bright shifting colors: pinks, purples, cyans, magentas

uniform float speed = 0.5;  // Faster movement

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

// Vaporwave color palette - bright pinks, purples, cyans
vec3 get_vaporwave_color(float t) {
    // Vaporwave colors cycling through the spectrum
    vec3 color1 = vec3(0.3, 0.15, 0.5);   // Deep purple
    vec3 color2 = vec3(0.5, 0.1, 0.4);    // Magenta
    vec3 color3 = vec3(0.1, 0.3, 0.6);    // Cyan-blue
    vec3 color4 = vec3(0.4, 0.15, 0.5);   // Purple-pink

    // Cycle through colors
    float pos = fract(t + TIME * 0.05) * 4.0;

    if (pos < 1.0) {
        return mix(color1, color2, pos);
    } else if (pos < 2.0) {
        return mix(color2, color3, pos - 1.0);
    } else if (pos < 3.0) {
        return mix(color3, color4, pos - 2.0);
    } else {
        return mix(color4, color1, pos - 3.0);
    }
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * speed;

    // Create multiple layers of swirling patterns at different scales
    vec2 offset1 = vec2(cos(time * 0.5) * 0.3, sin(time * 0.4) * 0.3);
    vec2 offset2 = vec2(sin(time * 0.6) * 0.5, cos(time * 0.5) * 0.5);
    vec2 offset3 = vec2(cos(time * 0.7) * 0.2, sin(time * 0.6) * 0.2);

    // Combine noise layers for swirling effect
    float n1 = fbm(uv * 2.0 + offset1);
    float n2 = fbm(uv * 3.0 + offset2);
    float n3 = fbm(uv * 1.5 + offset3);

    // Blend noise layers
    float noise_val = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2);

    // Add spiral rotation for more movement
    float rotation = atan(uv.y - 0.5, uv.x - 0.5) / 6.28318;
    noise_val = mix(noise_val, rotation + time * 0.1, 0.4);

    // Get vaporwave colors
    vec3 color = get_vaporwave_color(noise_val);

    // Add brightness variation for depth (brighter overall)
    float brightness = 1.0 + noise_val * 0.3;
    color *= brightness;

    COLOR = vec4(color, 1.0);
}
