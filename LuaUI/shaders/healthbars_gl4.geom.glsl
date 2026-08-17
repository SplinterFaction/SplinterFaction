#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.  

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
// Vertex budget, worst case. Ordinary bar: 8 outer background + 8 trough + 8
// fill + 20 glyphs = 44. SF split bar: 8 outer background + 16 (two troughs) +
// 16 (two fills) + 4 shield glyph + 16 percentage glyphs (three digits plus the
// sign, reachable now that a split bar can sit at 100%) = 60, against
// MAXVERTICES of 64. Overrunning max_vertices truncates output silently rather
// than erroring, so if split bars vanish while glyphs are on, look here first:
// dropping to a single full-width trough buys back 8.
layout(triangle_strip, max_vertices = MAXVERTICES) out;
#line 20000

uniform float iconDistance;
uniform float skipGlyphsNumbers; // <0.5 means none, <1.5 means percent only, >1.5 means nothing, just bars

in DataVS { // I recall the sane limit for cache coherence is like 48 floats per vertex? try to stay under that!
	uint v_numvertices;
	vec4 v_mincolor;
	vec4 v_maxcolor;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	vec2 v_sizemodifiers;
	uvec4 v_bartype_index_ssboloc;
	float v_secondvalue; // SF split bars: the right-hand half's value (0 for every other bar type)
} dataIn[];

