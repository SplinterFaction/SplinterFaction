#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition; // x,y on unit circle, z = progress
layout (location = 1) in vec4 posscale;            // x,z center for static, y = turret height, w = range
layout (location = 2) in vec4 color1;
layout (location = 3) in vec4 visibility;          // FadeStart, FadeEnd, StartAlpha, EndAlpha
layout (location = 4) in vec4 projectileParams;    // kept for layout compatibility, unused
layout (location = 5) in vec4 additionalParams;    // groupselectionfadescale, weaponType, flags, stipple
layout (location = 6) in uvec4 instData;

uniform float lineAlphaUniform = 1.0;
uniform float fadeDistOffset = 0.0;
uniform float inMiniMap = 0.0;
uniform int rotationMiniMap = 0;
uniform vec4 pipVisibleArea = vec4(0.0, 1.0, 0.0, 1.0);

uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;
uniform float staticUnits = 0.0;

uniform sampler2D heightmapTex;
uniform sampler2D losTex;
uniform sampler2D mapNormalTex;

out DataVS {
	flat vec4 v_blendedcolor;
	flat float v_weapontype;
	flat float v_ringflags;
	flat float v_stipplepattern;
	float v_circleprogress;
	float v_radial;
	vec2 v_localxy;
	#if (DEBUG == 1)
		vec4 v_debug;
	#endif
};

//__ENGINEUNIFORMBUFFERDEFS__

struct SUniformsBuffer {
	uint composite;
	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 drawPos;
	vec4 speed;
	vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#define UNITUNIFORMS uni[instData.y]
#define RANGE                  posscale.w
#define TURRETHEIGHT           posscale.y
#define GROUPSELECTIONFADESCALE additionalParams.x
#define WEAPONTYPE             additionalParams.y
#define RINGFLAGS              additionalParams.z
#define STIPPLEPATTERN         additionalParams.w
#define FADESTART              visibility.x
#define FADEEND                visibility.y
#define STARTALPHA             visibility.z
#define ENDALPHA               visibility.w

vec2 inverseMapSize = 1.0 / mapSize.xy;

float heightAtWorldPos(vec2 w) {
	const vec2 heightmaptexel = vec2(8.0, 8.0);
	w += vec2(-8.0, -8.0) * (w * inverseMapSize) + vec2(4.0, 4.0);
	vec2 uvhm = clamp(w, heightmaptexel, mapSize.xy - heightmaptexel);
	uvhm = uvhm * inverseMapSize;
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

void main() {
	v_localxy = circlepointposition.xy;
	v_circleprogress = circlepointposition.z;
	v_radial = clamp(length(circlepointposition.xy), 0.0, 1.0);
	v_weapontype = WEAPONTYPE;
	v_ringflags = RINGFLAGS;
	v_stipplepattern = STIPPLEPATTERN;
	v_blendedcolor = color1;

	vec3 modelWorldPos;
	if (staticUnits > 0.5) {
		modelWorldPos = posscale.xyz;
		modelWorldPos.y = heightAtWorldPos(modelWorldPos.xz) + TURRETHEIGHT;
	} else {
		modelWorldPos = UNITUNIFORMS.drawPos.xyz;
		modelWorldPos.y += TURRETHEIGHT;
	}

	// Plain world-space circle: no heading, no cone logic, no ballistic reshaping.
	vec2 worldXZ = modelWorldPos.xz + circlepointposition.xy * RANGE;
	float worldY = heightAtWorldPos(worldXZ);

	// Keep shallow-water rings readable.
	if (modelWorldPos.y > -20.0) {
		modelWorldPos.y = max(1.0, modelWorldPos.y);
		worldY = max(1.0, worldY);
	}

	vec3 circleWorldPos = vec3(worldXZ.x, worldY + 4.0, worldXZ.y);

	// Bounds fade.
	vec2 mymin = min(circleWorldPos.xz, mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	float outOfBoundsAlpha = 1.0 - clamp(inboundsness * (-0.02), 0.0, 1.0);

	// Distance fade.
	vec4 camPos = cameraViewInv[3];
	float distToCam = length(modelWorldPos.xyz - camPos.xyz);
	float fadeDist = FADEEND - FADESTART;
	float fadeAlpha = STARTALPHA;
	if (fadeDist != 0.0) {
		fadeAlpha = clamp((FADEEND + fadeDistOffset - distToCam) / fadeDist, ENDALPHA, STARTALPHA);
	}
	if (inMiniMap > 0.5) {
		fadeAlpha = 1.0;
	}

	// Fog.
	float fogDist = length((cameraView * vec4(circleWorldPos.xyz, 1.0)).xyz);
	float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0.0, 1.0);
	v_blendedcolor.rgb = mix(fogColor.rgb, v_blendedcolor.rgb, fogFactor);

	// Position.
	if (inMiniMap < 0.5) {
		gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
		gl_Position.z = gl_Position.z - 128.0 / gl_Position.w;
	} else {
		bool isPip = (pipVisibleArea.x != 0.0 || pipVisibleArea.y != 1.0 || pipVisibleArea.z != 0.0 || pipVisibleArea.w != 1.0);
		vec4 ndcxy;
		if (isPip) {
			vec2 normPos = circleWorldPos.xz / mapSize.xy;
			vec2 screenPos;
			screenPos.x = (normPos.x - pipVisibleArea.x) / (pipVisibleArea.y - pipVisibleArea.x);
			screenPos.y = 1.0 - (normPos.y - pipVisibleArea.z) / (pipVisibleArea.w - pipVisibleArea.z);
			if (rotationMiniMap == 0) {
				screenPos.y = 1.0 - screenPos.y;
			} else if (rotationMiniMap == 1) {
				screenPos.xy = screenPos.yx;
			} else if (rotationMiniMap == 2) {
				screenPos.x = 1.0 - screenPos.x;
			} else if (rotationMiniMap == 3) {
				screenPos.xy = vec2(1.0) - screenPos.yx;
			}
			ndcxy = vec4(screenPos * 2.0 - 1.0, 0.0, 1.0);
		} else {
			ndcxy = mmDrawViewProj * vec4(circleWorldPos.xyz, 1.0);
			if (rotationMiniMap == 1) {
				ndcxy.xy = vec2(-ndcxy.y, ndcxy.x);
			} else if (rotationMiniMap == 2) {
				ndcxy.xy = -ndcxy.xy;
			} else if (rotationMiniMap == 3) {
				ndcxy.xy = vec2(ndcxy.y, -ndcxy.x);
			}
		}
		gl_Position = ndcxy;
	}

	float outalpha = outOfBoundsAlpha * (fadeAlpha * lineAlphaUniform);
	v_blendedcolor.a *= outalpha;

	float selectedUnitCount = (WEAPONTYPE == 2.0) ? selBuilderCount : selUnitCount;
	selectedUnitCount = clamp(selectedUnitCount, 1.0, 25.0);
	float innerRingDim = GROUPSELECTIONFADESCALE * 0.1 * selectedUnitCount;
	float finalAlpha = drawAlpha;
	if (drawMode == 2.0) {
		finalAlpha = drawAlpha / max(pow(innerRingDim, 2.0), 1.0);
	}
	finalAlpha = clamp(finalAlpha, 0.0, 1.0);
	v_blendedcolor.a *= finalAlpha;

	#if (DEBUG == 1)
		v_debug = vec4(modelWorldPos, RANGE);
	#endif
}
