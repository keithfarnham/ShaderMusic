shader_type canvas_item;

//based on shader by mrange https://www.shadertoy.com/view/MfjyWK
//audio visualization/modulation stuff based on https://godotshaders.com/shader/spectrum-analyzer/

uniform float planeDist = 0.5;
uniform float furthest = 16.0;
uniform float fadeFrom = 8.0;
uniform float fadeOutMod = 0.0;
uniform float radius = 0.5;
uniform float antiAliasBaseValue = 3.0;
uniform float slowVal = 2.0;
uniform float rayDepth = 1.75;
uniform vec3 rayDirMod = vec3(0.0);
uniform vec3 rayOriginMod = vec3(0.0);
uniform float planeZMod = 0.0;
uniform float zoomValue = 1.0;
uniform float pixelCoords_X_mod = 0.0;
uniform float pixelCoords_Y_mod = 0.0;
uniform vec2 pathA = vec2(0.0);
uniform vec2 pathB = vec2(0.0);
uniform bool useUV = false;
const int VU_COUNT = 30;
uniform float[VU_COUNT] freq_data;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 92.0; //84sec song duration + 3sec delay + 5 sec on frontend
const float songFadeOutStart = 91.0; //84sec fade start + 3sec delay + 5 sec on frontend

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
    return mix(vec3(0.8, 0.8, 0.8), vec3(0.0, 0.0, 0.0), t);
}

// from Inigo Quilez: https://iquilezles.org/articles/distfunctions2d/
float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sdChamferBox(vec2 p, vec2 b, float chamfer )
{
    p = abs(p)-b;

    p = (p.y>p.x) ? p.yx : p.xy;
    p.y += chamfer;
    
    const float k = 1.0-sqrt(2.0);
    if( p.y<0.0 && p.y+p.x*k<0.0 )
        return p.x;
    
    if( p.x<p.y )
        return (p.x+p.y)*sqrt(0.5);    
    
    return length(p);
}

vec4 plane(vec3 planePosition, vec3 normalizedPlanePosition, float planeDistance, vec3 centralPlanePosition, vec3 offsetPosition, float planeIndex, vec2 uv) {
    float freqMod = useUV ? uv.x : planePosition.y;
    float fft = freq_data[int(freqMod * float(VU_COUNT))];

    if (fft <= 0.0)
    {
        // if there's no audio playing return black for color, shader will start up when audio starts
        return vec4(0.0);
    }

    float antiAliasingFactor = (antiAliasBaseValue * planeDistance * distance(planePosition.xy, normalizedPlanePosition.xy));
    vec4 colorOutput = vec4(0.0);
    vec2 adjustedPlanePosition = planePosition.xy;
    vec2 box = vec2(0.8,0.4);
    float circleDist = sdChamferBox(adjustedPlanePosition / 2.0, box, radius);

    float grad = clamp(0.2 + 0.8 * (adjustedPlanePosition.y + 1.0) * 0.5, 0.0, 1.0);
    vec3 outsideColor = mix(vec3(0.0), vec3(0.7), fft/2.0);
    vec3 insideColor = palette(planeIndex + 2.0 / fft/2.0);

    float edgeWidth = 50.0;

    if (circleDist > 0.0) {
        colorOutput.xyz = outsideColor;
        colorOutput.w = 0.1;
    } else {
        colorOutput.xyz = insideColor;
        colorOutput.w = 1.0 - smoothstep(-edgeWidth, 0.0, circleDist);
    }
    return colorOutput / 2.0;
}

vec4 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, vec2 pixelSize, vec2 uv) {
    float pixelLength = length(pixelCoord);
    vec2 nextPixelCoord = pixelCoord + 1.0 / pixelSize;
    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    rayDir += rayDirMod * sin(0.5 + 0.5 * TIME);
    vec3 nextRayDir = normalize(nextPixelCoord.x * rightVector + nextPixelCoord.y * upVector + rayDepth * forwardVector);
    float planeIndex = floor(rayOrigin.z / planeDist);

    vec4 accumulatedColor = vec4(0.0);

    vec3 currentRayOrigin = rayOrigin;
    currentRayOrigin += rayOriginMod;
    float accumulatedPlaneDist = 0.0;

    for (float planeStep = 1.0; planeStep <= furthest; ++planeStep) {
        if (accumulatedColor.w > 0.9) {
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
            float fadeOutReflection = smoothstep(0.0, planeDist, depthDifference);

            vec4 planeColor = plane(planeIntersection, nextPlaneIntersection, accumulatedPlaneDist, centralPlaneIntersection, offsetPosition, planeIndex + planeStep, uv);

            float cameraFade = smoothstep(planeDist + fadeOutMod , 0.0, planeIntersection.z - rayOrigin.z);
            planeColor.w *= cameraFade;

            planeColor.w *= fadeOutFactor * fadeInFactor + (planeIndex * fadeFrom);
            if (planeColor.w > 0.001) {
                accumulatedColor = alphaBlend(planeColor, accumulatedColor);
            }
            currentRayOrigin = planeIntersection;
        }
    }

    return accumulatedColor;
}

void fragment() {
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;

    vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
    normalizedCoords -= 0.5;
    normalizedCoords.x *= screenSize.x / screenSize.y;
    normalizedCoords *= zoomValue;
    normalizedCoords += vec2(pixelCoords_X_mod, pixelCoords_Y_mod);

    float timeOffset = planeDist * TIME / slowVal;

    vec3 rayOrigin = offset(timeOffset);
    vec3 rayOriginDerivative = doffset(timeOffset);
    vec3 rayOriginSecondDerivative = ddoffset(timeOffset);

    vec3 forward = normalize(rayOriginDerivative);
    vec3 right = normalize(cross(UP_VECTOR.xyx + rayOriginSecondDerivative, forward));
    vec3 up = -cross(forward, right);

    vec2 uv = UV;
    vec4 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, screenSize, uv);

    finalColor *= 1.5;

    //fade out at the end of the song
    if (TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    {
        float fadeDuration = songDuration - songFadeOutStart;
        float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
        finalColor *= 1.0 - fadeProgress;
    }

    finalColor = sqrt(finalColor);
    COLOR = finalColor;
}