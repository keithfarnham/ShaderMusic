shader_type canvas_item;

//based on shader by mrange https://www.shadertoy.com/view/MfjyWK
//audio visualization/modulation stuff based on https://godotshaders.com/shader/spectrum-analyzer/

uniform float planeDist = 0.5;
uniform float furthest = 16.0;
uniform float fadeFrom = 8.0;
uniform float tunnelWidth = 0.1;
uniform float tunnelHeight = 0.5;
uniform float antiAliasBaseValue = 3.0;
uniform float slowVal = 2.0;
uniform float rayDirMod = 0.0;
uniform vec3 rayOriginMod = vec3(0.0);
uniform float planeZMod = 0.0;
uniform float depthMod = 0.0;
uniform float pixelCoords_X_mod = 0.0;
uniform float pixelCoords_Y_mod = 0.0;
uniform float pathA_X = 0.0;
uniform float pathA_Y = 0.0;
uniform bool useUV = false;
const int VU_COUNT = 100;
uniform float[VU_COUNT] freq_data;
uniform bool previewMode = false;

const vec2 PATH_A = vec2(0.31, 0.41);
const vec2 PATH_B = vec2(1.0, sqrt(0.5));
const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 89.0; //81sec song duration + 3sec delay + 5 sec on frontend
const float songFadeOutStart = 88.0; // 80 sec fade start + 3sec delay + 5 sec on frontend

vec3 offset(float zPos) {
    vec2 pathA = vec2(pathA_X, pathA_Y);
    return vec3(PATH_B * sin(pathA * zPos), zPos);
}

vec3 doffset(float zPos) {
    vec2 pathA = vec2(pathA_X, pathA_Y);
    return vec3(pathA * PATH_B * cos(pathA * zPos), 1.0);
}

vec3 ddoffset(float zPos) {
    vec2 pathA = vec2(pathA_X, pathA_Y);
    return vec3(-pathA * pathA * PATH_B * sin(pathA * zPos), 0.0);
}

vec4 alphaBlend(vec4 back, vec4 front) {
    // Based on: https://en.wikipedia.org/wiki/Alpha_compositing
    float w = front.w + back.w * (1.0 - front.w);
    vec3 xyz = (front.xyz * front.w + back.xyz * back.w * (1.0 - front.w)) / w;
    return w > 0.0 ? vec4(xyz, w) : vec4(0.0);
}

vec3 palette(float n) {
    // Cyan: (0.0, 1.0, 1.0), Red: (1.0, 0.0, 0.0)
    float t = 0.5 + 0.5 * sin(n); // t in [0,1]
    return mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 0.0, 0.0), t);
}

// from Inigo Quilez: https://iquilezles.org/articles/distfunctions2d/
float dot2( vec2 v ) { return dot(v,v); }
float sdTunnel( in vec2 p, in vec2 wh )
{
    p.x = abs(p.x); p.y = -p.y;
    vec2 q = p - wh;

    float d1 = dot2(vec2(max(q.x,0.0),q.y));
    q.x = (p.y>0.0) ? q.x : length(p)-wh.x;
    float d2 = dot2(vec2(q.x,max(q.y,0.0)));
    float d = sqrt( min(d1,d2) );

    return (max(q.x,q.y)<0.0) ? -d : d;
}

