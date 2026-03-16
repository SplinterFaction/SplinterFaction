#version 420

in DataVS {
	vec4 color;
	vec4 visibility;
	vec4 params1;
	vec2 localCoord;
	float worldRadius;
} vIn;

out vec4 fragColor;

void main()#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), released under the MIT license

//__DEFINES__

#line 20000

uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;
uniform float timeSeconds;
uniform float tacticalAlphaMult;
uniform float bucketMode;

#if (DEBUG == 1)

//__ENGINEUNIFORMBUFFERDEFS__

#endif

in DataVS {
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

out vec4 fragColor;

void main() {
	fragColor = v_blendedcolor;

	#ifdef RANGE_OVERVIEW_EXTRAS
		fragColor.a *= tacticalAlphaMult;

		bool dashed = (v_ringflags == 1.0 || v_ringflags == 3.0);
		bool sweep  = (v_ringflags == 2.0 || v_ringflags == 3.0);

		float ang = atan(v_localxy.y, v_localxy.x);
		float normAng = fract((ang + 3.14159265) / 6.2831853);

		// Filled scan wedge
		if (drawMode < 0.5 && sweep) {
			float sweepPos = fract(timeSeconds * 0.1);
			float diff = abs(normAng - sweepPos);
			diff = min(diff, 1.0 - diff);

			float wedgeMask = smoothstep(0.25, 0.0, diff);
			float radialMask = smoothstep(0.08, 1.0, v_radial);
			float finalWedge = wedgeMask * radialMask;

			fragColor.rgb = mix(fragColor.rgb, vec3(1.0, 1.0, 1.0), 0.9 * finalWedge);
			fragColor.a = max(fragColor.a, 0.025 * finalWedge);
		}

		// Per-ring stipple patterns
		if (drawMode > 0.5 && dashed) {
			float dash = 1.0;

			if (v_stipplepattern == 1.0) {
				// long dash
				dash = mod(floor(normAng * 20.0), 2.0);
			}
			else if (v_stipplepattern == 2.0) {
				// dot-dash
				dash = mod(floor(normAng * 10.0), 3.0);
				dash = (dash < 1.5) ? 1.0 : 0.0;
			}
			else if (v_stipplepattern == 3.0) {
				// sparse dots
				dash = mod(floor(normAng * 72.0), 4.0);
				dash = (dash < 1.0) ? 1.0 : 0.0;
			}
			else {
				// default
				dash = mod(floor(normAng * 40.0), 2.0);
			}

			if (dash < 0.5) {
				discard;
			}
		}

		// Edge sweep highlight — use same angular basis as wedge
		if (drawMode > 0.5 && sweep) {
			float sweepPos = fract(timeSeconds * 0.1);
			float diff = abs(normAng - sweepPos);
			diff = min(diff, 1.0 - diff);

			float sweepMask = smoothstep(0.18, 0.0, diff);

			fragColor.a *= (1.0 + 1.25 * sweepMask);

			vec3 sweepColor = vec3(1.0, 1.0, 0.20);
			fragColor.rgb = mix(fragColor.rgb, sweepColor, 0.65 * sweepMask);
		}
	#endif

	#if (DEBUG == 1)
		if (fract(gl_FragCoord.x * 0.125) < 0.4) {
			#if (STATICUNITS == 0)
				fragColor.rgba *= 0.0;
			#endif
		}else{
			#if(STATICUNITS == 1)
				fragColor.rgba *= 0.0;
			#endif
		}
	#endif
}
{
	fragColor = vec4(vIn.color.rgb, 1.0);
}