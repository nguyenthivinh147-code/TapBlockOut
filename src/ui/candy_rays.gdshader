shader_type canvas_item;
// Candy sunburst behind Road Trip's target gift box (road_trip_map.gd TargetRays, design.md mục 7 "Chuyển động của
// màn Road Trip"): pastel pink and purple rays turn slowly and fade out toward the rim, over a soft glow in the middle
// that breathes. Drawn on a square node; everything outside the inscribed circle is clear. Only TIME moves it, so the
// map under it is never redrawn.

// Pink rays (and as many purple ones between them).
uniform float rays = 10.0;
uniform vec4 pink : source_color = vec4(1.0, 0.70, 0.86, 1.0);
// Light lilac: a deeper purple vanishes on the map's purple background.
uniform vec4 purple : source_color = vec4(0.91, 0.82, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.96, 0.99, 1.0);
// Seconds for one turn (clockwise) and for one breath of the glow.
uniform float spin_sec = 12.0;
uniform float breathe_sec = 1.8;
// Overall opacity; purple rays are this much fainter than pink ones.
uniform float alpha : hint_range(0.0, 1.0) = 0.9;
uniform float purple_alpha : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) - TAU * TIME / spin_sec;
	// +1 on a pink ray, -1 on a purple one; a narrow soft edge between them.
	float w = cos(a * rays);
	float t = smoothstep(-0.18, 0.18, w);
	vec4 ray = mix(purple, pink, t);
	// Rays narrow toward the rim: each one fades from its middle line as the radius grows. The box covers the middle
	// (out to ~0.6 of the radius, the node is 1.7 boxes wide), so rays stay strong just past it, then fade.
	float core = mix(1.0, abs(w), smoothstep(0.5, 1.0, r));
	float ray_a = mix(purple_alpha, 1.0, t) * core * (1.0 - smoothstep(0.6, 1.0, r));
	float b = 0.5 + 0.5 * sin(TAU * TIME / breathe_sec);
	float g = exp(-r * r * mix(5.0, 3.5, b)) * mix(0.75, 1.0, b);
	vec3 col = mix(ray.rgb, glow.rgb, clamp(g, 0.0, 1.0));
	COLOR = vec4(col, clamp(max(ray_a, g), 0.0, 1.0) * alpha * step(r, 1.0));
}
