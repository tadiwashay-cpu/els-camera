// Toon lighting (0.8, FR-Legends-like look): the sun in soft-edged bands
// instead of a smooth falloff, crisp shadow edges, a small hard highlight
// and a thin rim of light on edges that face the sun. `toon` (a global
// shader parameter, project.godot [shader_globals]) blends back to plain
// lighting: Settings > Art style > Classic sets it to 0.
global uniform float toon;

void light() {
	float ndl = dot(NORMAL, LIGHT);
#ifdef TOON_FOLIAGE
	// Leaves let light through: their back faces are lit from either side.
	ndl = mix(ndl, abs(ndl) * 0.7, foliage_back);
#endif
	float lambert = clamp(ndl, 0.0, 1.0);
	float bands = smoothstep(-0.04, 0.06, ndl) * 0.55 + smoothstep(0.42, 0.52, ndl) * 0.3;
	float att = mix(ATTENUATION, smoothstep(0.35, 0.65, ATTENUATION), toon);
	DIFFUSE_LIGHT += mix(lambert, bands, toon) * att * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float gloss = mix(12.0, 90.0, 1.0 - ROUGHNESS);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), gloss);
	spec = mix(spec, smoothstep(0.45, 0.55, spec), toon) * (1.0 - ROUGHNESS * 0.85);
	vec3 spec_tint = mix(vec3(1.0), ALBEDO, METALLIC);
	SPECULAR_LIGHT += spec * att * LIGHT_COLOR * spec_tint * 0.35;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * smoothstep(0.0, 0.3, ndl);
	SPECULAR_LIGHT += smoothstep(0.3, 0.4, rim) * toon * att * LIGHT_COLOR * 0.12;
}
