shader_type spatial;
render_mode cull_disabled, specular_disabled, vertex_lighting;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float snap_resolution : hint_range(60.0, 480.0, 1.0) = 100.0;
uniform float alpha_cut = 0.5;

void vertex() {
	// Replaces Sprite3D's BILLBOARD_FIXED_Y (turns to face you, stays upright).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

	// Same snapping as models.gdshader.
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (!IN_SHADOW_PASS) {
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * snap_resolution) / snap_resolution;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	if (albedo.a < alpha_cut) discard; // replaces ALPHA_CUT_DISCARD
	ALBEDO = albedo.rgb;
}