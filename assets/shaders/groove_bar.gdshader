shader_type canvas_item;

// Groove bar shader with rainbow lava lamp effect and curved right edge
uniform float speed = 0.3;
uniform float curve_radius = 30.0;  // Radius for rounded right edge

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

void fragment() {
    vec2 uv = UV;
    vec2 pixel_pos = uv * vec2(1.0 / TEXTURE_PIXEL_SIZE.x, 1.0 / TEXTURE_PIXEL_SIZE.y);
    vec2 size = vec2(1.0 / TEXTURE_PIXEL_SIZE.x, 1.0 / TEXTURE_PIXEL_SIZE.y);

    // Calculate distance from right edge for curved masking
    float right_edge_x = size.x;
    float dist_from_right = right_edge_x - pixel_pos.x;
    float half_height = size.y * 0.5;
    float dist_from_center_y = abs(pixel_pos.y - half_height);

    // Create curved right edge (rounded cap)
    float alpha = 1.0;
    if (dist_from_right < curve_radius) {
        // Calculate distance from the curve center point
        float curve_center_y = half_height;
        float curve_center_x = right_edge_x - curve_radius;

        // Distance from top or bottom curve center
        float top_curve_y = curve_radius;
        float bottom_curve_y = size.y - curve_radius;

        if (pixel_pos.y < top_curve_y) {
            // Top rounded corner
            float dx = pixel_pos.x - curve_center_x;
            float dy = pixel_pos.y - top_curve_y;
            float dist = sqrt(dx * dx + dy * dy);
            alpha = smoothstep(curve_radius + 1.0, curve_radius - 1.0, dist);
        } else if (pixel_pos.y > bottom_curve_y) {
            // Bottom rounded corner
            float dx = pixel_pos.x - curve_center_x;
            float dy = pixel_pos.y - bottom_curve_y;
            float dist = sqrt(dx * dx + dy * dy);
            alpha = smoothstep(curve_radius + 1.0, curve_radius - 1.0, dist);
        }
    }

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

    // Rainbow color
    vec3 color = rainbow(n);

    // Add some brightness variation
    float brightness = 0.8 + n * 0.4;
    color *= brightness;

    COLOR = vec4(color, alpha);
}
