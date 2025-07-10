SynthDef(\directIn, {
	var sig;
	sig = SoundIn.ar(\ins.ir(~micIns));
	sig = sig * \inAmps.kr(~micAmps);
	sig = sig * \gain.kr(1);
	sig = Compander.ar(sig, sig,
		\thresh.kr(0.4),
		1,
		1 / \ratio.kr(4),
		0.01,
		0.1
	);
	Out.ar(\out.ir(0), sig * \amp.kr(2.5));
}).add;

SynthDef(\looper, {
	var mic, recTrig, playTrig, max, ptr, loop, rec, feedback;
	var xfade = \xfade.kr(0.1);
	var buf = \buf.kr(0);

	// ~micIns as default just to set the channels n
	mic = Mix.ar(InFeedback.ar(\in.ir(~micIns)));
	recTrig = Trig1.ar(\recTrig.tr(0), ControlDur.ir);
	playTrig = Trig1.ar(\playTrig.tr(0), ControlDur.ir);
	max = Sweep.ar(recTrig, SampleRate.ir * \run.kr(0));
	ptr = Phasor.ar(playTrig, 1, 0, max, 0);
	loop = BufRd.ar(1, buf, ptr);

	rec = Mix.ar([
		mic * \recGain.kr(0).varlag(xfade,-2),
		loop * \fbGain.kr(0).varlag(xfade,-2)
	]);
	rec = rec * \recAmp.kr(1).varlag(xfade,-2);
	BufWr.ar(rec, buf, ptr);

	loop = loop * \loopAmp.kr(1).varlag(xfade,-2);
	Out.ar(\out.ir(0), loop);
	Out.ar(\ptrBus.ir(0), ptr);
}).add;

