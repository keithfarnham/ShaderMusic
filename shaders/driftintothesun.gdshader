shader_type canvas_item;

//based on shader by mrange https://www.shadertoy.com/view/MfjyWK
//audio visualization/modulation stuff based on https://godotshaders.com/shader/spectrum-analyzer/

uniform float planeDist = 0.5;
uniform float furthest = 16.0;
uniform float fadeFrom = 8.0;
uniform float circleRadius = 0.1;
uniform float antiAliasBaseValue = 3.0;
uniform float pixelCoords_X_mod = 0.0;
uniform float pixelCoords_Y_mod = 0.0;
uniform bool previewMode = false;

const int VU_COUNT = 1;
uniform float[VU_COUNT] freq_data;

const vec2 PATH_A = vec2(0.31, 0.41);
const vec2 PATH_B = vec2(1.0, sqrt(0.5));
const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 188.0; //180sec song duration + 3sec delay + 5 sec on frontend
const float fadeOutStart = 182.0; //174.0 sec fade start + 3sec delay + 5 sec on frontend

// License: Unknown, author: Matt Taylor (https://github.com/64), found: https://64.github.io/tonemapping/
vec3 aces_approx(vec3 colorVec) {
    colorVec = max(colorVec, 0.0);
    colorVec *= 0.6;
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((colorVec * (a * colorVec + b)) / (colorVec * (c * colorVec + d) + e), 0.0, 1.0);
}

vec3 offset(float zPos) {
    return vec3(PATH_B * sin(PATH_A * zPos), zPos);
}

vec3 doffset(float zPos) {
    return vec3(PATH_A * PATH_B * cos(PATH_A * zPos), 1.0);
}

vec3 ddoffset(float zPos) {
    return vec3(-PATH_A * PATH_A * PATH_B * sin(PATH_A * zPos), 0.0);
}

vec4 alphaBlend(vec4 back, vec4 front) {
    // Based on: https://en.wikipedia.org/wiki/Alpha_compositing
    float w = front.w + back.w * (1.0 - front.w);
    vec3 xyz = (front.xyz * front.w + back.xyz * back.w * (1.0 - front.w)) / w;
    return w > 0.0 ? vec4(xyz, w) : vec4(0.0);
}

vec3 palette(float n) {
    return 0.5 + 0.5 * sin(vec3(0.0, 1.0, 2.0) + n);
}

// from Inigo Quilez: https://iquilezles.org/articles/distfunctions2d/
float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

vec4 plane(vec3 planePosition, vec3 normalizedPlanePosition, float planeDistance, vec3 centralPlanePosition, vec3 offsetPosition, float planeIndex, vec2 uv) {
    float fft = freq_data[int(uv.x * float(VU_COUNT))];
    // if (!previewMode && fft <= 0.0)
    // {
    //     // if there's no audio playing return black for color, shader will start up when audio starts
    //     return vec4(0.0);
    // }
    float timeModulation = 0.5 + 0.5 * sin(TIME); // Oscillates between 0.0 and 1.0 over time
    //modulating the aa with time and fft
    float antiAliasingFactor = fft * timeModulation * (antiAliasBaseValue * planeDistance * distance(planePosition.xy, normalizedPlanePosition.xy));
    vec4 colorOutput = vec4(0.0);
    vec2 adjustedPlanePosition = planePosition.xy;

    float radius = circleRadius + fft; //modulating circle radius with fft
    float circleDistance = sdCircle(adjustedPlanePosition / 2.0, radius); // Adjusted position and radius for proper scaling

    colorOutput.xyz = palette(0.5 * planeIndex + 2.0 * circleDistance);
    colorOutput.xyz *= fft + 1.0; //modulating color with fft
    colorOutput.w = smoothstep(antiAliasingFactor, -antiAliasingFactor, circleDistance);
    return colorOutput;
}

vec3 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, vec2 pixelSize, vec2 uv) {
    float pixelLength = length(pixelCoord);
    vec2 nextPixelCoord = pixelCoord + 1.0 / pixelSize;
    float rayDepth = 1.75;

    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    vec3 nextRayDir = normalize(nextPixelCoord.x * rightVector + nextPixelCoord.y * upVector + rayDepth * forwardVector);

    float planeIndex = floor(rayOrigin.z / planeDist);

    vec4 accumulatedColor = vec4(0.0);

    vec3 currentRayOrigin = rayOrigin;
    float accumulatedPlaneDist = 0.0;

    for (float planeStep = 1.0; planeStep <= furthest; ++planeStep) {
        if (accumulatedColor.w > 0.95) {
            break;
        }
        float planeZ = planeDist * planeIndex + planeDist * planeStep;

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

            float reflectionIntensity = mix(1.0, 0.9, fadeOutReflection * fadeInFactor);

            vec4 planeColor = plane(planeIntersection, nextPlaneIntersection, accumulatedPlaneDist, centralPlaneIntersection, offsetPosition, planeIndex + planeStep, uv);

            // Reduce alpha for the nearest plane step
            if (planeStep == 1.0) {
                planeColor.w *= 0.5;
            }

            planeColor.w *= fadeOutFactor * fadeInFactor;
            accumulatedColor = alphaBlend(planeColor, accumulatedColor);
            accumulatedColor.w *= reflectionIntensity;
            currentRayOrigin = planeIntersection;
        }
    }

    return accumulatedColor.xyz * accumulatedColor.w;
}

void fragment() {
    vec2 screenSize = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 normalizedCoords = FRAGCOORD.xy / screenSize;
    vec2 adjustedCoords = -1.0 + 2.0 * normalizedCoords;
    vec2 pixelCoords = adjustedCoords;

    pixelCoords.x += pixelCoords_X_mod;
    pixelCoords.y += pixelCoords_Y_mod;

    // dividing by slow_val to slow down movement
    float slow_val = 2.0;
    float timeOffset = planeDist * TIME / slow_val;

    vec3 rayOrigin = offset(timeOffset);
    vec3 rayOriginDerivative = doffset(timeOffset);
    vec3 rayOriginSecondDerivative = ddoffset(timeOffset);

    vec3 forward = normalize(rayOriginDerivative);
    vec3 right = normalize(cross(UP_VECTOR.xyx + rayOriginSecondDerivative, forward));
    vec3 up = cross(forward, right);

    vec2 uv = UV;

    vec3 finalColor = color(forward, right, up, rayOrigin, pixelCoords, screenSize, uv);

    finalColor *= 1.5;

    //fade out at the end of the song
    // float fadeDuration = songDuration - fadeOutStart;
    // if (!previewMode && TIME >= fadeOutStart)
    // {
    //     float fadeProgress = clamp((TIME - fadeOutStart) / fadeDuration, 0.0, 1.0);
    //     finalColor *= 1.0 - fadeProgress; // Fade out the color
    // }

    COLOR = vec4(finalColor, 1.0);
}