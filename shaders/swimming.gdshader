shader_type canvas_item;

// based on shader by TDM here: https://www.shadertoy.com/view/Ms2SD1

//audio visualization/modulation stuff based on https://godotshaders.com/shader/spectrum-analyzer/

uniform float zoomValue = 1.0;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform vec2 mouseScreenPos = vec2(0.0);
//fft
uniform float amplitude = 0.03;
uniform float freqX = 10.0;
uniform float freqSlow = 2.0;
uniform float freqY = 5.0;
uniform vec3 fftMod = vec3(1.0);
const int VU_COUNT = 10;
uniform float[VU_COUNT] freq_data;
uniform sampler2D prevFrame;
uniform sampler2D prevFrame2;
uniform sampler2D video;
uniform bool previewMode = false;
uniform bool visibleInScroll = true;
uniform float msWaited = 0.0;
uniform float BPM;
uniform float MS_PER_BEAT;
uniform float MS_PER_MEASURE;
// sea
uniform int iterGeometry = 3;
uniform int iterFragment = 5;
uniform float seaHeight = 0.6;
uniform float seaChoppy = 4.0;
uniform float seaSpeed = 2.0;
uniform float seaFreq = 0.16;
uniform vec3 seaBase = vec3(0.0,0.09,0.18);
uniform vec3 seaWaterColor = vec3(0.48,0.54,0.36);
#define SEA_TIME (1.0 + TIME * seaSpeed)

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 224.0; //218sec song duration + 6sec delay
const float songFadeOutStart = 218.0; //212sec fade start + 6sec delay

const mat2 octave_m = mat2(vec2(1.6,1.2),vec2(-1.2,1.6));
const int NUM_STEPS = 32;
const float EPSILON	= 1e-3;

// math
mat3 fromEuler(vec3 ang) {
	vec2 a1 = vec2(sin(ang.x),cos(ang.x));
    vec2 a2 = vec2(sin(ang.y),cos(ang.y));
    vec2 a3 = vec2(sin(ang.z),cos(ang.z));
    mat3 m;
    m[0] = vec3(a1.y*a3.y+a1.x*a2.x*a3.x,a1.y*a2.x*a3.x+a3.y*a1.x,-a2.y*a3.x);
	m[1] = vec3(-a2.y*a1.x,a1.y*a2.y,a2.x);
	m[2] = vec3(a3.y*a1.x*a2.x+a1.y*a3.x,a1.x*a3.x-a1.y*a3.y*a2.x,a2.y*a3.y);
	return m;
}
float hash( vec2 p ) {
	float h = dot(p,vec2(127.1,311.7));	
    return fract(sin(h)*43758.5453123);
}
float noise( in vec2 p ) {
    vec2 i = floor( p );
    vec2 f = fract( p );	
	vec2 u = f*f*(3.0-2.0*f);
    return -1.0+2.0*mix( mix( hash( i + vec2(0.0,0.0) ), 
                     hash( i + vec2(1.0,0.0) ), u.x),
                mix( hash( i + vec2(0.0,1.0) ), 
                     hash( i + vec2(1.0,1.0) ), u.x), u.y);
}

// lighting
float diffuse(vec3 n,vec3 l,float p) {
    return pow(dot(n,l) * 0.4 + 0.6,p);
}
float specular(vec3 n,vec3 l,vec3 e,float s, float fft) {    
    float nrm = (s + 8.0) / (PI * 8.0);
    return pow(max(dot(reflect(e,n),l),0.0),s) * nrm;
}

// sky
vec3 getSkyColor(vec3 e, float fft) {
    e.y = (max(e.y,0.0)*0.8+0.2)*0.8;
    return vec3(pow(1.0-e.y,2.0) + (fft * fftMod.x), 1.0-e.y + (fft * fftMod.y), 0.6+(1.0-e.y)*0.4 + (fft * fftMod.z)) * 1.1;
}

// sea
float sea_octave(vec2 uv, float choppy) {
    uv += noise(uv);
    vec2 wv = 1.0-abs(sin(uv));
    vec2 swv = abs(cos(uv));    
    wv = mix(wv,swv,wv);
    return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
}

float map(vec3 p, float fft) {
    float freq = seaFreq;
    float amp = seaHeight;
    float choppy = seaChoppy;
    vec2 uv = p.xz; uv.x *= 0.75;
    
    float d, h = 0.0;    
    for(int i = 0; i < iterGeometry; i++) {
    	d = sea_octave((uv + SEA_TIME)*freq,choppy);
    	d += sea_octave((uv - SEA_TIME)*freq,choppy);
        h += d * amp;        
    	uv *= octave_m; freq *= 1.9; amp *= 0.22;
        choppy = mix(choppy,1.0,0.2);
    }
    return p.y - h;
}

