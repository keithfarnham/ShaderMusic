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
uniform vec2 pixelCoords_mod = vec2(0.0);
uniform vec2 pathA = vec2(0.0);
uniform vec2 pathB = vec2(0.0);
uniform vec3 paletteColor1 = vec3(0.0);
uniform vec3 paletteColor2 = vec3(0.0);
const int VU_COUNT = 100;
uniform float[VU_COUNT] freq_data;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 90.0; //82sec song duration + 3sec delay + 5 sec on frontend
const float songFadeOutStart = 88.0; //80sec fade start + 3sec delay + 5 sec on frontend

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

// from Inigo Quilez: https://iquilezles.org/articles/distfunctions2d/
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}
float sdBlobbyCross( vec2 pos, float he )
{
    pos = abs(pos);
    pos = vec2(abs(pos.x-pos.y),1.0-pos.x-pos.y)/sqrt(2.0);

    float p = (he-pos.y-0.25/he)/(6.0*he);
    float q = pos.x/(he*he*16.0);
    float h = q*q - p*p*p;
    
    float x;
    if( h>0.0 ) { float r = sqrt(h); x = pow(q+r,1.0/3.0)-pow(abs(q-r),1.0/3.0)*sign(r-q); }
    else        { float r = sqrt(p); x = 2.0*r*cos(acos(q/(p*r))/3.0); }
    //x = min(x,sqrt(2.0)/2.0);
    
    vec2 z = vec2(x,he*(1.0-2.0*x*x)) - pos;
    return length(z) * sign(z.y);
}

float opOnion( vec2 p, float r )
{
  return abs(sdBlobbyCross(p, shapeRadius)) - r;
}


vec4 plane(vec3 planePosition, vec3 normalizedPlanePosition, float planeDistance, vec3 centralPlanePosition, vec3 offsetPosition, float planeIndex, float fft) {
    if (fft <= 0.0)
    {
        // if there's no audio playing return black for color, shader will start up when audio starts
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    float antiAliasingFactor = (antiAliasBaseValue * planeDistance * distance(planePosition.xy, normalizedPlanePosition.xy));
    vec4 colorOutput = vec4(0.0);
    vec2 adjustedPlanePosition = planePosition.xy;
    float adjustedRadius = shapeRadius + fft * 0.02;
    float shapeDist = opOnion(adjustedPlanePosition, adjustedRadius);
    float circleDist = sdCircle(adjustedPlanePosition, 0.1);
    float grad = clamp(0.2 + 0.8 * (adjustedPlanePosition.y + 1.0) * 0.5, 0.0, 1.0);
    float c = cos(TIME) * 0.3;
    float s = sin(TIME) * 0.5;
    vec3 insideColor = mix(vec3(0.2, 0.0, 0.0 + c), vec3(0.5 - s, 0.0 + c, 0.0), grad);
    vec3 outsideColor = fft < 500.0 ? palette(planeIndex + (fft * 0.05)) * 1.5 : palette(planeIndex) * 1.5;
    colorOutput.xyz = (shapeDist > 0.0) ? outsideColor : insideColor;
    colorOutput.w = shapeDist > 0.0 ? smoothstep(-antiAliasingFactor, antiAliasingFactor, shapeDist) : 0.01;
    colorOutput.w = circleDist > 0.0 ? colorOutput.w : 0.0; //get rid of the weird square that was showing up
    return colorOutput;
}

vec4 color(vec3 forwardVector, vec3 rightVector, vec3 upVector, vec3 rayOrigin, vec2 pixelCoord, vec2 screenSize, vec2 uv) {
    float pixelLength = length(pixelCoord);
    vec2 nextPixelCoord = pixelCoord + 1.0 / screenSize;

    vec3 rayDir = normalize(pixelCoord.x * rightVector + pixelCoord.y * upVector + rayDepth * forwardVector);
    rayDir += rayDirMod;
    vec3 nextRayDir = normalize(nextPixelCoord.x * rightVector + nextPixelCoord.y * upVector + rayDepth * forwardVector);
    float planeIndex = floor(rayOrigin.z / planeDist);

    vec4 accumulatedColor = vec4(0.0);

    float wave = 0.03 * sin(2.0 * uv.x + TIME / 4.0 + uv.y * 5.0);
    float wavy_y = clamp(uv.y + wave, 0.0, 1.0);
    int bandIdy = int(floor(wavy_y * float(VU_COUNT)));
    float fft = freq_data[clamp(bandIdy, 0, VU_COUNT)];

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

            vec4 planeColor = plane(planeIntersection, nextPlaneIntersection, accumulatedPlaneDist, centralPlaneIntersection, offsetPosition, planeIndex + planeStep, fft);

            planeColor.w *= fadeOutFactor;

            accumulatedColor = alphaBlend(planeColor, accumulatedColor);
            currentRayOrigin = planeIntersection;
        }
    }

    return accumulatedColor;
}

void fragment() {
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

    vec4 finalColor = color(forward, right, up, rayOrigin, normalizedCoords, screenSize, FRAGCOORD.xy / screenSize);

    finalColor *= 1.5;

    //fade out at the end of the song
    if (TIME >= songFadeOutStart && songFadeOutStart <= songDuration)
    {
        float fadeDuration = songDuration - songFadeOutStart;
        float fadeProgress = clamp((TIME - songFadeOutStart) / fadeDuration, 0.0, 1.0);
        finalColor *= 1.0 - fadeProgress; // Fade out the color
        finalColor.w = 1.0;
    }

    finalColor = sqrt(finalColor);
    COLOR = finalColor;
}
