shader_type canvas_item;

//based on shader by FabriceNeyret2 here: https://www.shadertoy.com/view/MllSzj
const int VU_COUNT = 20;
uniform float[VU_COUNT] freq_data;
uniform float zoomValue = 1.0;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform sampler2D mainImage;
uniform sampler2D vid1Image;
uniform sampler2D vid2Image;
uniform sampler2D prevImage;
uniform sampler2D noiseTexture;
uniform float songDuration;
uniform bool previewMode = false;
uniform bool visibleInScroll = true;
uniform bool part2 = true;

void fragment() {
    if (!visibleInScroll) {
        discard;
    }
    vec4 fragColor;
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
    normalizedCoords *= zoomValue;
    normalizedCoords += pixelCoords_mod;

    if (previewMode) {
        fragColor =   texture(mainImage, normalizedCoords);
    }
    else
    {
        float fft = freq_data[int(normalizedCoords.x * float(VU_COUNT))];
        vec4 mainTex = texture(mainImage, normalizedCoords);
       
        if (!part2) {
            vec4 vid1tex = texture(vid1Image, normalizedCoords);
            vid1tex.rgb = vec3(vid1tex.r + sin(TIME * 0.5), vid1tex.g - sin(TIME * 0.5), vid1tex.b * sin(TIME));
            vec4 vid2tex = texture(vid2Image, normalizedCoords);
            vid2tex.rgb = vec3(vid2tex.r - sin(TIME * 0.5), vid2tex.g * sin(TIME * 0.5), vid2tex.b + sin(TIME));
            vec4 mixedVid = mix(vid1tex, vid2tex, 0.5);
            mainTex = mix(mainTex, mixedVid, 0.6);
        }
        
        vec4 o = step(texture(noiseTexture, UV).r, mainTex);
        float mixAmount = mod(TIME, songDuration) / songDuration;
        o = mix(mainTex, o, mixAmount);
        fragColor = o;
        
    }
    COLOR = fragColor;
}