float map_detailed(vec3 p) {
    float freq = seaFreq;
    float amp = seaHeight;
    float choppy = seaChoppy;
    vec2 uv = p.xz; uv.x *= 0.75;
    
    float d, h = 0.0;    
    for(int i = 0; i < iterFragment; i++) {        
    	d = sea_octave((uv+SEA_TIME)*freq,choppy);
    	d += sea_octave((uv-SEA_TIME)*freq,choppy);
        h += d * amp;        
    	uv *= octave_m; freq *= 1.9; amp *= 0.22;
        choppy = mix(choppy,1.0,0.2);
    }
    return p.y - h;
}

vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist, float fft) {  
    float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
    fresnel = min(fresnel * fresnel * fresnel, 0.5);
    
    vec3 reflected = getSkyColor(reflect(eye, n), fft);    
    vec3 refracted = seaBase + diffuse(n, l, 80.0) * seaWaterColor * 0.12; 
    
    vec3 color = mix(refracted, reflected, fresnel);
    
    float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
    color += seaWaterColor * (p.y - seaHeight) * 0.18 * atten;
    
    color += specular(n, l, eye, 60.0, fft);
    
    return color;
}

// tracing
vec3 getNormal(vec3 p, float eps) {
    vec3 n;
    n.y = map_detailed(p);    
    n.x = map_detailed(vec3(p.x+eps,p.y,p.z)) - n.y;
    n.z = map_detailed(vec3(p.x,p.y,p.z+eps)) - n.y;
    n.y = eps;
    return normalize(n);
}

float heightMapTracing(vec3 ori, vec3 dir, out vec3 p, float fft) {
    float tm = 0.0;
    float tx = 1000.0;    
    float hx = map(ori + dir * tx, fft);
    if(hx > 0.0) {
        p = ori + dir * tx;
        return tx;   
    }
    float hm = map(ori, fft);
    for(int i = 0; i < NUM_STEPS; i++) {
        float tmid = mix(tm, tx, hm / (hm - hx));
        p = ori + dir * tmid;
        float hmid = map(p, fft);        
        if(hmid < 0.0) {
            tx = tmid;
            hx = hmid;
        } else {
            tm = tmid;
            hm = hmid;
        }        
        if(abs(hmid) < EPSILON) break;
    }
    return mix(tm, tx, hm / (hm - hx));
}

vec4 color(vec2 coord, float time,  vec2 screenSize, float fft, vec2 uv) {
    // ray
    vec3 ang = vec3(sin(time*3.0)*0.1,sin(time)*0.2+0.3,time);    
    vec3 ori = vec3(0.0,3.5,time*5.0);
    vec3 dir = normalize(vec3(coord,-2.0)); dir.z += length(coord) * 0.14;
    dir = normalize(dir) * fromEuler(ang);

    // tracing
    vec3 p;
    heightMapTracing(ori,dir,p, fft);
    vec3 dist = p - ori;
    float epsilon_nrm  = (0.1 / screenSize.x);
    vec3 n = getNormal(p, dot(dist,dist) * epsilon_nrm);
    vec3 light = normalize(vec3(0.0,1.0,0.8));
             
    // color
    float alpha = 1.0;
    vec4 color = vec4( mix(
        getSkyColor(dir, fft),
        getSeaColor(p,n,light,dir,dist, fft),
    	pow(smoothstep(0.0,-0.02,dir.y),0.2)), alpha);

    if (previewMode) {
        return color;
    }

    // video 
    vec2 tex_uv = uv * 4.0;
    vec4 videoTex = texture(video, tex_uv);
    vec4 prev = texture(prevFrame, tex_uv);
    vec4 prev2 = texture(prevFrame2, tex_uv);
    vec4 prevMix = mix(prev, prev2, msWaited / MS_PER_MEASURE);
    color = mix(color, prevMix, 0.5);
    return mix(color - (fft * 0.01), videoTex + (fft * 0.01), 0.2);
}

void fragment() {
    if (!visibleInScroll){
        discard;
    }
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = -FRAGCOORD.xy / screenSize;
    normalizedCoords *= zoomValue;
    normalizedCoords += pixelCoords_mod;
    
    float wave = amplitude * sin(freqX * UV.x + TIME / freqSlow + UV.y * freqY);
    float wavy_y = clamp(UV.x + wave, 0.0, 1.0);
    float band_f = wavy_y * float(VU_COUNT);
    int bandIdy = int(floor(band_f));
    float bandFract = fract(band_f);
    float fft = mix(freq_data[clamp(bandIdy, 0, VU_COUNT - 1)], freq_data[clamp(bandIdy + 1, 0, VU_COUNT - 1)], bandFract);
    
    vec4 finalColor  = vec4(0.0);

    float time = TIME * 0.1;//* 0.05 + mouseScreenPos.x*0.001;
    finalColor = color(normalizedCoords, time, screenSize, fft, UV);
    finalColor = vec4(pow(finalColor.rgb,vec3(0.8)), 1.0);

    //fade out at the end of the song
    // if (TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    // {
    //     float fadeDuration = songDuration - songFadeOutStart;
    //     float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
    //     finalColor *= 1.0 - fadeProgress; // Fade out the color
    //     finalColor.w = 1.0;
    // }

    COLOR = finalColor;
}