shader_type canvas_item;

// Color invert shader for opponent sprite
// Creates a negative/inverted color effect

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    // Invert RGB channels, keep alpha the same
    color.rgb = vec3(1.0) - color.rgb;
    COLOR = color;
}
