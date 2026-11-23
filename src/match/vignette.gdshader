shader_type canvas_item;
// The resting look (ScreenFx): darker corners, no screen read.
uniform float vignette = 0.3;

void fragment() {
	vec2 c = SCREEN_UV - vec2(0.5);
	float v = smoothstep(0.42, 1.08, length(c * vec2(1.5, 1.0)));
	COLOR = vec4(0.0, 0.0, 0.02, v * vignette);
}
