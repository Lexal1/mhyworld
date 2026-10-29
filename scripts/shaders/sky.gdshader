shader_type sky;

// Colours, sun direction and time-of-day amounts are set by day_night.gd every frame.
uniform vec3 sky_top : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.83, 0.93);
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.25);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);   // points TOWARD the sun
uniform mat3 celestial_basis;                 // world -> star field, so stars turn with the sun
uniform float dusk : hint_range(0.0, 1.0) = 0.0;        // 1 at sunrise/sunset
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0; // 1 at night

// Look, tweak these on the material.
uniform float sun_size = 0.045;   // angular radius in radians (real sun is ~0.005, too tiny for a game)
uniform sampler2D sun_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 sun_atlas = vec2(1.0, 1.0);   // columns, rows
uniform float sun_frame = 0.0;

uniform float moon_size = 0.05;
uniform sampler2D moon_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 moon_atlas = vec2(4.0, 2.0);  // columns, rows
uniform float moon_frame = 0.0;

uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5; // set by day_night.gd: 0 = clear, 1 = overcast
uniform float cloud_scale = 1.5;
uniform vec2 cloud_wind = vec2(0.02, 0.0); // drift, in noise units per second
uniform float cloud_evolve = 0.03;         // how fast the shapes morph in place
uniform float cloud_softness = 0.2;        // higher = fluffier edges
uniform float sky_bands = 10.0;            // PSX: gradient colour steps from horizon to zenith
uniform float cloud_pixels = 32.0;         // PSX: cloud cells per noise unit (lower = chunkier)

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			dot(p, vec3(269.5, 183.3, 246.1)),
			dot(p, vec3(113.5, 271.9, 124.6)));
	return normalize(-1.0 + 2.0 * fract(sin(p) * 43758.5453123) + vec3(1e-4));
}

// 3D Perlin (gradient) noise, roughly -0.5..0.5. The 3rd axis is time, so clouds morph instead of just sliding.
float perlin(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic fade

	float n000 = dot(hash33(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0));
	float n100 = dot(hash33(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0));
	float n010 = dot(hash33(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0));
	float n110 = dot(hash33(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0));
	float n001 = dot(hash33(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0));
	float n101 = dot(hash33(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0));
	float n011 = dot(hash33(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0));
	float n111 = dot(hash33(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0));

	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
			mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

// Centred on 0, so a threshold of 0 covers about half the sky.
float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * perlin(p);
		p = p * 2.03 + vec3(17.1, 9.3, 3.7); // higher octaves also evolve faster in time
		amp *= 0.5;
	}
	return sum;
}

vec3 stars(vec3 dir) {
	vec3 d = (celestial_basis * dir) * 70.0;
	vec3 id = floor(d);
	vec3 f = fract(d) - 0.5;
	float h = hash31(id);
	float s = step(0.992, h) * step(length(f), 0.3); // PSX: hard-edged dots
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.9, 0.7), hash31(id + 7.0));
	return tint * s * (0.6 + 2.0 * fract(h * 97.0));
}

// Returns (u, v, inside). Maps a view direction onto a square facing `body_dir`.
// `size` is the half-width in radians, same meaning as before.
vec3 body_uv(vec3 dir, vec3 body_dir, float size, vec3 up_axis) {
	float c = dot(dir, body_dir);
	if (c <= 0.0) return vec3(0.0);
	vec3 off = dir / c - body_dir;
	vec3 right = normalize(cross(body_dir, up_axis));
	vec2 p = vec2(dot(off, right), dot(off, up_axis)) / tan(size) * 0.5 + 0.5;
	p.y = 1.0 - p.y; // texture v runs downward
	float inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	return vec3(p, inside);
}

// Picks one cell of a row-major atlas (frame 0 = top-left).
vec2 atlas_uv(vec2 uv, vec2 grid, float frame) {
	float f = mod(floor(frame), grid.x * grid.y);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	return (cell + uv) / grid;
}

