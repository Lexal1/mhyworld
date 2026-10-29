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
uniform float moon_size = 0.05;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5; // set by day_night.gd: 0 = clear, 1 = overcast
uniform float cloud_scale = 1.5;
uniform vec2 cloud_wind = vec2(0.02, 0.0); // drift, in noise units per second
uniform float cloud_evolve = 0.03;         // how fast the shapes morph in place
uniform float cloud_softness = 0.2;        // higher = fluffier edges

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
	float s = step(0.992, h) * smoothstep(0.4, 0.05, length(f));
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.9, 0.7), hash31(id + 7.0));
	return tint * s * (0.6 + 2.0 * fract(h * 97.0));
}

void sky() {
	vec3 dir = EYEDIR;
	float y = max(dir.y, 0.0); // below the horizon we just keep the horizon colour (matches the fog)

	// Base gradient
	vec3 col = mix(sky_horizon, sky_top, pow(y, 0.45));

	// Warm glow on the side of the sky facing the sun, strongest at sunrise/sunset
	vec2 flat_dir = normalize(dir.xz + vec2(1e-5));
	vec2 flat_sun = normalize(sun_dir.xz + vec2(1e-5));
	float facing = pow(max(dot(flat_dir, flat_sun), 0.0), 3.0);
	float band = 1.0 - smoothstep(0.0, 0.45, y);
	col = mix(col, glow_color, dusk * facing * band * 0.85);

	// Halo around the sun
	float sun_cos = dot(dir, sun_dir);
	float above = smoothstep(-0.1, 0.1, dir.y);
	float sun_up = smoothstep(-0.15, 0.05, sun_dir.y);
	vec3 halo_col = mix(vec3(1.0, 0.9, 0.7), glow_color, dusk);
	float halo = pow(max(sun_cos, 0.0), 24.0) * 0.35 + pow(max(sun_cos, 0.0), 6.0) * 0.12;
	col += halo_col * halo * sun_up * above;

	// Sun, moon and stars are left out of the ambient-light cubemap so they don't light the world twice.
	if (!AT_CUBEMAP_PASS) {
		float sun_ang = acos(clamp(sun_cos, -1.0, 1.0));
		float disc = 1.0 - smoothstep(sun_size * 0.8, sun_size, sun_ang);
		col += mix(vec3(1.0, 0.95, 0.85), glow_color, dusk * 0.7) * disc * 4.0 * above;

		vec3 moon_dir = -sun_dir;
		float moon_cos = dot(dir, moon_dir);
		float moon_ang = acos(clamp(moon_cos, -1.0, 1.0));
		float moon = 1.0 - smoothstep(moon_size * 0.85, moon_size, moon_ang);
		col += vec3(0.5, 0.6, 1.0) * pow(max(moon_cos, 0.0), 48.0) * 0.15 * star_amount * above;
		col += vec3(0.85, 0.9, 1.0) * moon * 1.5 * star_amount * above;
		col += stars(dir) * star_amount * above;
	}

	// Clouds: the sky is treated as a flat layer overhead
	if (dir.y > 0.0) {
		vec2 plane = dir.xz / (dir.y + 0.12) * cloud_scale + TIME * cloud_wind;
		vec3 p = vec3(plane, TIME * cloud_evolve);

		// Coverage: a lower threshold lets more of the noise count as cloud.
		// pow() makes the slider feel even (0.5 = partly cloudy, 1.0 = solid overcast).
		float thr = mix(0.35, -0.55, pow(cloud_cover, 1.5));
		float density = fbm(p);
		float cov = smoothstep(thr, thr + cloud_softness, density);
		cov *= smoothstep(0.0, 0.05, cloud_cover); // exactly clear at 0
		cov *= smoothstep(0.0, 0.15, dir.y);       // fade at the horizon where the noise gets tiny

		// Cheap lighting: if it's thinner toward the sun, we're near a sunlit edge.
		float density_sun = fbm(p + vec3(flat_sun * 0.12, 0.0));
		float lit = clamp(0.5 + (density - density_sun) * 4.0, 0.0, 1.0);

		// Heavy cover = darker, greyer clouds.
		float overcast = smoothstep(0.6, 1.0, cloud_cover);
		vec3 lit_col = mix(vec3(1.0), glow_color, dusk * 0.75) * mix(1.0, 0.6, overcast);
		vec3 shade_col = lit_col * mix(vec3(0.55, 0.6, 0.75), vec3(0.5, 0.52, 0.58), overcast);
		vec3 cloud = mix(shade_col, lit_col, lit) * mix(0.05, 1.0, daylight);
		col = mix(col, cloud, cov * mix(0.95, 1.0, overcast));
	}

	// Darker "ground" in the ambient cubemap, so downward faces aren't lit like the sky.
	if (AT_CUBEMAP_PASS) {
		col *= mix(1.0, 0.45, 1.0 - smoothstep(-0.25, 0.0, dir.y));
	}

	COLOR = col;
}
