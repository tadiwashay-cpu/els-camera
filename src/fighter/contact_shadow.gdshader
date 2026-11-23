shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A soft round shadow: darkest in the middle, gone at the rim.
instance uniform float alpha = 0.5;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = (1.0 - smoothstep(0.15, 1.0, d));
	ALBEDO = vec3(0.02, 0.02, 0.03);
	ALPHA = a * a * alpha;
}
