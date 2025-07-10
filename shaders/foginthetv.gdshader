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
uniform float shapeSize = 0.5;
uniform vec3 secondShapeOffset = vec3(0.0);
uniform vec2 pathA = vec2(0.0);
uniform vec2 pathB = vec2(0.0);
uniform vec3 paletteColor1 = vec3(0.0);
uniform vec3 paletteColor2 = vec3(0.0);
uniform vec3 backgroundColor = vec3(0.0);
//fft
uniform float amplitude = 1.0;
uniform float freqX = 1.0;
uniform float freqSlow = 4.0;
uniform float freqY = 2.0;
const int VU_COUNT = 100;
uniform float[VU_COUNT] freq_data;
uniform int framesWaited;
uniform sampler2D prevFrame;
uniform sampler2D prevFrame2;
uniform sampler2D video;

const vec4 UP_VECTOR = vec4(0.0, 1.0, 2.0, 3.0);
const float songDuration = 100.0; //94sec song duration + 6sec delay
const float songFadeOutStart = 96.0; //90sec fade start + 6sec delay

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

float sdPyramid( vec3 p, float h )
{
  float m2 = h*h + 0.25;
    
  p.xz = abs(p.xz);
  p.xz = (p.z>p.x) ? p.zx : p.xz;
  p.xz -= 0.5;

  vec3 q = vec3( p.z, h*p.y - 0.5*p.x, h*p.x + 0.5*p.y);
   
  float s = max(-q.x,0.0);
  float t = clamp( (q.y-0.5*p.z)/(m2+0.25), 0.0, 1.0 );
    
  float a = m2*(q.x+s)*(q.x+s) + q.y*q.y;
  float b = m2*(q.x+0.5*t)*(q.x+0.5*t) + (q.y-m2*t)*(q.y-m2*t);
    
  float d2 = min(q.y,-q.x*m2-q.y*0.5) > 0.0 ? 0.0 : min(a,b);
    
  return sqrt( (d2+q.z*q.z)/m2 ) * sign(max(q.z,-p.y));
}

vec2 pyramid_face_uv(vec3 p, vec3 n, float h) {
    // p: local-space hit position
    // n: normal at p
    // h: pyramid height

    vec3 abs_n = abs(n);
    vec2 uv;

    // If the Y component of the normal is largest, it's the base
    if (abs_n.y > abs_n.x && abs_n.y > abs_n.z && n.y < 0.0) {
        // Base face (XZ plane)
        uv = p.xz + 0.5; // Assuming base from -0.5 to 0.5 in X and Z
    } else {
        // Side face: project onto the triangle
        // Find which side face (there are 4)
        float angle = atan(p.z, p.x);
        float side = floor((angle + PI) / (0.5 * PI)); // 0,1,2,3 for 4 faces
        float u, v;

        // Rotate p so the current face is always in the same orientation
        float rot = -side * 0.5 * PI;
        float cx = cos(rot);
        float sz = sin(rot);
        vec3 pr = vec3(cx * p.x - sz * p.z, p.y, sz * p.x + cx * p.z);

        // Map the triangle: base from (-0.5,0) to (0.5,0), apex at (0, h)
        // Project pr.x in [-0.5,0.5], pr.y in [0,h]
        u = pr.x + 0.5;
        v = pr.y / h;
        uv = vec2(u, v);
    }
    return uv;
}

