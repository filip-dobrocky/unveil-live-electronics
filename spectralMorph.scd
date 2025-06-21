// load things
(
b = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/sul_ponticello_tremolo/Vc-pont_trem-A2-mf-4c-N.wav");
c = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/behind_the_bridge/Vc-behind_bridge-N-N-3c-N.wav");
b.normalize;
c.normalize;
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

d = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav");


(
SynthDef(\spectral, { arg out=0, bufnumA=0, bufnumB=1;
    var inA, chainA, inB, chainB, chain, sig, fftSize = 1024, mix, freezeTrig, freezeThresh = 0.66, freezeTime = 3;
	mix = MouseX.kr(0, 1);
	// inA = PlayBuf.ar(1, bufnumA, BufRateScale.kr(bufnumA), loop: 1);
	inA = SoundIn.ar(0);
	inB = PlayBuf.ar(1, bufnumB, BufRateScale.kr(bufnumB), loop: 1);//, startPos: BufFrames.kr(bufnumB) * 0.5);
	chainA = FFT(LocalBuf(fftSize), inA);
    chainB = FFT(LocalBuf(fftSize), inB);
	freezeTrig = ToggleFF.ar(Onsets.kr(chainA, freezeThresh));
	chainB = PV_Freeze(chainB, freezeTrig);
    chain = PV_MagMul(chainA, chainB);
	sig = IFFT(chain).dup;
	sig = (mix * sig) + ((1-mix)*inA);
	sig = Limiter.ar(sig);
    Out.ar(out, sig);
}).play(s,[\out, 0, \bufnumA, b.bufnum, \bufnumB, c.bufnum ]);
)

Onsets
Trig

(
SynthDef(\spectral, {
    arg out=0, fftSize = 1024, freezeThresh = 0.66;
    arg mix1 = 0.0, mix2 = 0.0, mix3 = 0.0;

    var inA, filterIns, mixes, chainA, frozenChains, freezeTrig, filtered, final, sig;

    inA = SoundIn.ar(0);

    // Filter inputs as array (can be expanded)
    filterIns = [SoundIn.ar(1), SoundIn.ar(2), SoundIn.ar(3)];
    mixes = [mix1, mix2, mix3];

    // FFT of main input
    chainA = FFT(LocalBuf(fftSize), inA, hop);

    // Freeze trigger based on inA's transients
    freezeTrig = ToggleFF.ar(Onsets.kr(chainA, freezeThresh));

    // Create frozen FFT chains for each filter input
    frozenChains = filterIns.collect { |sig|
        var chain = FFT(LocalBuf(fftSize), sig, hop);
        PV_Freeze(chain, freezeTrig);
    };

    // Apply PV_MagMul sequentially with mix weight
    filtered = chainA;
    frozenChains.do { |frozen, i|
        var mix = mixes[i];
        var partial = PV_MagMul(filtered, frozen);  // full multiplication
        // Crossfade between unfiltered and filtered
        filtered = XFade2.ar(IFFT(partial), IFFT(filtered), mix * 2 - 1).fft; // back to FFT
    };

    // Final output
    sig = IFFT(filtered).dup;
    sig = Limiter.ar(sig);
    Out.ar(out, sig);
}).add;
)


