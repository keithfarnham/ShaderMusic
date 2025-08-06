shader_type canvas_item;

//based on shader by public_int_i here: https://www.shadertoy.com/view/XdBBDz
uniform float songDuration;
const int VU_COUNT = 20;
uniform float[VU_COUNT] freq_data;
uniform float zoomValue = 1.0;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform bool useUV = true;
uniform bool visibleInScroll = true;
void fragment() {
    if (!visibleInScroll) {
        discard;
    }
    float fft = freq_data[int(UV.x * float(VU_COUNT))];
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = (FRAGCOORD.xy * (zoomValue + (0.01 * TIME/120.0) + fft)) + pixelCoords_mod;
    // Apply horizontal scroll for hyperspace effect
    float maxScrollDist = 20000.0;
    normalizedCoords.x += maxScrollDist * (1.0 - exp(-TIME * 0.005));

	vec4 o = vec4(0.0, 0.1, 0.1, 0.0);
	for (int s = 0; s < 64; s++) {
        vec2 R = screenSize;
        vec2 u = vec2( float(s%8) / 2.0, float(s/8) / 2.0);
		u = (normalizedCoords*2.0-R+u)/R.x;
		u = floor((6.0-vec2(atan(u.y,u.x)/3.0,length(u)))*R)+0.5;

		o += max(1.0-fract(vec4(7.0,6.0,4.0,0.0)*0.02+(u.y*0.02+u.x*0.4)*fract(u.x*0.61)+TIME)*5.0, 0.0)/64.0;
    }
    o.rgb = vec3(o.r + fft, o.g + fft, o.b - fft * 0.5);
	COLOR = o;
}