void sky() {
	vec3 dir = EYEDIR;
	float y = max(dir.y, 0.0); // below the horizon we just keep the horizon colour (matches the fog)

	// Base gradient
	float yq = floor(y * sky_bands + 0.5) / sky_bands; // PSX: hard colour bands, not a smooth gradient
	vec3 col = mix(sky_horizon, sky_top, pow(yq, 0.45));

	// Warm glow on the side of the sky facing the sun, strongest at sunrise/sunset
	vec2 flat_dir = normalize(dir.xz + vec2(1e-5));
	vec2 flat_sun = normalize(sun_dir.xz + vec2(1e-5));
	float facing = pow(max(dot(flat_dir, flat_sun), 0.0), 3.0);
	float band = 1.0 - smoothstep(0.0, 0.75, y);
	float glow_w = floor(dusk * facing * band * 0.85 * 5.0 + 0.5) / 5.0; // PSX: banded sunset
	col = mix(col, glow_color, glow_w);

	// Halo around the sun
	float sun_cos = dot(dir, sun_dir);
	float above = smoothstep(-0.1, 0.1, dir.y);
	float sun_up = smoothstep(-0.15, 0.05, sun_dir.y);
	vec3 halo_col = mix(vec3(1.0, 0.9, 0.7), glow_color, dusk);
	float halo = pow(max(sun_cos, 0.0), 24.0) * 0.35 + pow(max(sun_cos, 0.0), 6.0) * 0.12;
	halo = floor(halo * 24.0) / 32.0; // PSX: stepped halo
	col += halo_col * halo * sun_up * above;

	// Sun, moon and stars are left out of the ambient-light cubemap so they don't light the world twice.
	if (!AT_CUBEMAP_PASS) {
		col += stars(dir) * star_amount * above; // first, so the moon draws over them

		// The sun's path rotates around this axis, so using it as "up" keeps the sprites upright.
		vec3 up_axis = transpose(celestial_basis) * vec3(0.0, 0.0, 1.0);

		vec3 m = body_uv(dir, -sun_dir, moon_size, up_axis);
		float moon_halo = floor(pow(max(dot(dir, -sun_dir), 0.0), 48.0) * 4.0) / 4.0 * 0.15;
		col += vec3(0.5, 0.6, 1.0) * moon_halo * star_amount * above;
		if (m.z > 0.5) {
			vec4 t = textureLod(moon_texture, atlas_uv(m.xy, moon_atlas, moon_frame), 0.0);
			col = mix(col, t.rgb * 1.5, t.a * star_amount * step(0.0, dir.y));
		}

		vec3 s = body_uv(dir, sun_dir, sun_size, up_axis);
		if (s.z > 0.5) {
			vec4 t = textureLod(sun_texture, atlas_uv(s.xy, sun_atlas, sun_frame), 0.0);
			vec3 tint = mix(vec3(1.0, 0.95, 0.85), glow_color, dusk * 0.7);
			col = mix(col, t.rgb * tint * 2.0, t.a * step(0.0, dir.y));
		}
	}

	// Clouds: the sky is treated as a flat layer overhead
	if (dir.y > 0.0) {
		vec2 plane = dir.xz / (dir.y + 0.12) * cloud_scale;
		plane = floor(plane * cloud_pixels) / cloud_pixels + TIME * cloud_wind; // PSX: chunky cells, the noise drifts through them
		vec3 p = vec3(plane, TIME * cloud_evolve);

		// Coverage: a lower threshold lets more of the noise count as cloud.
		// pow() makes the slider feel even (0.5 = partly cloudy, 1.0 = solid overcast).
		float thr = mix(0.35, -0.55, pow(cloud_cover, 1.5));
		float density = fbm(p);
		float cov = smoothstep(thr, thr + cloud_softness, density);
		cov *= smoothstep(0.0, 0.05, cloud_cover); // exactly clear at 0
		cov *= smoothstep(0.0, 0.15, dir.y);       // fade at the horizon where the noise gets tiny
		cov = floor(cov * 3.0 + 0.5) / 3.0;        // PSX: a few opacity steps instead of soft edges

		// Cheap lighting: if it's thinner toward the sun, we're near a sunlit edge.
		float density_sun = fbm(p + vec3(flat_sun * 0.12, 0.0));
		float lit = step(density_sun, density); // PSX: two tones, lit or shaded

		// Heavy cover = darker, greyer clouds.
		// Heavy cover = darker, greyer clouds.
float overcast = smoothstep(0.6, 1.0, cloud_cover);

		// Clouds on the sun's side of the sky glow more at dusk.
		float sun_side = pow(max(dot(flat_dir, flat_sun), 0.0), 2.0);
		float tint = dusk * mix(0.5, 1.0, sun_side);
		vec3 lit_col = mix(vec3(1.0), glow_color, tint) * mix(1.0, 0.6, overcast);

		// Shaded undersides go from blue-grey (day) to purple (dusk).
		vec3 shade_tone = mix(vec3(0.55, 0.6, 0.75), vec3(0.45, 0.4, 0.6), dusk);
		vec3 shade_col = lit_col * mix(shade_tone, vec3(0.5, 0.52, 0.58), overcast);

		// Keep clouds lit while the sun is near the horizon, but not once it's well below it.
		float dusk_light = dusk * smoothstep(-0.2, 0.0, sun_dir.y) * 0.8;
		float brightness = max(mix(0.05, 1.0, daylight), dusk_light);
		vec3 cloud = mix(shade_col, lit_col, lit) * brightness;
		// The ambient light is sampled from this sky. Bright white clouds would flood the world with light
		// (more cloud = brighter), so the ambient copy of the clouds is much dimmer than what you see.
		if (AT_CUBEMAP_PASS) cloud *= 0.35;
		col = mix(col, cloud, cov * mix(0.95, 1.0, overcast));
	}

	// Darker "ground" in the ambient cubemap, so downward faces aren't lit like the sky.
	if (AT_CUBEMAP_PASS) {
		col *= mix(1.0, 0.45, 1.0 - smoothstep(-0.25, 0.0, dir.y));
	}

	COLOR = col;
}
