shader_type canvas_item;

//based on shader by mrange https://www.shadertoy.com/view/MfjyWK
//audio visualization/modulation stuff based on https://godotshaders.com/shader/spectrum-analyzer/

uniform float planeDist = 0.5;
uniform float furthest = 16.0;
uniform float fadeFrom = 8.0;
uniform float fadeOutMod = 0.0;
uniform float shapeRadius = 0.5;
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
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform sampler2D texture3;
uniform sampler2D texture4;
uniform bool previewMode = false;
uniform bool visibleInScroll = true;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 139.0; //136sec song duration + 3sec delay
const float songFadeOutStart = 136.0; //133sec fade start + 3sec delay

vec3 offset(float zPos) {
    return vec3(pathB * sin(pathA * zPos), zPos);
}

vec3 doffset(float zPos) {
    return vec3(pathA * pathB * cos(pathA * zPos), 1.0);
}

vec3 ddoffset(float zPos) {
    return vec3(-pathA * pathA * pathB * sin(pathA * zPos), 0.0);
}

vec4 alphaBlend(vec4 back, vec4 front) {
    // Based on: https://en.wikipedia.org/wiki/Alpha_compositing
    float w = front.w + back.w * (1.0 - front.w);
    vec3 xyz = (front.xyz * front.w + back.xyz * back.w * (1.0 - front.w)) / w;
    return w > 0.0 ? vec4(xyz, w) : vec4(0.0);
}

vec3 palette(float n) {
    float t = 0.5 + 0.5 * sin(n);
    return mix(paletteColor1, paletteColor2, t);
}

vec4 plane(vec3 planePosition, vec3 normalizedPlanePosition, float planeDistance, vec2 pixelCoord, vec3 offsetPosition, float planeIndex, float fft) {
    // if (!previewMode && fft <= 0.0)
    // {
    //     // if there's no audio playing return black for color, shader will start up when audio starts
    //     return vec4(0.0, 0.0, 0.0, 1.0);
    // }

    float antiAliasingFactor = (antiAliasBaseValue * planeDistance * distance(planePosition.xy, normalizedPlanePosition.xy));
    vec4 colorOutput = vec4(0.0);
    vec2 adjustedPlanePosition = planePosition.xy;
    vec2 tex_uv = (adjustedPlanePosition * -0.25);
    tex_uv.x *= -0.5;
    if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
        return vec4(0.0);
    }

    tex_uv = clamp(tex_uv, 0.0, 1.0);
    vec4 tex = vec4(0.0);
    switch(int(mod(planeIndex, 4.0)))
    {
        case 0:
            tex = texture(texture1, tex_uv);
            break;
        case 1:
            tex = texture(texture2, tex_uv);
            break;
        case 2:
            tex = texture(texture3, tex_uv);
            break;
        case 3:
            tex = texture(texture4, tex_uv);
            break;
        default:
            tex = texture(texture1, tex_uv);
            break;
    }
    vec3 color = vec3(paletteColor1.x + cos(TIME), paletteColor1.y + sin(TIME), paletteColor1.z + sin(TIME * 0.5));
    colorOutput.xyz = tex.rgb;
    float edge_fade = 1.0 - max(abs(tex_uv.x - 0.5) * 2.0, abs(tex_uv.y - 0.5) * 2.0);
    colorOutput.w = clamp(edge_fade, 0.0, 1.0);
    return colorOutput;
}

vec4 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, vec2 screenSize, float fft) {
    float pixelLength = length(pixelCoord);
    vec2 nextPixelCoord = pixelCoord + 1.0 / screenSize;

    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    rayDir += rayDirMod;
    rayDir.x += 0.1 * sin(TIME * 0.5);
    rayDir.y += 0.2 * cos(TIME * 0.1);
    vec3 nextRayDir = normalize(nextPixelCoord.x * rightVector + nextPixelCoord.y * upVector + rayDepth * forwardVector);
    nextRayDir.x += 0.1 * sin(TIME * 0.5);
    nextRayDir.y += 0.2 * cos(TIME * 0.1);
    float planeIndex = floor(rayOrigin.z / planeDist);

    vec4 accumulatedColor = vec4(0.0);

    vec3 currentRayOrigin = rayOrigin;
    currentRayOrigin += rayOriginMod;
    float accumulatedPlaneDist = 0.0;

    for (float planeStep = 1.0; planeStep <= furthest; ++planeStep) {
        if (accumulatedColor.w > 0.95) {
            break;
        }
        float planeZ = planeDist * planeIndex + planeDist * planeStep;
        planeZ += planeZMod;
        float linearPlaneDist = (planeZ - currentRayOrigin.z) / rayDir.z;
        float nextPlaneDist = (planeZ - currentRayOrigin.z) / nextRayDir.z;

        {
            vec3 planeIntersection = currentRayOrigin + rayDir * linearPlaneDist;
            vec3 nextPlaneIntersection = currentRayOrigin + nextRayDir * nextPlaneDist;

            accumulatedPlaneDist += linearPlaneDist;

            vec3 offsetPosition = offset(planeIntersection.z);

            float depthDifference = planeIntersection.z - rayOrigin.z;
            float fadeInFactor = smoothstep(planeDist * furthest, planeDist * fadeFrom, depthDifference);
            float fadeOutFactor = smoothstep(0.0, planeDist * 0.001, depthDifference);

            vec4 planeColor = plane(planeIntersection, nextPlaneIntersection, accumulatedPlaneDist, pixelCoord, offsetPosition, planeIndex + planeStep, fft);

            accumulatedColor = alphaBlend(planeColor, accumulatedColor);
            currentRayOrigin = planeIntersection;
        }
    }

    return accumulatedColor;
}

void fragment() {
    if (!visibleInScroll){
        discard;
    }
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
    normalizedCoords -= 0.5;
    normalizedCoords *= screenSize / 100.0;
    normalizedCoords *= zoomValue;
    normalizedCoords += pixelCoords_mod;

    float timeOffset = planeDist * TIME / slowVal;

    vec3 rayOrigin = offset(timeOffset);
    vec3 rayOriginDerivative = doffset(timeOffset);
    vec3 rayOriginSecondDerivative = ddoffset(timeOffset);

    vec3 forward = normalize(rayOriginDerivative);
    vec3 right = normalize(cross(UP_VECTOR.xyx + rayOriginSecondDerivative, forward));
    vec3 up = -cross(forward, right);

    float wave = 0.5 * sin(40.0 * UV.x + TIME / 4.0 + UV.y * 20.0);
    float wavy_y = clamp(UV.x + wave, 0.0, 1.0);
    int bandIdy = int(floor(wavy_y * float(VU_COUNT)));
    float fft = freq_data[clamp(bandIdy, 0, VU_COUNT)];

    vec4 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, screenSize, fft);

    finalColor.xyz *= finalColorMod;

    //fade out at the end of the song
    // if (!previewMode && TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    // {
    //     float fadeDuration = songDuration - songFadeOutStart;
    //     float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
    //     finalColor *= 1.0 - fadeProgress; // Fade out the color
    //     finalColor.w = 1.0;
    // }

    vec4 background = vec4(0.0, 0.0, 0.0, 0.5);
    background.xyz = palette(fft);
    finalColor.xyz -= fft *0.1;
    finalColor = mix(background, finalColor, finalColor.a);
    COLOR = finalColor;
}