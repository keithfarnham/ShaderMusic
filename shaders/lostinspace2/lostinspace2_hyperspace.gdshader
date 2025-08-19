shader_type canvas_item;

//based on shader by public_int_i here: https://www.shadertoy.com/view/XdBBDz
uniform float songDuration;
const int VU_COUNT = 20;
uniform float[VU_COUNT] freq_data;
uniform float zoomValue = 1.0;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform bool visibleInScroll = true;
uniform bool previewMode = false;
uniform bool part2 = true;

mat2 rotation(float angle) {
    angle = radians(angle);
    float c = cos(angle);
    float s = sin(angle);
    return mat2(
        vec2(c, -s), 
        vec2(s, c)
    );
}

vec4 color(vec2 screenSize, vec2 normalizedCoords) {
    vec4 c = vec4(0.0);
    int iter = part2 ? 64 : 8;
    for (int s = 0; s < 64; s++) {
        vec2 R = screenSize;
        vec2 u = vec2( float(s%8) / 2.0, float(s/8) / 2.0);
		u = (normalizedCoords*2.0-R+u)/R.x;
		u = floor((6.0-vec2(atan(u.y,u.x)/3.0,length(u)))*R)+0.5;

		c += max(1.0-fract(vec4(7.0,6.0,4.0,0.0) * 0.02 + (u.y*0.02+u.x*0.4) * fract(u.x*0.61) + TIME) * 5.0, 0.0)/64.0;
    }

    return c;
}

void fragment() {
    if (!visibleInScroll) {
        discard;
    }
    float fft = freq_data[int(UV.x * 4.0 * float(VU_COUNT))];
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    float zoom = mix(0.3, zoomValue, 0.5 + 0.5 * sin(TIME * 0.05));
    vec2 normalizedCoords = (FRAGCOORD.xy * zoom) + pixelCoords_mod;

	vec4 o = vec4(0.0, 0.1, 0.1, 1.0);
    
    if (!part2) {
        o = vec4(0.0 + fft, 0.1 * fft, 0.1 - fft, 1.0);
    }
    
    o += color(screenSize, normalizedCoords);
    
    if (!previewMode) {
        mat2 rot = rotation(15.0);
        vec2 coords = normalizedCoords * rot;
        o += color(screenSize, coords);
        rot = part2 ? rotation(5.0) : rotation(5.0 + 10.0 * sin(TIME * 0.5));
    }

	COLOR = o;
}