shader_type canvas_item;

// Vaporwave-style swirling background shader
// Bright shifting colors: pinks, purples, cyans, magentas
// Enhanced with STRONG visible moving distortions

uniform float speed = 1.5;  // Animation speed

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

// Circle SDF for visible distortion blobs
float circle_sdf(vec2 p, vec2 center, float radius) {
    return length(p - center) - radius;
}

// Vaporwave color palette
vec3 get_vaporwave_color(float t) {
    vec3 color1 = vec3(0.3, 0.15, 0.5);   // Deep purple
    vec3 color2 = vec3(0.5, 0.1, 0.4);    // Magenta
    vec3 color3 = vec3(0.1, 0.3, 0.6);    // Cyan-blue
    vec3 color4 = vec3(0.4, 0.15, 0.5);   // Purple-pink

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

    // LARGE visible distortion blobs moving around
    vec2 blob1_pos = vec2(0.25 + sin(time * 0.5) * 0.4, 0.5 + cos(time * 0.4) * 0.4);
    vec2 blob2_pos = vec2(0.75 + cos(time * 0.6) * 0.35, 0.5 + sin(time * 0.5) * 0.35);
    vec2 blob3_pos = vec2(0.5 + sin(time * 0.45) * 0.3, 0.7 + cos(time * 0.55) * 0.3);

    // Calculate distances to blobs
    float blob1_dist = circle_sdf(uv, blob1_pos, 0.25);
    float blob2_dist = circle_sdf(uv, blob2_pos, 0.2);
    float blob3_dist = circle_sdf(uv, blob3_pos, 0.28);

    // Create STRONG visible distortion fields
    float blob1_strength = smoothstep(0.5, 0.0, abs(blob1_dist)) * 0.5;
    float blob2_strength = smoothstep(0.45, 0.0, abs(blob2_dist)) * 0.4;
    float blob3_strength = smoothstep(0.55, 0.0, abs(blob3_dist)) * 0.6;

    // Apply strong UV warping
    vec2 distorted_uv = uv;

    // Radial distortion from blobs - much stronger
    vec2 dir1 = normalize(uv - blob1_pos);
    vec2 dir2 = normalize(uv - blob2_pos);
    vec2 dir3 = normalize(uv - blob3_pos);

    distorted_uv += dir1 * blob1_strength;
    distorted_uv += dir2 * blob2_strength;
    distorted_uv += dir3 * blob3_strength;

    // Add strong wave distortions
    float wave1 = sin(distorted_uv.y * 10.0 + time * 3.0) * 0.08;
    float wave2 = cos(distorted_uv.x * 8.0 + time * 2.5) * 0.08;
    distorted_uv.x += wave1;
    distorted_uv.y += wave2;

    // Swirling motion around blobs
    float angle1 = atan(uv.y - blob1_pos.y, uv.x - blob1_pos.x);
    float angle2 = atan(uv.y - blob2_pos.y, uv.x - blob2_pos.x);
    distorted_uv += vec2(cos(angle1), sin(angle1)) * blob1_strength * 0.3;
    distorted_uv += vec2(cos(angle2), sin(angle2)) * blob2_strength * 0.3;

    // Base gradient with distortion
    vec2 offset1 = vec2(cos(time * 0.3) * 0.5, sin(time * 0.2) * 0.5);
    vec2 offset2 = vec2(sin(time * 0.4) * 0.3, cos(time * 0.3) * 0.3);

    float n1 = fbm(distorted_uv * 1.5 + offset1);
    float n2 = fbm(distorted_uv * 2.0 + offset2);

    float noise_val = (n1 * 0.5 + n2 * 0.5);

    // Add diagonal flow
    float diagonal = (distorted_uv.x + distorted_uv.y) * 0.5;
    noise_val = mix(noise_val, diagonal + time * 0.15, 0.3);

    // VISIBLE color rings around blobs
    float ring1 = smoothstep(0.3, 0.25, abs(blob1_dist)) - smoothstep(0.25, 0.2, abs(blob1_dist));
    float ring2 = smoothstep(0.25, 0.2, abs(blob2_dist)) - smoothstep(0.2, 0.15, abs(blob2_dist));
    float ring3 = smoothstep(0.35, 0.3, abs(blob3_dist)) - smoothstep(0.3, 0.25, abs(blob3_dist));

    // Add extremely subtle ring effects to color value (alpha ≤ 0.1)
    noise_val += ring1 * 0.05;
    noise_val += ring2 * 0.04;
    noise_val += ring3 * 0.06;

    // Extremely subtle color shifts in blob areas (alpha ≤ 0.1)
    noise_val += blob1_strength * 0.08;
    noise_val += blob2_strength * 0.06;
    noise_val += blob3_strength * 0.10;

    noise_val = smoothstep(0.0, 1.0, noise_val);

    // Get vaporwave colors
    vec3 color = get_vaporwave_color(noise_val);

    // Brightness variation
    float brightness = 1.0 + (noise_val - 0.5) * 0.3;

    // Extremely subtle highlights on blob areas (alpha ≤ 0.1)
    brightness += blob1_strength * 0.10;
    brightness += blob2_strength * 0.08;
    brightness += blob3_strength * 0.10;

    // Extremely subtle ring highlights (alpha ≤ 0.1)
    brightness += (ring1 + ring2 + ring3) * 0.10;

    color *= brightness;

    COLOR = vec4(color, 1.0);
}
