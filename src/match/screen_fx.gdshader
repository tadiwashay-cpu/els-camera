shader_type canvas_item;
// Hits and speed (ScreenFx): colour split, a radial blur towards the centre,
// a tinted flash at the edges and the vignette. Only drawn while an effect
// runs: it reads the screen.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette = 0.3;
uniform float aberration = 0.0;
uniform float blur = 0.0;
uniform vec4 flash : source_color = vec4(1.0, 0.1, 0.1, 0.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float r = length(c * vec2(1.5, 1.0));
	vec2 split = c * aberration * 0.016;
	vec3 col = vec3(texture(screen, uv - split).r, texture(screen, uv).g, texture(screen, uv + split).b);
	if (blur > 0.002) {
		vec3 acc = col;
		for (int i = 1; i <= 5; i++) {
			acc += texture(screen, uv - c * blur * 0.05 * float(i) / 5.0).rgb;
		}
		col = mix(col, acc / 6.0, smoothstep(0.08, 0.5, r));
	}
	float v = smoothstep(0.42, 1.08, r);
	col *= 1.0 - v * vignette;
	col = mix(col, flash.rgb, flash.a * v);
	COLOR = vec4(col, 1.0);
}
