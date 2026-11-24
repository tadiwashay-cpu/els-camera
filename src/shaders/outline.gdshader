shader_type spatial;
// Clean dark outlines (0.8 toon look): the mesh drawn again a little
// bigger, inside out, in one flat colour. Box fighters carry a second
// surface whose normals point to each box's corners (BoxBuilder), so the
// hull grows evenly and stays closed at the corners. The width follows the
// distance so the line keeps about the same thickness on screen.
render_mode unshaded, cull_front, shadows_disabled, ambient_light_disabled;

global uniform float outline_width;
uniform vec4 line_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float width_scale = 1.0;
instance uniform float outline_scale = 1.0;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = clamp(-view_pos.z, 1.5, 30.0);
	VERTEX += normalize(NORMAL) * outline_width * width_scale * outline_scale * d;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
