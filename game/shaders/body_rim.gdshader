shader_type canvas_item;

// Rim-light + soft-edge shader for the stage-2 membrane body.
// The body texture is a warm coral gradient; this shader carves the
// circular silhouette, adds a bright crescent on the light side
// (upper-left) and a soft top gloss. No painted outline is baked in.

uniform vec4 rim_color : source_color = vec4(1.00, 0.88, 0.82, 1.0);
uniform float rim_width : hint_range(0.0, 0.5) = 0.22;
uniform vec2 light_dir = vec2(-0.55, -0.83);
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Elliptical distance from the membrane center (slightly high).
	vec2 c = vec2(0.5, 0.47);
	vec2 p = (UV - c) * vec2(1.0, 1.08);
	float d = length(p) * 2.0; // 0 at center, ~1.0 at the rim
	// Soft circular silhouette.
	float edge = smoothstep(1.0, 0.93, d);
	// Rim crescent: bright near the edge, on the side facing the light.
	vec2 n = normalize(p + vec2(0.0001));
	float facing = clamp(dot(n, normalize(light_dir)), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, d) * pow(facing, 1.6);
	// Top gloss: soft highlight toward the upper middle.
	float gloss = smoothstep(0.55, 0.0, d) * 0.5 * max(0.0, -n.y);
	vec3 col = tex.rgb + rim_color.rgb * rim * 0.9 + vec3(1.0) * gloss * gloss_strength;
	COLOR = vec4(col, tex.a * edge);
}