SynthDef(\reso, {
	arg freqs = #[440, 660, 880, 1320], amps = #[1, 1, 1, 1], decays = #[1, 1, 1, 1], amp = 1, harmonics = 10, bus = 0;
	var sig, in, minF;

	minF = freqs.reduce({ |a, b| a.min(b) });
	in = In.ar(bus, ~totalChans);
	sig = DynKlank.ar(
		`[freqs, amps, decays],
		in,
		\freqScale.kr(1),
		\freqOffset.kr(0),
		\decayScale.kr(1)
	) * 0.2;
	sig = LPF.ar(sig, harmonics*minF);
	sig = Limiter.ar(sig) * 0.2;

	XOut.ar(bus, \mix.kr(0, 0.5), sig);
}).add;

SynthDef(\pitchShifter, {
	var in, sig;
	var bus = \bus.kr(0);

	in = In.ar(bus, ~totalChans);
	sig = PitchShift.ar(
		in,
		0.2,
		\ratio.kr(1),
		0.005,
		0.1
	);

	XOut.ar(bus, \mix.kr(0, 0.5), sig);
}).add;

SynthDef(\destroyer, {
	arg cutoff = 300;
	var in, sig;
	var bus = \bus.kr(0);
	var bass = \bass.kr(0, 0.5).clip(0, 1);
	var crush = \crush.kr(0, 0.5).clip(0, 1) ** 0.5;
	in = In.ar(bus, ~totalChans);
	sig = Decimator.ar(
		in,
		s.sampleRate * (1 - crush.linlin(0, 1, 0, 0.8)),
		crush.linlin(0, 1, 24, 2)
	);
	sig = ((1 - bass) * sig) + (bass * RLPF.ar(sig, cutoff, 0.5));
	sig.softclip; // tanh?
	// sig = Limiter.ar(sig);
	XOut.ar(bus, \mix.kr(0, 0.5), sig);
}).add;

SynthDef(\spectral, {
	arg out = 0, freezeThresh = 0.4,
	inBus = 0, ptrBus = 0, buffers = #[0, 0, 0],
	mix1 = 0, mix2 = 0, mix3 = 0, loopAmp = 1;

	var in, loopIns, mixes, chainIn, frozenChains, freezeTrig, filtered, final, sig, ptrs, chainWet;
	var fftSize = 1024;
	var chans =  ~micIns.size;

	in = In.ar(inBus, chans);

	ptrs = In.ar(ptrBus, ~nLoops);
	loopIns = buffers.collect { |buf, i|
		var loop;
		loop = BufRd.ar(1, buf, ptrs[i]);
		Limiter.ar(loop * loopAmp);
	};
	mixes = [mix1, mix2, mix3];

	chainIn = FFT(LocalBuf(fftSize), Mix.ar(in));

	// Freeze trigger based on inA's transients
	freezeTrig = 1 - Trig1.ar(Onsets.kr(chainIn, freezeThresh), 0.001);

	// TODO: freeze fix
	// Create frozen FFT chains for each filter input
	frozenChains = loopIns.collect { |sig|
		var chain = FFT(LocalBuf(fftSize), sig);
		PV_Freeze(chain, freezeTrig);
	};

	// Apply PV_MagMul sequentially with mix weight
	filtered = FFT(LocalBuf(fftSize ! chans), in);

	frozenChains.do { |frozen, i|
		var mix = mixes[i];
		filtered = filtered.collect { |chain, i|
			// var copy = PV_Copy(frozen, LocalBuf(fftSize));
			// var mul = PV_MagMul(copy, frozen);
			var gated = PV_MagBelow(frozen, Amplitude.ar(in[i], 0.01, 2, 500));
			PV_Morph(chain, gated, mix)
		};
	};

	sig = IFFT(filtered);
	sig = Limiter.ar(sig);
	// sig = Select.ar(mixes.sum > 0, [inA, sig]); // to prevent latency when off
	Out.ar(out, sig);
}).add;


SynthDef(\reverb, {
	arg
	predelay = 0.0,
	input_diff_1 = 1,
	input_diff_2 = 1,
	bandwidth = 0.1,		// input bandwidth
	decay = 0.9,	// tank decay
	decay_diff_1 = 1,
	decay_diff_2 = 1,
	damping = 0.999, // tank bandwidth
	shimmerMix = 0,
	pitchShift = 12,
	amp = 1,
	bus = 0;

	var src, input, local, sig, shimmerMixLag;
	var input_diff = [ input_diff_1, input_diff_2 ];
	var dltimes;
	var tank0, tank1, tankdelays0, tankdelays1, outdelaysL, outdelaysR;
	var n_out_0, n_out_1, n_out_2, n_out_3, n_out_4, n_out_5, n_out_6;

	src = In.ar(bus, ~totalChans);
	src = Splay.ar(src);

	input = Integrator.ar(
		DelayC.ar(src.mean * bandwidth, 0.08, predelay),
		coef: 1 - bandwidth
	);

	// [142,107,379,277]/29761;
	dltimes = [ 0.0047713450488895, 0.0035953092974026, 0.012734787137529, 0.0093074829474816 ];


	dltimes.do { |it i|
		input = AllpassN.ar(input, it, it, decaytime: input_diff[ i.trunc(2) / 2 ]);
	};
	///////////////////////////////////Tank///////////

	// [ 672, 4453, 1800, 3720  ]/ 27961
	tankdelays0 = [ 0.022579886428547, 0.1496253486106, 0.060481838647895, 0.12499579987232 ];

	// [908, 4217, 2656, 3163] / 27961
	tankdelays1 = [ 0.030509727495716, 0.14169550754343, 0.089244313027116, 0.10628003091294 ];

	local = LocalIn.ar(2);
	////////////////////////// 0 //////////////////

	n_out_1 = AllpassL.ar(
		input + local[1],
		0.4,
		// (tankdelays0[0] + SinOsc.ar(0.7,mul:0.00025)),
		(tankdelays0[0] + LFNoise2.ar(0.7,mul:0.00025)),
		decaytime: decay_diff_1
	);

	tank0 = DelayC.ar(
		n_out_1,
		tankdelays0[1],
		tankdelays0[1]
	);

	// n_out_2 = OnePole.ar(tank0, 1 - damping);
	n_out_2	= Integrator.ar(tank0 * ( 1 - damping ), damping) * decay;

	n_out_3 = AllpassL.ar(
		n_out_2,
		tankdelays0[2],
		tankdelays0[2],
		decaytime: decay_diff_2
	);

	tank0 = DelayC.ar(
		n_out_3,
		tankdelays0[3],
		tankdelays0[3] - ControlDur.ir
	) * decay;

	////////////////////////////// 1 ///////////////

	n_out_4 = AllpassL.ar(
		input + local[0],
		0.4,
		// (tankdelays1[0] + SinOsc.ar(0.71, mul:0.00018)),
		(tankdelays1[0] + LFNoise2.kr(0.71, mul:0.00018)),
		decaytime: decay_diff_1
	);

	tank1 = DelayC.ar(
		n_out_4,
		tankdelays1[1],
		tankdelays1[1]
	);

	n_out_5	= Integrator.ar(tank1 * ( 1 - damping ), damping) * decay;

	n_out_6 = AllpassL.ar(
		n_out_5,
		tankdelays1[2],
		tankdelays1[2],
		decaytime: decay_diff_2
	);

	tank1 = DelayC.ar(
		n_out_6,
		tankdelays1[3],
		tankdelays1[3] - ControlDur.ir

	) * decay;

	LocalOut.ar([
		tank0 * -1,
		tank1 * -1
	]);

	// [266,  2974, 1913, 1996, 1990, 187,  1066] / 29761
	outdelaysL = [ 0.0089378717113, 0.099929437854911, 0.064278754074124, 0.067067638856221, 0.066866032727395, 0.0062833910150869, 0.035818688888142 ];

	// [353, 3627, 1228, 2673, 2111, 335, 121] / 29761
	outdelaysR = [ 0.011861160579282, 0.12187090487551, 0.041262054366453, 0.089815530392124, 0.070931756325392, 0.011256342192803, 0.0040657235979974 ];

	sig = Mix(
		[
			Mix([
				DelayN.ar( n_out_4, outdelaysL[0] ),
				DelayN.ar( n_out_4, outdelaysL[1] ),
				DelayN.ar( n_out_5, outdelaysL[2] ).neg,
				DelayN.ar( n_out_6, outdelaysL[3] ),
				DelayN.ar( n_out_1, outdelaysL[4] ).neg,
				DelayN.ar( n_out_2, outdelaysL[5] ).neg,
				DelayN.ar( n_out_3, outdelaysL[6] ).neg
			])
			,
			Mix([
				DelayN.ar( n_out_1, outdelaysR[0] ),
				DelayN.ar( n_out_1, outdelaysR[1] ),
				DelayN.ar( n_out_2, outdelaysR[2] ).neg,
				DelayN.ar( n_out_3, outdelaysR[3] ),
				DelayN.ar( n_out_4, outdelaysR[4] ).neg,
				DelayN.ar( n_out_5, outdelaysR[5] ).neg,
				DelayN.ar( n_out_6, outdelaysR[6] ).neg
			])
	]);

	sig = SplayAz.ar(~totalChans, sig);

	shimmerMixLag = Lag.kr(shimmerMix, 5);

	// shimmer / pitch shift
	sig = ((1-shimmerMixLag)*sig) + (shimmerMixLag*PitchShift.ar(sig, pitchRatio: (2 ** (pitchShift / 12)), pitchDispersion: 0.01, timeDispersion: 0.1));

	XOut.ar(bus, \mix.kr(0, 0.5), sig);
}).add;


SynthDef(\fxTail, {
	Out.ar(\out.ir(0), Limiter.ar(In.ar(\in.ir(0), ~totalChans)));
}).add;

SynthDef(\directOut, {
	var decoded, sig, hoa;
	var rttFreq = \rttFreq.kr(0, 0.1);

	// Encode
	sig = FoaEncode.ar(In.ar(\in.ir(0), ~totalChans), ~encoder);

	// Transform
	sig = FoaRTT.ar(
		sig,
		LFDNoise3.ar(rttFreq, pi, add: pi),
		LFDNoise3.ar(rttFreq**(1/3), pi, add: pi),
		LFDNoise3.ar(rttFreq**(2/3), pi, add: pi)
	);

	sig = FoaPush.ar(sig, \pushAngle.kr(0, 0.2));

	sig = FoaRTT.ar(
		sig,
		\rotX.kr(0),
		0,
		\rotY.kr(0)
	);

	sig = AmbiVerbSC.ar(sig, \reverbMix.kr(0.1, 0.2), 0.01, lowRT: 6, highRT: 4, size: 'Metallener Saal');

	hoa = FoaDecode.ar(FoaNFC.ar(sig, AtkHoa.refRadius), ~decoder);
	hoa = VSTPlugin.ar(hoa, hoa.size);

	if (~output == \cube) {
		sig = HoaDecodeMatrix.ar(hoa, ~hoaMatrix);
	}
	{
		sig = FoaDecode.ar(sig, ~decoder);
	};

	Out.ar(\out.ir(0), sig);
}).add;