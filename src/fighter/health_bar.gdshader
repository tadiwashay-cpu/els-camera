shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A small life bar that always faces the camera (HealthBar). The fill goes
// green -> yellow -> red; a pale trail shows damage just taken; the rim is
// the fighter's colour.
instance uniform float fill = 1.0;
instance uniform float trail = 1.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float alpha = 1.0;

void vertex() {
	// Billboard: keep the quad's centre, face the camera, keep its world size.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV;
	// Rounded pill: distance from the inner segment.
	float aspect = 5.6;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float half_len = aspect * 0.5 - 0.5;
	float d = length(vec2(max(abs(p.x) - half_len, 0.0), p.y)) - 0.5;
	if (d > 0.0) {
		discard;
	}
	float rim = smoothstep(-0.22, -0.12, d);
	// Inner bar coordinates (inside the rim).
	float x = clamp((uv.x - 0.04) / 0.92, 0.0, 1.0);
	vec3 health = mix(vec3(0.95, 0.2, 0.15), vec3(1.0, 0.85, 0.2), smoothstep(0.15, 0.5, fill));
	health = mix(health, vec3(0.3, 0.92, 0.38), smoothstep(0.5, 0.85, fill));
	vec3 col = vec3(0.06, 0.06, 0.08);
	if (x < trail) {
		col = vec3(1.0, 0.92, 0.85);
	}
	if (x < fill) {
		col = health * (0.85 + 0.25 * (1.0 - uv.y));
	}
	col = mix(col, tint.rgb * 0.9, rim);
	ALBEDO = col;
	ALPHA = alpha;
}