out DataGS {
	vec4 g_color; // pure rgba
	vec4 g_uv; // xy is trivially uv coords, z is texture blend factor, w means nothing yet
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;
float zoffset;
float depthbuffermod;
float sizemultiplier = dataIn[0].v_sizemodifiers.x;
#define HALFPIXEL 0.0019765625

#define BARTYPE dataIn[0].v_bartype_index_ssboloc.x
#define BARALPHA dataIn[0].v_parameters.y
#define GLYPHALPHA dataIn[0].v_parameters.z
#define UVOFFSET dataIn[0].v_parameters.w
#define UNIFORMLOC dataIn[0].v_bartype_index_ssboloc.z
#define SECONDVALUE dataIn[0].v_secondvalue

#define BITUSEOVERLAY 1u
#define BITSHOWGLYPH 2u
#define BITPERCENTAGE 4u
#define BITTIMELEFT 8u
#define BITINTEGERNUMBER 16u
#define BITGETPROGRESS 32u
#define BITFLASHBAR 64u
#define BITCOLORCORRECT 128u
#define BITSPLITBAR 256u

// Inner span of the bar, i.e. the region the fill quads and troughs live in.
#define BARINNERLEFT  (-BARWIDTH + BARCORNER)
#define BARINNERSPAN  (2.0 * (BARWIDTH - BARCORNER))

void emitVertexBG(in vec2 pos){
	g_uv.xy = vec2(0.0,0.0);
	vec3 primitiveCoords = vec3(pos.x,0.0,pos.y - zoffset) * BARSCALE *sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	gl_Position.z += depthbuffermod;
	g_uv.z = 0.0; // this tells us to use color
	float extracolor = 0.0;
	if (((BARTYPE & BITFLASHBAR) > 0u) && (mod(timeInfo.x, 10.0) > 4.0)){
		extracolor = 0.5;
	}
	g_color = mix(BGBOTTOMCOLOR + extracolor, BGTOPCOLOR + extracolor, pos.y);
	g_color.a *= dataIn[0].v_parameters.y; // blend with bar fade alpha
	EmitVertex();
}

// uOrigin/uSpan describe which slice of world x maps onto the full [0,1] atlas
// strip. Full-width bars pass the whole inner span, so this is identical to the
// original fixed mapping. Split bars pass their own half, so each half gets the
// complete texture pattern instead of half of one.
void emitVertexBarBG(in vec2 pos, in vec4 botcolor, in float bartextureoffset, in float uOrigin, in float uSpan){
	g_uv.x = (pos.x - uOrigin) / uSpan; // map U to [0,1] over the requested span
	g_uv.y = (pos.y - BARCORNER) / (BARHEIGHT - 2 * BARCORNER);
	vec2 uv01 = g_uv.xy*3.0;
	g_uv.xy = g_uv.xy * vec2(ATLASSTEP * 9, ATLASSTEP) + vec2(3 * ATLASSTEP, bartextureoffset); // map uvs to the bar texture
	g_uv.y = -1.0 * g_uv.y;
	//vec3 primitiveCoords = vec3( (pos.x - sign(pos.x) * BARCORNER),0.0, (pos.y - sign(pos.y - 0.5) * BARCORNER - zoffset)) * BARSCALE;
	vec3 primitiveCoords = vec3( pos.x,0.0, pos.y - zoffset) * BARSCALE *sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	gl_Position.z += depthbuffermod;
	g_uv.z = clamp(10000 * bartextureoffset, 0, 1); // this tells us to use color if we are using bartextureoffset
	g_color = botcolor;
	//g_color = vec4(g_uv.x, g_uv.y, 0.0, 1.0);
	g_color.a *= dataIn[0].v_parameters.y; // blend with bar fade alpha
	//g_color.a = 1.0;
	//	g_uv.y -= ATLASSTEP * 8;
	EmitVertex();
}
void emitVertexGlyph(in vec2 pos, in vec2 uv){
	g_uv.xy = vec2(uv.x, 1.0 - uv.y);
	vec3 primitiveCoords = vec3(pos.x,0.0,pos.y - zoffset) * BARSCALE *sizemultiplier;
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	g_uv.z = 1.0; // this tells us to use texture
	g_color = vec4(1.0);
	g_color.a *= dataIn[0].v_parameters.z; // blend with text/icon fade alpha
	EmitVertex();
}

// The translucent tinted trough behind a fill, spanning [xstart, xstart + xspan].
void emitTrough(in float xstart, in float xspan, in vec4 tintcolor){
	vec4 truecolor = tintcolor;
	truecolor.a = 0.2;
	vec4 topcolor = truecolor;
	topcolor.rgb *= BOTTOMDARKENFACTOR;
	float xend = xstart + xspan;
	emitVertexBarBG(vec2(xstart,                 SMALLERCORNER + BARCORNER            ), truecolor, 0.0, xstart, xspan); //1
	emitVertexBarBG(vec2(xstart,                 BARHEIGHT - SMALLERCORNER - BARCORNER), topcolor,  0.0, xstart, xspan); //2
	emitVertexBarBG(vec2(xstart + SMALLERCORNER, BARCORNER                            ), truecolor, 0.0, xstart, xspan); //3
	emitVertexBarBG(vec2(xstart + SMALLERCORNER, BARHEIGHT - BARCORNER                ), topcolor,  0.0, xstart, xspan); //4
	emitVertexBarBG(vec2(xend   - SMALLERCORNER, BARCORNER                            ), truecolor, 0.0, xstart, xspan); //5
	emitVertexBarBG(vec2(xend   - SMALLERCORNER, BARHEIGHT - BARCORNER                ), topcolor,  0.0, xstart, xspan); //6
	emitVertexBarBG(vec2(xend,                   SMALLERCORNER + BARCORNER            ), truecolor, 0.0, xstart, xspan); //7
	emitVertexBarBG(vec2(xend,                   BARHEIGHT - SMALLERCORNER - BARCORNER), topcolor,  0.0, xstart, xspan); //8
	EndPrimitive();
}

// The filled portion of a bar, growing left to right from xstart over xspan.
// bartextureoffset of 0.0 gives a flat colour fill, otherwise the atlas row at
// that offset is stretched across the fill.
void emitFillQuad(in float xstart, in float xspan, in float value, in vec4 fillcolor, in float bartextureoffset){
	vec4 truecolor = fillcolor;
	truecolor.a = 1.0;
	vec4 botcolor = truecolor;
	botcolor.rgb *= BOTTOMDARKENFACTOR;
	float fillpos = (xspan - 2.0 * SMALLERCORNER) * value;
	emitVertexBarBG(vec2(xstart,                                 SMALLERCORNER + BARCORNER            ), botcolor,  bartextureoffset, xstart, xspan); //1
	emitVertexBarBG(vec2(xstart,                                 BARHEIGHT - BARCORNER - SMALLERCORNER), truecolor, bartextureoffset, xstart, xspan); //2
	emitVertexBarBG(vec2(xstart + SMALLERCORNER,                 BARCORNER                            ), botcolor,  bartextureoffset, xstart, xspan); //3
	emitVertexBarBG(vec2(xstart + SMALLERCORNER,                 BARHEIGHT - BARCORNER                ), truecolor, bartextureoffset, xstart, xspan); //4
	emitVertexBarBG(vec2(xstart + SMALLERCORNER + fillpos,       BARCORNER                            ), botcolor,  bartextureoffset, xstart, xspan); //5
	emitVertexBarBG(vec2(xstart + SMALLERCORNER + fillpos,       BARHEIGHT - BARCORNER                ), truecolor, bartextureoffset, xstart, xspan); //6
	emitVertexBarBG(vec2(xstart + 2.0 * SMALLERCORNER + fillpos, BARCORNER + SMALLERCORNER            ), botcolor,  bartextureoffset, xstart, xspan); //7
	emitVertexBarBG(vec2(xstart + 2.0 * SMALLERCORNER + fillpos, BARHEIGHT - BARCORNER - SMALLERCORNER), truecolor, bartextureoffset, xstart, xspan); //8
	EndPrimitive();
}

void emitGlyph(vec2 bottomleft, vec2 uvbottomleft, vec2 uvsizes){
	#define GROWSIZE 0.2
	emitVertexGlyph(vec2(bottomleft.x, bottomleft.y), vec2(uvbottomleft.x + HALFPIXEL, uvbottomleft.y + HALFPIXEL));
	emitVertexGlyph(vec2(bottomleft.x, bottomleft.y + BARHEIGHT), vec2(uvbottomleft.x + HALFPIXEL, uvbottomleft.y + uvsizes.y - HALFPIXEL));
	emitVertexGlyph(vec2(bottomleft.x + BARHEIGHT, bottomleft.y), vec2(uvbottomleft.x + uvsizes.x - HALFPIXEL, uvbottomleft.y + HALFPIXEL));
	emitVertexGlyph(vec2(bottomleft.x + BARHEIGHT, bottomleft.y + BARHEIGHT), vec2(uvbottomleft.x + uvsizes.x -HALFPIXEL, uvbottomleft.y + uvsizes.y-HALFPIXEL));
	EndPrimitive();
}


#line 22000
void main(){
	// bail super early like scum if simple bar with >0.99 value
	//if (v_bartype_index_ssboloc.y < 32u){ // for paralyze and emp bars, which should always go above regular health bar
		zoffset =  1.15 * BARHEIGHT *  float(dataIn[0].v_bartype_index_ssboloc.y);
	//}else{
	//	zoffset =  1.15 * BARHEIGHT *  -1.0;
	//}

	centerpos = dataIn[0].v_centerpos;

	rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz,

	g_color = vec4(1.0, 0.0, 1.0, 1.0); // a very noticeable default color

	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont

	float health = dataIn[0].v_parameters.x;
	if (BARALPHA < MINALPHA) return; // Dont draw below 50% transparency

	// All the early bail conditions to not draw full/empty bars
	#ifndef DEBUGSHOW
	if ((BARTYPE & BITSPLITBAR) > 0u) {
		// Split bars carry two independent values, so a full hull with a spent
		// shield (or the reverse) still has something worth showing. Only bail
		// when neither half has anything to say.
		if (health > 0.999 && SECONDVALUE > 0.999) return;
		if (health < 0.00001 && SECONDVALUE < 0.00001) return;
	} else {
		if (health < 0.00001) return;
		if ((BARTYPE & BITPERCENTAGE) > 0u) { // for percentage bars
			if (health > 0.999) return;
		}else{
			if ((BARTYPE & BITGETPROGRESS) > 0u) { // reload bar?
				if (health > 0.999) return;
			}
			if ((BARTYPE & BITUSEOVERLAY) > 0u){ // for textured percentage bars bars
			//	if (health > 0.995) return;
			//	if (health < 0.005) return;
			}
		}
	}
	#endif
	if (dataIn[0].v_numvertices == 0u) return; // for hiding the build bar when full health


	// STOCKPILE BAR:  128*numStockpileQued + numStockpiled + stockpileBuild
	uint numStockpiled = 0u;
	uint numStockpileQueued = 0u;
	if ((BARTYPE & BITINTEGERNUMBER) > 0u){
		float oldhealth = health;
		health = fract(oldhealth);
		oldhealth = floor(oldhealth);
		numStockpiled = uint(floor( mod (oldhealth, 128)));
		numStockpileQueued = uint(floor(oldhealth/128));
	}

	//EMIT BAR BACKGROUND!
	//     /-4----------6-\
	//   2 |              | 8
	//     |              |
	//   1 |              | 7
	//     \-3----------5-/
	//start in bottom leftmost of this shit.

		depthbuffermod = 0.001;
		emitVertexBG(vec2(-BARWIDTH            , BARCORNER            )); //1
		emitVertexBG(vec2(-BARWIDTH            , BARHEIGHT - BARCORNER)); //2
		emitVertexBG(vec2(-BARWIDTH + BARCORNER, 0                    )); //3
		emitVertexBG(vec2(-BARWIDTH + BARCORNER, BARHEIGHT            )); //4
		emitVertexBG(vec2( BARWIDTH - BARCORNER, 0                    )); //5
		emitVertexBG(vec2( BARWIDTH - BARCORNER, BARHEIGHT            )); //6
		emitVertexBG(vec2( BARWIDTH            , BARCORNER            )); //7
		emitVertexBG(vec2( BARWIDTH            , BARHEIGHT - BARCORNER)); //8
		EndPrimitive();

	// EMIT THE COLORED BACKGROUND
	// for this to work, we need the true color of the bar?

		// The trough is tinted with the uncorrected ramp colour, the fill with the
		// colour-corrected one. Keep that split, it is what gives health bars their
		// washed-out backing.
		vec4 troughcolor = mix(dataIn[0].v_mincolor, dataIn[0].v_maxcolor, health);
		vec4 fillcolor   = troughcolor;
		if ((BARTYPE & BITCOLORCORRECT) > 0u) { fillcolor.rgb = fillcolor.rgb / max(max(fillcolor.r, fillcolor.g), 0.0001); } // color correction for health

		float fillvalue = health;
		if ((BARTYPE & BITTIMELEFT) > 0u) fillvalue = 1.0; // full bar for timer based shit

		float bartextureoffset = 0;
		if ((BARTYPE & BITUSEOVERLAY) > 0u) bartextureoffset = UVOFFSET; // if the bar type is a textured bar, we have a lot of work to do

	// EMIT THE COLORED BACKGROUND AND THE BAR FOREGROUND

		if ((BARTYPE & BITSPLITBAR) > 0u) {
			// SF split bar: hull on the left, personal overshield on the right, one
			// row, two independent values. Each half is drawn the way the standalone
			// bar it replaces was drawn, so the hull side stays a flat colour fill
			// and the shield side keeps the atlas strip at UVOFFSET.
			vec4 osTrough = mix(SPLITMINCOLOR, SPLITMAXCOLOR, SECONDVALUE);
			float halfspan   = (BARINNERSPAN - SPLITGAP) * 0.5;
			float leftstart  = BARINNERLEFT;
			float rightstart = BARINNERLEFT + halfspan + SPLITGAP;

			depthbuffermod = 0.000;
			emitTrough(leftstart,  halfspan, troughcolor);
			emitTrough(rightstart, halfspan, osTrough);

			depthbuffermod = -0.001;
			emitFillQuad(leftstart,  halfspan, fillvalue,   fillcolor, 0.0);
			emitFillQuad(rightstart, halfspan, SECONDVALUE, osTrough,  UVOFFSET);
		} else {
			depthbuffermod = 0.000;
			emitTrough(BARINNERLEFT, BARINNERSPAN, troughcolor);

			depthbuffermod = -0.001;
			emitFillQuad(BARINNERLEFT, BARINNERSPAN, fillvalue, fillcolor, bartextureoffset);
		}

	// try to emit text?

	if (GLYPHALPHA < MINALPHA) return; // dont display glyphs below 50% transparency

	if (skipGlyphsNumbers > 1.5) return;

	float currentglyphpos = 1.0;

	if (skipGlyphsNumbers < 0.5 ){
		if ((BARTYPE & BITSHOWGLYPH) > 0u){
			emitGlyph(vec2(- BARWIDTH - currentglyphpos * BARHEIGHT , 0), vec2(ATLASSTEP, UVOFFSET), vec2(ATLASSTEP, ATLASSTEP));	//glyph icon
		}
	}else{
		currentglyphpos = 0.0;
	}

	if ((BARTYPE & BITINTEGERNUMBER) > 0u){ // STOCKPILE FONTS THEN EH? xx/yy
		vec4 numbers = vec4(numStockpiled, numStockpiled, numStockpileQueued, numStockpileQueued);
		numbers = numbers * vec4(1.0, 0.1, 1.0, 0.1);
		numbers = floor(mod(numbers, 10.0)) * ATLASSTEP;
		float glyphpctsecatlas = 11 * ATLASSTEP; // TODO: slash sign in texture
		// go right to left

		emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT  , 0), vec2(0, numbers.x ), vec2(ATLASSTEP, ATLASSTEP)); // lsb of numqueued
		if (numbers.y > 0 ){
			emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.4 , 0), vec2(0, numbers.y ), vec2(ATLASSTEP, ATLASSTEP)); // msb of numqueued
		}
	}


	if ((BARTYPE & (BITTIMELEFT | BITPERCENTAGE))  > 0u){
		float lsb ;
		float msb ;
		float hsb ; // hundreds. Only ever nonzero for a percentage bar sitting at 100%,
		            // which used to be unreachable because percentage bars bailed out
		            // above 0.999. Split bars can sit at a full hull with a spent
		            // shield, so the digit is needed now or that reads as "0%".
		float glyphpctsecatlas;
		if ((BARTYPE & BITTIMELEFT) > 0u){ //display time
			health = (health - 1.0) / (1.0/40.0);
			lsb = abs(floor(mod(health, 10.0)));
			msb = abs( floor(mod(health*0.1, 10.0)));
			hsb = 0.0; // timers roll over well before three digits
			glyphpctsecatlas = 14.0; // seconds
		}else{
			lsb = floor(mod(health*100.0, 10.0));
			msb = floor(mod(health*10.0, 10.0));
			hsb = floor(mod(health, 10.0));
			glyphpctsecatlas = 11.0; // percent
		}
		emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 1.0) * BARHEIGHT , 0), vec2(0, glyphpctsecatlas * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP)); // %
		emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 2.0) * BARHEIGHT + BARHEIGHT * 0.2 , 0), vec2(0,  lsb * ATLASSTEP ), vec2(ATLASSTEP, ATLASSTEP)); // lsb
		if (msb > 0 || hsb > 0){ // the tens digit stays even at zero once there is a hundreds digit, so 100 does not read as 10
			emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 3.0) * BARHEIGHT + BARHEIGHT * 0.5 , 0), vec2(0,  msb * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP)); //msb
		}
		if (hsb > 0){
			emitGlyph(vec2(-BARWIDTH - (currentglyphpos + 4.0) * BARHEIGHT + BARHEIGHT * 0.8 , 0), vec2(0,  hsb * ATLASSTEP), vec2(ATLASSTEP, ATLASSTEP)); //hsb
		}
	}
}