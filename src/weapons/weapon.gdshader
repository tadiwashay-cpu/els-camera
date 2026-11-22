shader_type spatial;
// Weapons: one draw call, three finishes picked per box by the vertex
// colour's alpha (set by tools/gen_weapons.py):
//   1.0 = matte (wood, cloth, rubber, paint)
//   0.5 = polished metal (blades, iron, gold)
//   0.0 = glowing (plasma, magic, sparks)

varying vec3 col;
varying float finish;
// A weapon power ready to use: a pulsing glow in its colour (alpha = strength).
instance uniform vec4 charge : source_color = vec4(0.0);

void vertex() {
	vec3 c = COLOR.rgb;
	col = mix(pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)), c / vec3(12.92), lessThan(c, vec3(0.04045)));
	finish = COLOR.a;
}

void fragment() {
	float metal = step(0.25, finish) * step(finish, 0.75);
	float emit = step(finish, 0.25);
	ALBEDO = col;
	METALLIC = metal * 0.75;
	ROUGHNESS = mix(0.7, 0.26, metal);
	SPECULAR = mix(0.35, 0.8, metal);
	EMISSION = col * emit * 2.2 + charge.rgb * charge.a * (0.35 + 0.65 * emit + 0.4 * metal);
}
