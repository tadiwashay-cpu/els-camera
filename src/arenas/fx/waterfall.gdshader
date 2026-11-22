shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// A sheet of falling water: streaks scrolling down, soft side edges.

uniform vec4 color : source_color = vec4(0.78, 0.92, 1.0, 0.72);
uniform float speed = 1.6;

void fragment() {
	float wob = sin(UV.x * 37.0) * 0.06 + sin(UV.x * 11.0 + 1.3) * 0.08;
	float s = fract(UV.y * 2.5 - TIME * speed + wob);
	float streak = 0.7 + 0.3 * smoothstep(0.0, 0.6, s);
	float lines = step(0.9, fract(UV.x * 17.0 + wob * 3.0));
	float edge = smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.9, UV.x);
	ALBEDO = color.rgb * streak + vec3(0.18) * lines;
	ALPHA = color.a * edge * (0.8 + 0.2 * streak) * smoothstep(1.0, 0.85, UV.y + 0.05);
}
