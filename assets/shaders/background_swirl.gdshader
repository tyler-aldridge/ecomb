shader_type canvas_item;

// Vaporwave-style swirling background shader
// Bright shifting colors: pinks, purples, cyans, magentas
// Enhanced with moving shapes and distortion

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

    for (int i = 0; i < 8; i++) {
        value += amplitude * smooth_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Circle SDF for shape distortion
float circle_sdf(vec2 p, vec2 center, float radius) {
    return length(p - center) - radius;
}

// Vaporwave color palette - bright pinks, purples, cyans
vec3 get_vaporwave_color(float t) {
    // Vaporwave colors cycling through the spectrum
    vec3 color1 = vec3(0.3, 0.15, 0.5);   // Deep purple
    vec3 color2 = vec3(0.5, 0.1, 0.4);    // Magenta
    vec3 color3 = vec3(0.1, 0.3, 0.6);    // Cyan-blue
    vec3 color4 = vec3(0.4, 0.15, 0.5);   // Purple-pink

    // Cycle through colors (faster for trippy effect)
    float pos = fract(t + TIME * 0.15) * 4.0;

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

    // Moving circles that distort the background
    vec2 circle1_pos = vec2(0.3 + sin(time * 0.4) * 0.3, 0.4 + cos(time * 0.3) * 0.3);
    vec2 circle2_pos = vec2(0.7 + cos(time * 0.35) * 0.25, 0.6 + sin(time * 0.45) * 0.25);
    vec2 circle3_pos = vec2(0.5 + sin(time * 0.5) * 0.2, 0.3 + cos(time * 0.4) * 0.2);

    float circle1 = circle_sdf(uv, circle1_pos, 0.15);
    float circle2 = circle_sdf(uv, circle2_pos, 0.12);
    float circle3 = circle_sdf(uv, circle3_pos, 0.18);

    // Smooth distortion fields from circles
    float dist1 = smoothstep(0.3, 0.0, abs(circle1)) * 0.15;
    float dist2 = smoothstep(0.25, 0.0, abs(circle2)) * 0.12;
    float dist3 = smoothstep(0.35, 0.0, abs(circle3)) * 0.18;

    // Apply circular distortions to UV
    vec2 distorted_uv = uv;
    distorted_uv += normalize(uv - circle1_pos) * dist1;
    distorted_uv += normalize(uv - circle2_pos) * dist2;
    distorted_uv += normalize(uv - circle3_pos) * dist3;

    // Add wave distortion
    float wave1 = sin(distorted_uv.y * 8.0 + time * 2.0) * 0.02;
    float wave2 = cos(distorted_uv.x * 6.0 + time * 1.5) * 0.02;
    distorted_uv.x += wave1;
    distorted_uv.y += wave2;

    // Create multiple layers of smooth flowing patterns
    vec2 offset1 = vec2(cos(time * 0.3) * 0.5, sin(time * 0.2) * 0.5);
    vec2 offset2 = vec2(sin(time * 0.4) * 0.3, cos(time * 0.3) * 0.3);
    vec2 offset3 = vec2(cos(time * 0.25) * 0.4, sin(time * 0.35) * 0.4);

    // Combine noise layers with distorted UV
    float n1 = fbm(distorted_uv * 1.5 + offset1);
    float n2 = fbm(distorted_uv * 2.0 + offset2);
    float n3 = fbm(distorted_uv * 2.5 + offset3);

    // Blend noise layers with smooth weights
    float noise_val = (n1 * 0.4 + n2 * 0.4 + n3 * 0.2);

    // Add smooth diagonal gradient for consistent flow
    float diagonal = (distorted_uv.x + distorted_uv.y) * 0.5;
    noise_val = mix(noise_val, diagonal + time * 0.15, 0.3);

    // Add circular color influences
    noise_val += dist1 * 0.3;
    noise_val += dist2 * 0.25;
    noise_val += dist3 * 0.2;

    // Smooth out the value to eliminate any remaining harsh transitions
    noise_val = smoothstep(0.0, 1.0, noise_val);

    // Get vaporwave colors
    vec3 color = get_vaporwave_color(noise_val);

    // Add subtle brightness variation for depth
    float brightness = 1.0 + (noise_val - 0.5) * 0.2;

    // Add highlights where circles are
    brightness += (dist1 + dist2 + dist3) * 0.4;

    color *= brightness;

    COLOR = vec4(color, 1.0);
}
