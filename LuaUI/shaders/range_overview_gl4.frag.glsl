#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

uniform float drawAlpha = 1.0;
uniform float tacticalAlphaMult = 1.0;

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
	fragColor.a *= drawAlpha;
	fragColor.a *= tacticalAlphaMult;

	#if (DEBUG == 1)
		if (fract(gl_FragCoord.x * 0.125) < 0.4) {
			#if (STATICUNITS == 0)
				fragColor.rgba *= 0.0;
			#endif
		} else {
			#if (STATICUNITS == 1)
				fragColor.rgba *= 0.0;
			#endif
		}
	#endif
}
