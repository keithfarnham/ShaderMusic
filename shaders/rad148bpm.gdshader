shader_type canvas_item;

//audio visualization/modulation stuff based on https://godotshaders.com/shader/spectrum-analyzer/

uniform float planeDist = 0.5;
uniform float furthest = 16.0;
uniform float fadeFrom = 8.0;
uniform float fadeOutMod = 0.0;
uniform float shapeRadius = 0.5;
uniform float finalAlphaReduction = 0.0;
uniform float antiAliasBaseValue = 3.0;
uniform float slowVal = 2.0;
uniform float rayDepth = 1.75;
uniform vec3 rayDirMod = vec3(0.0);
uniform vec3 rayOriginMod = vec3(0.0);
uniform float planeZMod = 0.0;
uniform float zoomValue = 1.0;
uniform float finalColorMod = 1.5;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform vec2 pathA = vec2(0.0);
uniform vec2 pathB = vec2(0.0);
uniform vec3 paletteColor1 = vec3(0.0);
uniform vec3 paletteColor2 = vec3(0.0);
const int VU_COUNT = 100;
uniform float[VU_COUNT] freq_data;
uniform sampler2D video;
uniform bool visibleInScroll = true;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 76.0; //73sec song duration + 3sec delay
const float songFadeOutStart = 74.0; //71sec fade start + 3sec delay

vec3 offset(float zPos) {
    return vec3(pathB * sin(pathA * zPos), zPos);
}

vec3 doffset(float zPos) {
    return vec3(pathA * pathB * cos(pathA * zPos), 1.0);
}

vec3 ddoffset(float zPos) {
    return vec3(-pathA * pathA * pathB * sin(pathA * zPos), 0.0);
}

vec3 palette(float n) {
    float t = 0.5 + 0.5 * sin(n);
    return mix(paletteColor1, paletteColor2, t);
}


vec4 plane(vec2 pixelCoord, float fft) {
    // if (fft <= 0.0)
    // {
    //     // if there's no audio playing return black for color, shader will start up when audio starts
    //     return vec4(0.0, 0.0, 0.0, 1.0);
    // }

    vec4 colorOutput = vec4(0.0);
    vec2 tex_uv = pixelCoord;
    if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
        return vec4(0.0);
    }
    vec4 tex = vec4(0.0);
    tex = texture(video, tex_uv);
    vec3 color = vec3(paletteColor1.x + cos(TIME), paletteColor1.y + sin(TIME), paletteColor1.z + sin(TIME * 0.5));
    color = clamp(color, 0.0, 0.5);
    colorOutput.xyz = clamp(tex.rgb + color, 0.0, 0.5);
    colorOutput.w = all(lessThan(tex.rgb, vec3(0.2))) ? 0.8 : 0.5;
    return colorOutput;
}

vec4 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, float fft) {
    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    rayDir += rayDirMod;
    vec3 currentRayOrigin = rayOrigin;
    currentRayOrigin += rayOriginMod;
    vec3 planeIntersection = currentRayOrigin + rayDir * planeDist;
    vec4 planeColor = plane(pixelCoord, fft);

    return planeColor;
}

void fragment() {
    if (!visibleInScroll){
        discard;
    }
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
    normalizedCoords *= zoomValue;
    normalizedCoords += pixelCoords_mod;

    float timeOffset = planeDist * TIME / slowVal;

    vec3 rayOrigin = offset(timeOffset);
    vec3 rayOriginDerivative = doffset(timeOffset);
    vec3 rayOriginSecondDerivative = ddoffset(timeOffset);

    vec3 forward = normalize(rayOriginDerivative);
    vec3 right = normalize(cross(UP_VECTOR.xyx + rayOriginSecondDerivative, forward));
    vec3 up = -cross(forward, right);

    float wave = 0.5 * sin(1.0 * UV.x + TIME / 4.0 + UV.y * 2.0);
    float wavy_y = clamp(UV.x + wave, 0.0, 1.0);
    int bandIdy = int(floor(wavy_y * float(VU_COUNT)));
    float fft = freq_data[clamp(bandIdy, 0, VU_COUNT)];

    vec4 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, fft);

    finalColor.xyz *= finalColorMod;

    //fade out at the end of the song
    // if (TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    // {
    //     float fadeDuration = songDuration - songFadeOutStart;
    //     float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
    //     finalColor *= 1.0 - fadeProgress; // Fade out the color
    //     finalColor.w = 1.0;
    // }
    vec4 background = vec4(0.0, 0.0, 0.0, 0.1);
    background.xyz = palette(fft);
    finalColor.xyz -= fft *0.1;
    finalColor = mix(background, finalColor, finalColor.a - finalAlphaReduction);
    COLOR = finalColor;
}