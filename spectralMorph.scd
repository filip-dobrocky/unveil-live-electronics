// load things
(
b = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/sul_ponticello_tremolo/Vc-pont_trem-A2-mf-4c-N.wav");
c = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/behind_the_bridge/Vc-behind_bridge-N-N-3c-N.wav");
)

(
SynthDef("whiten", { |out=0, sndbufnum, sndbufnum2|
	var in, chain, in2, chain2, fftsize, morph;
	morph = MouseX.kr(0, 1);
	fftsize = 2048;
	in = SoundIn.ar(0);
	in2 = PlayBuf.ar(1, sndbufnum2, BufRateScale.kr(sndbufnum2), loop: 1);
	chain = FFT(LocalBuf(fftsize), in);
	chain2 = FFT(LocalBuf(fftsize), in2);
	chain = chain.pvcalc2(chain2, fftsize, {
		|mags, phases, mags2, phases2|
		// interpolate magnitudes up to 1
		mags = morph * (1-mags) + mags;
		mags2 = (1-morph) * (1-mags2) + mags2;
		// interpolate phases down to 0
		phases = phases - (phases*morph);
		phases2 = phases2 - (phases2*(1-morph));
		[mags * mags2, phases + phases2]
	}, frombin:0, tobin:1024, zeroothers:0);
	Out.ar(out, 0.5 * IFFT(chain).dup);
}).add;
)


x = Synth("whiten", [\out, 0, \sndbufnum, c.bufnum, \sndbufnum2, b.bufnum])


(
SynthDef("help-morph", { arg out=0, bufnumA=0, bufnumB=1;
    var inA, chainA, inB, chainB, chain, fftSize = 2048;
	inA = SoundIn.ar(0);
	inB = PlayBuf.ar(1, bufnumB, BufRateScale.kr(bufnumB), loop: 1);
	chainA = FFT(LocalBuf(fftSize), inA);
    chainB = FFT(LocalBuf(fftSize), inB);
    chain = PV_Morph(chainA, chainB, MouseX.kr);
    Out.ar(out, IFFT(chain).dup);
}).play(s,[\out, 0, \bufnumA, b.bufnum, \bufnumB, c.bufnum ]);
)




