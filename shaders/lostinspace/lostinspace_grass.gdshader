shader_type canvas_item;

//based on shader by fizzer here: https://www.shadertoy.com/view/lslGR8

const int VU_COUNT = 20;
uniform float songDuration;
uniform float[VU_COUNT] freq_data;
uniform float zoomValue = 1.0;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform bool visibleInScroll = true;

#define BLADES 110

vec3 rotateX(float a, vec3 v)
{
	return vec3(v.x, cos(a) * v.y + sin(a) * v.z, cos(a) * v.z - sin(a) * v.y);
}

vec3 rotateY(float a, vec3 v)
{
	return vec3(cos(a) * v.x + sin(a) * v.z, v.y, cos(a) * v.z - sin(a) * v.x);
}

vec3 rotateZ(float a, vec3 v)
{
	return vec3(cos(a) * v.x + sin(a) * v.y, cos(a) * v.y - sin(a) * v.x, v.z);
}

vec4 grass(vec2 p, float x)
{
	float s = mix(0.7, 2.0, 0.5 + sin(x * 12.0) * 0.5);
	p.x += pow(1.0 + p.y, 2.0) * 0.1 * cos(x * 0.5 + TIME);
	p.x *= s;
	p.y = (1.0 + p.y) * s - 1.0;
	float m = 1.0 - smoothstep(0.0, clamp(1.0 - p.y * 1.5, 0.01, 0.6) * 0.2 * s, pow(abs(p.x) * 19.0, 1.5) + p.y - 0.6);
	return vec4(mix(vec3(0.05, 0.1, 0.0) * 0.8, vec3(0.0, 0.3, 0.0), (p.y + 1.0) * 0.5 + abs(p.x)), m * smoothstep(-1.0, -0.9, p.y));
}

float dither(vec2 fragCoord)
{
	return fract(fragCoord.x * 0.482635532 + fragCoord.y * 0.1353412 + TIME * 100.0) * 0.008;
}

void fragment() {
	if (!visibleInScroll) {
		discard;
	}
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = -FRAGCOORD.xy / screenSize;
	normalizedCoords *= zoomValue;
    normalizedCoords += pixelCoords_mod;

	vec3 ct = vec3(0.0, 1.0, 5.0);
	vec3 cp = rotateY(cos(TIME * 0.2) * 0.4, vec3(0.0, 0.6, 0.0));
	vec3 cw = normalize(cp - ct);
	vec3 cu = normalize(cross(cw, vec3(0.0, 1.0, 0.0)));
	vec3 cv = normalize(cross(cu, cw));
	
	mat3 rm = mat3(cu, cv, cw);
	
	vec2 uv = (FRAGCOORD.xy / normalizedCoords) * 2.0 - vec2(1.0);
	uv.y = -uv.y;
	vec2 t = uv;
	t.x *= screenSize.x / screenSize.y;
	
	vec3 ro = cp, rd = rotateY(0.05, rm * rotateZ(0.05, vec3(t, -1.3)));
	
	vec3 fcol = vec3(0.0);
	
	for(int i = 0; i < BLADES; i += 1)
	{
		float z = -(float(BLADES - i) * 0.1 + 1.0);
		vec4 pln = vec4(0.0, 0.0, -1.0, z);
		float t = (pln.w - dot(pln.xyz, ro)) / dot(pln.xyz, rd);
		vec2 tc = ro.xy + rd.xy * t;
		
		tc.x += cos(float(i) * 3.0) * 4.0;
		
		float cell = floor(tc.x);
		
		tc.x = (tc.x - cell) - 0.5;
		
		vec4 c = grass(tc, float(i) + cell * 10.0);
		
		fcol = mix(fcol, c.rgb, step(0.0, t) * c.w);
	}
    float fft = freq_data[int(UV.x * float(VU_COUNT))];
	float grassBrightnessTime = mod(TIME, songDuration);
	float grassBrightnessWait = 115.0;
	fcol = pow(fcol * 1.1, vec3(0.8));
	fcol.g = fcol.g > 0.1 ? fcol.g - (fft * 0.01) : fcol.g;
	if (grassBrightnessTime >= grassBrightnessWait) {
		fcol = fcol.g > 0.1 ? mix(fcol, fcol + vec3(0.2, 0.1, 0.2) * fft, (grassBrightnessTime - grassBrightnessWait) / (songDuration - grassBrightnessWait) ) : fcol;
	}
	
	// iÃ±igo quilez's great vigneting effect!
	vec2 q = (uv + vec2(1.0)) * 0.5;
	fcol *= 0.2 + 0.8*pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.1 );
	
	vec4 fragColor;
	fragColor.rgb = fcol * 1.8 + vec3(dither(FRAGCOORD.xy));
	fragColor.a = length(fcol.rgb) > 0.01 ? 1.0 : 0.0; // Alpha 1 if grass, 0 if background
	COLOR = fragColor;
}