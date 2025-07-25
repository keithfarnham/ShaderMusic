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
uniform float maxDistance = 16.0;
uniform vec3 rayDirMod = vec3(0.0);
uniform vec3 rayOriginMod = vec3(0.0);
uniform float planeZMod = 0.0;
uniform float zoomValue = 1.0;
uniform float finalColorMod = 1.5;
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform float boxRoundness = 0.5;
uniform vec3 boxSize = vec3(0.5, 0.5, 0.5);
uniform vec3 secondBoxOffset = vec3(0.0);
uniform vec2 pathA = vec2(0.0);
uniform vec2 pathB = vec2(0.0);
uniform vec3 paletteColor1 = vec3(0.0);
uniform vec3 paletteColor2 = vec3(0.0);
uniform vec3 backgroundColor = vec3(0.0);
const int VU_COUNT = 10;
uniform float[VU_COUNT] freq_data;
uniform int framesWaited;
uniform sampler2D prevFrame;
uniform sampler2D prevFrame2;
uniform sampler2D video;
uniform bool previewMode = false;
uniform bool visibleInScroll = true;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 114.0; //108sec song duration + 6sec delay
const float songFadeOutStart = 108.0; //102sec fade start + 6sec delay

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

//from inigo quilez https://iquilezles.org/articles/distfunctions/
float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b + r;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

mat3 rotation_y(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(c, 0.0, -s),
        vec3(0.0, 1.0, 0.0),
        vec3(s, 0.0, c)
    );
}

mat3 rotation_x(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, c, -s),
        vec3(0.0, s, c)
    );
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDir, float maxDist, int maxSteps, float rot_x, float rot_y, out float minDist) {
    float t = 0.0;
    int hit_id = 0;
    minDist = 1e6;
    for (int i = 0; i < maxSteps; i++) {
        vec3 p = rayOrigin + rayDir * t;

        // First box (centered, rotating)
        mat3 rot1 = rotation_y(rot_y) * rotation_x(rot_x);
        vec3 p1 = rot1 * p;
        float d1 = sdBox(p1, boxSize);

        // Second box (offset, different size/rotation)
        mat3 rot2 = rotation_y(rot_y + 1.0) * rotation_x(rot_x + 1.0);
        vec3 p2 = rot2 * (p - secondBoxOffset); // Offset in X
        float d2 = sdBox(p2, boxSize * 0.5);

        // Union of both boxes
        float dist = d1;
        hit_id = 1;
        if (d2 < dist) {
            dist = d2;
            hit_id = 2;
        }

        minDist = min(minDist, abs(dist));

        if (dist < 0.001) {
            return vec4(p, float(hit_id));
        }
        t += dist;
        if (t > maxDist) break;
    }
    return vec4(rayOrigin + rayDir * t, 0.0); // No hit
}


vec4 plane(vec3 rayOrigin, vec3 rayDir, vec2 pixelCoord, float fft) {
    // if (fft <= 0.0 && !previewMode)
    // {
    //     // if there's no audio playing return black for color, shader will start up when audio starts
    //     return vec4(0.0, 0.0, 0.0, 1.0);
    // }

    vec4 colorOutput = vec4(0.0);
    vec2 tex_uv = pixelCoord;
    if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
        return vec4(0.0);
    }
    vec4 tex = texture(video, tex_uv);
    vec4 prev = texture(prevFrame, tex_uv);
    vec4 prev2 = texture(prevFrame2, tex_uv);
    prev.rbg = clamp(vec3(prev.r + float(framesWaited) * 0.01, prev.g + float(framesWaited) * 0.02, prev.b - float(framesWaited) * 0.03), 0.0, 0.3 );
    float blend = 0.1 * float(framesWaited);
    prev = alphaBlend(prev, prev2);
    vec4 blended = mix(tex, prev, blend);

    vec3 color = vec3(paletteColor1.x + cos(TIME), paletteColor1.y + sin(TIME), paletteColor1.z + sin(TIME * 0.5));
    color = clamp(color, 0.0, 0.2);
    float minDist;
    vec4 marchResult = raymarch(rayOrigin, rayDir, maxDistance, 32, TIME, TIME * 0.5, minDist);
    float hit = marchResult.w;

    float edgeAlpha = 1.0 - smoothstep(0.0, 10.0, minDist);

    if (hit > 0.1) {
        // normal for shading?
        colorOutput.xyz = clamp(blended.rgb + color, 0.0, 0.7);
        colorOutput.w = edgeAlpha;
    } else {
        colorOutput.xyz = vec3(1.0, 0.0, 1.0);
        colorOutput.w = 0.0;
    }

    return colorOutput;
}

vec4 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, float fft) {
    vec2 normCoord = pixelCoord;
    vec3 rayDir = normalize(normCoord.x * rightVector + normCoord.y * upVector + rayDepth * forwardVector);
    rayDir += rayDirMod;
    vec3 currentRayOrigin = rayOrigin;
    currentRayOrigin += rayOriginMod;
    vec4 planeColor = plane(rayOrigin, rayDir, pixelCoord, fft);

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

    float wave = 0.1 * sin(10.0 * UV.x + TIME / 4.0 + UV.y * 2.0);
    float wavy_y = clamp(UV.x + wave, 0.0, 1.0);
    int bandIdy = int(floor(wavy_y * float(VU_COUNT)));
    float fft = freq_data[clamp(bandIdy, 0, VU_COUNT)];

    vec4 background = vec4(0.0, 0.0, 0.0, 0.1);
    background.xyz = backgroundColor + palette(fft);
    vec2 tex_uv = normalizedCoords;
    if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
        background = background;
    }
    else {
        vec4 tex = texture(video, tex_uv);
        vec4 prev = texture(prevFrame, tex_uv);
        vec4 prev2 = texture(prevFrame2, tex_uv);
        background.xyz = mix(background.xyz, prev2.rgb, 0.5);
        background.xyz = mix(background.xyz, prev.rbg, 0.5);
    }

    // Fixed camera setup
    rayOrigin = vec3(0.0) + rayOriginMod;
    vec3 rayDir = normalize(vec3(normalizedCoords, 1.5));
    vec4 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, fft);

    finalColor = mix(background, finalColor, finalColor.a - finalAlphaReduction);

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