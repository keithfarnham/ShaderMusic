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
const int VU_COUNT = 20;
uniform float[VU_COUNT] freq_data;
uniform float timeToWait = 1.0;
uniform float waitStart = 0.0;
uniform int framesWaited;
uniform bool previewMode = false;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D tex3;
uniform sampler2D tex4;
uniform sampler2D tex5;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 101.0; //95sec song duration + 6sec delay
const float songFadeOutStart = 98.0; //92sec fade start + 6sec delay

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

float sdHexPrism( vec3 p, vec2 h )
{
  const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
  p = abs(p);
  p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
  vec2 d = vec2(
       length(p.xy-vec2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
       p.z-h.y );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
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

mat3 rotation_y(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(c, 0.0, -s),
        vec3(0.0, 1.0, 0.0),
        vec3(s, 0.0, c)
    );
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDir, float maxDist, int maxSteps, float time, out float minDist) {
    float t = 0.0;
    float hit_id = 0.0;
    minDist = 1e6;
    for (int i = 0; i < maxSteps; i++) {
        vec3 p = rayOrigin + rayDir * t;

        mat3 rot2 = rotation_y(TIME * 0.5) * rotation_x(TIME * 0.2);
        vec3 p2 = rot2 * (p - secondBoxOffset);
        float dist = sdHexPrism(p2, boxSize.xy);
        hit_id = 2.0;

        minDist = min(minDist, abs(dist));

        if (dist < 0.001) {
            return vec4(p, float(hit_id));
        }
        t += dist;
        if (t > maxDist) break;
    }
    return vec4(rayOrigin + rayDir * t, 0.0); // No hit
}

vec2 hexprism_face_uv(vec3 p, vec3 n, vec2 hexSize, float prismHeight) {
    vec3 abs_n = abs(n);
    vec2 uv;

    // Cap face (top or bottom)
    if (abs_n.z > abs_n.x && abs_n.z > abs_n.y) {
        // Project XY to [0,1] (hexagon inscribed in unit circle)
        uv = (p.xy / hexSize) * 0.5 + 0.5;
    } else {
        // Side face: unwrap hexagon sides
        // Angle around Z axis
        float angle = atan(p.y, p.x);
        // Map angle to [0,1] for 6 sides
        float side = floor((angle + PI) / (PI / 3.0));
        float u = fract((angle + PI) / (2.0 * PI / 6.0)); // [0,1] along the side
        float v = (p.z / prismHeight) * 0.5 + 0.5;        // [0,1] along height
        uv = vec2(side / 6.0 + u / 6.0, v);
    }
    return uv;
}

vec3 estimate_normal_hexprism(vec3 p) {
    float eps = 0.001;
    float dx = sdHexPrism(p + vec3(eps, 0.0, 0.0), boxSize.xy * 0.5) - sdHexPrism(p - vec3(eps, 0.0, 0.0), boxSize.xy * 0.5);
    float dy = sdHexPrism(p + vec3(0.0, eps, 0.0), boxSize.xy * 0.5) - sdHexPrism(p - vec3(0.0, eps, 0.0), boxSize.xy * 0.5);
    float dz = sdHexPrism(p + vec3(0.0, 0.0, eps), boxSize.xy * 0.5) - sdHexPrism(p - vec3(0.0, 0.0, eps), boxSize.xy * 0.5);
    return normalize(vec3(dx, dy, dz));
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

    vec3 color = vec3(paletteColor1.x + cos(TIME), paletteColor1.y + sin(TIME), paletteColor1.z + sin(TIME * 0.5));
    color = clamp(color, 0.0, 0.2);
    float minDist;
    vec4 marchResult = raymarch(rayOrigin, rayDir, maxDistance, 32, TIME, minDist);
    float hit = marchResult.w;

    float edgeAlpha = 1.0 - smoothstep(0.0, 10.0, minDist);

    if (hit > 0.1) {
        vec3 hitPos = marchResult.xyz;
        vec3 normal;
        vec2 face_uv;

        mat3 rot2 = rotation_y(TIME * 0.5) * rotation_x(TIME * 0.2);
        mat3 inv_rot2 = transpose(rot2);
        vec3 local_hit_hex = inv_rot2 * (hitPos - secondBoxOffset);
        float s = sin(TIME);
        normal = estimate_normal_hexprism(local_hit_hex);
        face_uv = hexprism_face_uv(local_hit_hex, normal, boxSize.xy, boxSize.z);
        face_uv.y = 1.0 - face_uv.y;
        vec3 col2 = texture(tex3, face_uv).rgb;
        col2 = mix(col2, texture(tex3, face_uv).rgb, s);
        col2 = mix(col2, palette(fft), 0.5);
        colorOutput.xyz = clamp(col2, 0.0, 0.8);

        colorOutput.w = edgeAlpha;
    } else {
        colorOutput.xyz = vec3(1.0, 0.0, 1.0);
        colorOutput.w = 0.0;
    }

    return colorOutput;
}

vec4 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, float fft) {
    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    rayDir += rayDirMod;
    vec3 currentRayOrigin = rayOrigin;
    currentRayOrigin += rayOriginMod;
    vec4 planeColor = plane(rayOrigin, rayDir, pixelCoord, fft);

    return planeColor;
}

void fragment() {
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

    float wave = 0.2 * sin(20.0 * UV.x + TIME * 0.5 + UV.y * 10.0);
    float wavy_y = clamp(UV.y + wave, 0.0, 1.0);
    int bandIdy = int(floor(wavy_y * float(VU_COUNT)));
    float fft = freq_data[clamp(bandIdy, 0, VU_COUNT)];

    vec4 background = vec4(0.0, 0.0, 0.0, 0.1);
    background.xyz = backgroundColor + palette(fft);
    vec2 tex_uv = normalizedCoords;
    if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
        background = background;//backgroundColor + palette(fft);
    }
    else {
        float s = sin(TIME);
        vec4 img1 = texture(tex1, tex_uv);
        vec4 img2 = texture(tex2, tex_uv);
        vec4 img3 = texture(tex3, tex_uv);
        vec4 img4 = texture(tex4, tex_uv);
        vec4 img5 = texture(tex5, tex_uv);
        background.xyz = TIME > 30.0 ? mix(background.xyz, img2.rgb, 0.2 * s) : mix(background.xyz, img3.rgb, 0.8 * s);
        background.xyz = TIME > 30.0 ? mix(background.xyz, img5.rgb, 0.2 * s) : mix(background.xyz, img4.rgb, 0.2 * s);
        if (TIME > 60.0){
            background.xyz = mix(background.xyz, img1.rgb, 0.2 * s);
        }
        // 8 beats at 110 BPM: 60/110 = 0.54545s per beat
        float beat_length = 60.0 / 110.0;
        float beats16 = 16.0 * beat_length;
        float t = mod(TIME, beats16);
        if (t < beats16 * 0.5) { // first 8 beats (half of 16)
            background.xyz *= fft;
        }
        background.w = 0.8;
    }

    // Fixed camera setup
    rayOrigin = vec3(0.0) + rayOriginMod;
    vec3 rayDir = normalize(vec3(normalizedCoords, 1.5));
    vec4 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, fft);

    finalColor = mix(background, finalColor, finalColor.a - finalAlphaReduction);

    //fade out at the end of the song
    if (!previewMode && TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    {
        float fadeDuration = songDuration - songFadeOutStart;
        float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
        finalColor *= 1.0 - fadeProgress; // Fade out the color
        finalColor.w = 1.0;
    }

    COLOR = finalColor;
}