vec4 plane(vec3 planePosition, vec3 normalizedPlanePosition, float planeDistance, vec3 centralPlanePosition, vec3 offsetPosition, float planeIndex, vec2 uv) {
    float freqMod = useUV ? uv.x : planePosition.y;
    float band = clamp(freqMod * float(VU_COUNT - 1), 0.0, float(VU_COUNT - 1));
    int bandIdx = int(floor(band));
    float bandFrac = fract(band);
    float fft = mix(freq_data[bandIdx], freq_data[min(bandIdx + 1, VU_COUNT - 1)], bandFrac);

    // if (fft <= 0.0 && !previewMode)
    // {
    //     // if there's no audio playing return black for color, shader will start up when audio starts
    //     return vec4(0.0);
    // }

    float antiAliasingFactor = (antiAliasBaseValue * planeDistance * distance(planePosition.xy, normalizedPlanePosition.xy));
    vec4 colorOutput = vec4(0.0);
    vec2 adjustedPlanePosition = planePosition.xy;
    vec2 tunnelWH = vec2(tunnelWidth, tunnelHeight);
    float tunnelDist = sdTunnel(adjustedPlanePosition / 2.0, tunnelWH);

    float grad = clamp(0.2 + 0.8 * (adjustedPlanePosition.y + 1.0) * 0.5, 0.0, 1.0);
    float c = 0.5 + 0.5 * cos(TIME);
    vec3 outsideColor = mix(vec3(0.2, 0.0, 0.0 + c), vec3(1.0, 0.2 + c, 0.2), grad);
    vec3 insideColor = palette(planeIndex + 2.0 + fft);
    colorOutput.xyz = (tunnelDist > 0.0) ? outsideColor: insideColor;
    colorOutput.w = 1.0 - smoothstep(-antiAliasingFactor, antiAliasingFactor, abs(tunnelDist));
    return colorOutput;
}

vec3 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, vec2 pixelSize, vec2 uv) {
    float pixelLength = length(pixelCoord);
    vec2 nextPixelCoord = pixelCoord + 1.0 / pixelSize;
    float rayDepth = 1.75;

    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    rayDir += vec3(rayDirMod) * sin(0.5 + 0.5 * TIME);
    vec3 nextRayDir = normalize(nextPixelCoord.x * rightVector + nextPixelCoord.y * upVector + rayDepth * forwardVector);
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
        float centralPlaneDist = (planeZ - currentRayOrigin.z) / forwardVector.z;

        {
            vec3 planeIntersection = currentRayOrigin + rayDir * linearPlaneDist;
            vec3 nextPlaneIntersection = currentRayOrigin + nextRayDir * nextPlaneDist;
            vec3 centralPlaneIntersection = currentRayOrigin + forwardVector * centralPlaneDist;

            accumulatedPlaneDist += linearPlaneDist;

            vec3 offsetPosition = offset(planeIntersection.z);

            float depthDifference = planeIntersection.z - rayOrigin.z;
            float fadeInFactor = smoothstep(planeDist * furthest, planeDist * fadeFrom, depthDifference);
            float fadeOutFactor = smoothstep(0.0, planeDist * 0.1, depthDifference);
            float fadeOutReflection = smoothstep(0.0, planeDist * 1.0, depthDifference);

            vec4 planeColor = plane(planeIntersection, nextPlaneIntersection, accumulatedPlaneDist, centralPlaneIntersection, offsetPosition, planeIndex + planeStep, uv);

            planeColor.w *= fadeOutFactor * fadeInFactor + (planeIndex * fadeFrom);
            accumulatedColor = alphaBlend(planeColor, accumulatedColor);
            currentRayOrigin = planeIntersection;
        }
    }

    return accumulatedColor.xyz;
}

void fragment() {
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
    normalizedCoords -= 0.5;
    normalizedCoords *= screenSize / 100.0;
    normalizedCoords += vec2(pixelCoords_X_mod, pixelCoords_Y_mod);

    float timeOffset = planeDist * TIME / slowVal;

    vec3 rayOrigin = offset(timeOffset);
    vec3 rayOriginDerivative = doffset(timeOffset);
    vec3 rayOriginSecondDerivative = ddoffset(timeOffset);

    vec3 forward = normalize(rayOriginDerivative);
    vec3 right = normalize(cross(UP_VECTOR.xyx + rayOriginSecondDerivative, forward));
    vec3 up = -cross(forward, right);

    vec2 uv = UV;
    vec3 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, screenSize, uv);

    finalColor *= 1.5;

    //fade out at the end of the song
    // if (TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    // {
    //     float fadeDuration = songDuration - songFadeOutStart;
    //     float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
    //     finalColor *= 1.0 - fadeProgress; // Fade out the color
    // }

    finalColor = sqrt(finalColor);
    COLOR = vec4(finalColor, 1.0);
}