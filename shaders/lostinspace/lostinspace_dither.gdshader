shader_type canvas_item;

//based on shader by FabriceNeyret2 here: https://www.shadertoy.com/view/MllSzj
const int VU_COUNT = 20;
uniform float[VU_COUNT] freq_data;
uniform float zoomValue = 1.0;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform sampler2D video;
uniform sampler2D noiseTexture;
uniform float songDuration;
uniform bool previewMode = false;
uniform bool visibleInScroll = true;

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
        fragColor =   texture(video, normalizedCoords);
    }
    else
    {
        vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
        vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
        normalizedCoords *= zoomValue;
        normalizedCoords += pixelCoords_mod;

        vec4 vidTex = texture(video, normalizedCoords);
        vec4 o = step(texture(noiseTexture, UV).r, vidTex);
        float mixAmount = mod(TIME, songDuration) / songDuration;
        o = mix(vidTex, o, mixAmount);

        fragColor = o;
        
    }
    COLOR = fragColor;
}