vec3 estimate_normal_pyramid(vec3 p){
    float eps = 0.001;
    float dx = sdPyramid(p + vec3(eps, 0.0, 0.0), shapeSize) - sdPyramid(p - vec3(eps, 0.0, 0.0), shapeSize);
    float dy = sdPyramid(p + vec3(0.0, eps, 0.0), shapeSize) - sdPyramid(p - vec3(0.0, eps, 0.0), shapeSize);
    float dz = sdPyramid(p + vec3(0.0, 0.0, eps), shapeSize) - sdPyramid(p - vec3(0.0, 0.0, eps), shapeSize);
    return normalize(vec3(dx, dy, dz));
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

vec4 raymarch(vec3 rayOrigin, vec3 rayDir, float maxDist, int maxSteps, float rot_x, float rot_y, float fft) {
    float t = 0.0;
    int hit_id = 0;

    for (int i = 0; i < maxSteps; i++) {
        vec3 p = rayOrigin + rayDir * t;

        // First shape (centered, rotating)
        mat3 rot1 = rotation_y(rot_y) * rotation_x(rot_x);
        vec3 p1 = rot1 * p;
        float d1 = sdPyramid(p1, shapeSize);

        // Second shape (offset, different size/rotation)
        mat3 rot2 = rotation_y(rot_y + 1.0) * rotation_x(rot_x + 1.0);

        vec3 p2 = rot2 * (p - secondShapeOffset);
        p2.z += fft * 0.5;
        float d2 = sdPyramid(p2, shapeSize * 0.5);

        float dist = d1;
        hit_id = 1;
        if (d2 < dist) {
            dist = d2;
            hit_id = 2;
        }

        if (dist < 0.001) {
            return vec4(p, float(hit_id));
        }
        t += dist;
        if (t > maxDist) break;
    }
    return vec4(rayOrigin + rayDir * t, 0.0); // No hit
}


vec4 plane(vec3 rayOrigin, vec3 rayDir, vec2 pixelCoord, float fft) {
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
    vec4 tex = texture(video, tex_uv);
    vec4 prev = texture(prevFrame, tex_uv);
    vec4 prev2 = texture(prevFrame2, tex_uv);
    prev.rbg = clamp(vec3(prev.r + float(framesWaited) * 0.01, prev.g + float(framesWaited) * 0.02, prev.b - float(framesWaited) * 0.03), 0.0, 0.3 );
    float blend = 0.1 * float(framesWaited);
    prev = alphaBlend(prev, prev2);
    vec4 blended = mix(tex, prev, blend);

    vec3 color = vec3(paletteColor1.x + cos(TIME), paletteColor1.y + sin(TIME), paletteColor1.z + sin(TIME * 0.5));
    color = clamp(color, 0.0, 0.2);

    //I'm not displaying the pyramid faces correctly but it does look interesting

    vec4 marchResult = raymarch(rayOrigin, rayDir, maxDistance, 32, TIME * 0.5, TIME * 0.2, fft);
    float hit = marchResult.w;
    vec2 face_uv;

    if (hit > 0.1) {
        vec3 hitPos = marchResult.xyz;
        vec3 normal;

        if (hit == 1.0) {
            mat3 rot1 = rotation_y(TIME * 0.5) * rotation_x(TIME);
            mat3 inv_rot1 = transpose(rot1);
            vec3 local_hit_pyrm = inv_rot1 * hitPos;
            vec3 normal = estimate_normal_pyramid(local_hit_pyrm);
            face_uv = pyramid_face_uv(local_hit_pyrm, normal, shapeSize);
            face_uv.y = 1.0 - face_uv.y;
            vec3 col1 = texture(video, face_uv).rgb;
            colorOutput.xyz = col1;
        } else if (hit == 2.0) {
            mat3 rot2 = rotation_y(TIME * 0.5 + 1.0) * rotation_x(TIME + 1.0);
            mat3 inv_rot2 = transpose(rot2);
            vec3 local_hit_pyrm = inv_rot2 * (hitPos - secondShapeOffset);
            vec3 normal = estimate_normal_pyramid(local_hit_pyrm);
            face_uv = pyramid_face_uv(local_hit_pyrm, normal, shapeSize * 0.5);
            face_uv.y = 1.0 - face_uv.y;
            vec3 col2 = texture(video, face_uv).rgb;
            colorOutput.xyz = col2;
        }
    }
    // After calculating face_uv for side faces:
    if (face_uv.x < face_uv.y * 0.5 || face_uv.x > 1.0 - face_uv.y * 0.5) {
        colorOutput.a = 0.0; // Make outside the triangle transparent
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

    float wave = amplitude * sin(freqX * UV.x + TIME / freqSlow + UV.y * freqY);
    float wavy_y = clamp(UV.x + wave, 0.0, 1.0);
    int bandIdy = int(floor(wavy_y * float(VU_COUNT)));
    float fft = freq_data[clamp(bandIdy, 0, VU_COUNT)];

    vec4 background = vec4(0.0, 0.0, 0.0, 0.1);
    background.xyz = backgroundColor + palette(fft + (sin(TIME) * 0.5) );
    vec2 tex_uv = normalizedCoords;
    if (tex_uv.x < 0.0 || tex_uv.x > 1.0 || tex_uv.y < 0.0 || tex_uv.y > 1.0) {
        background = background;
    }
    else {
        vec4 tex = texture(video, tex_uv);
        vec4 prev = texture(prevFrame, tex_uv);
        vec4 prev2 = texture(prevFrame2, tex_uv);
        background.xyz = mix(background.xyz, prev2.rgb, 0.5);
        background.xyz = mix(background.xyz, prev.rgb, 0.5);
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