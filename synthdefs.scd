{ DynKlank.ar(`[Array.geom(6, 200, MouseX.kr(1.25, 3)) * MouseY.kr(1, 4), [0.5, 0.2, 0.2, 0.1, 0.1, 0.1], [2, 1.8, 1.5, 1, 1, 1]], LPF.ar(Impulse.ar(MouseX.kr(0.5, 30)), LFDNoise3.kr(5).range(100, 2500))) ! 2 * 0.2}.play;

(
// change freqs and ringtimes with mouse
{    var freqs, ringtimes;
	freqs = [800, 1071, 1153, 1723] * MouseX.kr(0.5, 2, 1);
	ringtimes = [1, 1, 1, 1] * MouseY.kr(0.1, 10, 1);
	DynKlank.ar(`[freqs, nil, ringtimes ], SoundIn.ar(0))
}.play;
)

(
SynthDef(\reverb,

	{ arg
		mix = 1,
		predelay = 0.0,
		inputDiff1 = 1,
		inputDiff2 = 1,
		bandwidth = 0.1,		// input bandwidth
		decay = 0.9,	// tank decay
		decayDiff1 = 1,
		decayDiff2 = 1,
		damping = 0.999, // tank bandwidth
		shimmerMix = 0,
		pitchShift = 12,
		outBus = 0,
		inBus;


		var src, input, local, sig, shimmerMixLag;
		var inputDiff = [ inputDiff1, inputDiff2 ];
		var dlTimes;
		var tank0, tank1, tankDelays0, tankDelays1, outDelaysL, outDelaysR;
		var n_out_0, n_out_1, n_out_2, n_out_3, n_out_4, n_out_5, n_out_6;

		src = In.ar(inBus, 2);

		input = Integrator.ar(
			DelayC.ar(src.mean * bandwidth, 0.08, predelay),
			coef: 1 - bandwidth
		);

		// [142,107,379,277]/29761;
		dlTimes = [ 0.0047713450488895, 0.0035953092974026, 0.012734787137529, 0.0093074829474816 ];


		dlTimes.do { |it i|
			input = AllpassN.ar(input, it, it, decaytime: inputDiff[ i.trunc(2) / 2 ]);
		};
		///////////////////////////////////Tank///////////

		// [ 672, 4453, 1800, 3720  ]/ 27961
		tankDelays0 = [ 0.022579886428547, 0.1496253486106, 0.060481838647895, 0.12499579987232 ];

		// [908, 4217, 2656, 3163] / 27961
		tankDelays1 = [ 0.030509727495716, 0.14169550754343, 0.089244313027116, 0.10628003091294 ];

		local = LocalIn.ar(2);
		////////////////////////// 0 //////////////////

		n_out_1 = AllpassL.ar(
			input + local[1],
			0.4,
			// (tankDelays0[0] + SinOsc.ar(0.7,mul:0.00025)),
			(tankDelays0[0] + LFNoise2.ar(0.7,mul:0.00025)),
			decaytime: decayDiff1
		);

		tank0 = DelayC.ar(
			n_out_1,
			tankDelays0[1],
			tankDelays0[1]
		);

		// n_out_2 = OnePole.ar(tank0, 1 - damping);
		n_out_2	= Integrator.ar(tank0 * ( 1 - damping ), damping) * decay;

		n_out_3 = AllpassL.ar(
			n_out_2,
			tankDelays0[2],
			tankDelays0[2],
			decaytime: decayDiff2
		);

		tank0 = DelayC.ar(
			n_out_3,
			tankDelays0[3],
			tankDelays0[3] - ControlDur.ir
		) * decay;

		////////////////////////////// 1 ///////////////

		n_out_4 = AllpassL.ar(
			input + local[0],
			0.4,
			// (tankDelays1[0] + SinOsc.ar(0.71, mul:0.00018)),
			(tankDelays1[0] + LFNoise2.kr(0.71, mul:0.00018)),
			decaytime: decayDiff1
		);

		tank1 = DelayC.ar(
			n_out_4,
			tankDelays1[1],
			tankDelays1[1]
		);

		n_out_5	= Integrator.ar(tank1 * ( 1 - damping ), damping) * decay;

		n_out_6 = AllpassL.ar(
			n_out_5,
			tankDelays1[2],
			tankDelays1[2],
			decaytime: decayDiff2
		);

		tank1 = DelayC.ar(
			n_out_6,
			tankDelays1[3],
			tankDelays1[3] - ControlDur.ir

		) * decay;

		LocalOut.ar([
			tank0 * -1,
			tank1 * -1
		]);

		// [266,  2974, 1913, 1996, 1990, 187,  1066] / 29761
		outDelaysL = [ 0.0089378717113, 0.099929437854911, 0.064278754074124, 0.067067638856221, 0.066866032727395, 0.0062833910150869, 0.035818688888142 ];

		// [353, 3627, 1228, 2673, 2111, 335, 121] / 29761
		outDelaysR = [ 0.011861160579282, 0.12187090487551, 0.041262054366453, 0.089815530392124, 0.070931756325392, 0.011256342192803, 0.0040657235979974 ];

		sig = Mix([
				DelayN.ar( n_out_4, outDelaysL[0] ),
				DelayN.ar( n_out_4, outDelaysL[1] ),
				DelayN.ar( n_out_5, outDelaysL[2] ).neg,
				DelayN.ar( n_out_6, outDelaysL[3] ),
				DelayN.ar( n_out_1, outDelaysL[4] ).neg,
				DelayN.ar( n_out_2, outDelaysL[5] ).neg,
				DelayN.ar( n_out_3, outDelaysL[6] ).neg,
				DelayN.ar( n_out_1, outDelaysR[0] ),
				DelayN.ar( n_out_1, outDelaysR[1] ),
				DelayN.ar( n_out_2, outDelaysR[2] ).neg,
				DelayN.ar( n_out_3, outDelaysR[3] ),
				DelayN.ar( n_out_4, outDelaysR[4] ).neg,
				DelayN.ar( n_out_5, outDelaysR[5] ).neg,
				DelayN.ar( n_out_6, outDelaysR[6] ).neg
			]);

		shimmerMixLag = Lag.kr(shimmerMix, 5);

		// shimmer (pitch shift)
		sig = ((1-shimmerMixLag)*sig) +
		(shimmerMixLag*PitchShift.ar(sig, pitchRatio:(2**(pitchShift/12))));

		XOut.ar(outBus, mix, sig);
}).add;

)

(
~totalChans = 2;
SynthDef(\reso1, {
	arg freq = #[440, 660, 880], decay = 1.0, amp = 1, harmonics = 10, bus = 0, mix = 0;
	var sig, in;

	in = In.ar(bus, ~totalChans);
	sig = Splay.ar(RLPF.ar(CombN.ar(in, 0.2, freq.reciprocal, decay), harmonics*freq.lag(2), 0.6));
	XOut.ar(bus, mix.lag, sig);
}).add;

~freqs = #[440,880,300];

SynthDef(\reso2, {
	arg freqs = #[440, 660, 880, 1320], amps = #[1, 1, 1, 1], decays = #[1, 1, 1, 1], amp = 1, harmonics = 10, bus = 0, mix = 0;
	var sig, in, minF;

	minF = freqs.reduce({ |a, b| a.min(b) });
	in = In.ar(bus, ~totalChans);
	sig = DynKlank.ar(`[freqs, amps, decays], in) * 0.2;
	sig = LPF.ar(sig, harmonics*minF);
	sig = Limiter.ar(sig) * 0.2;

	XOut.ar(bus, mix.lag, sig);
}).add;
)

a = {Impulse.ar(1) ! 2}.play;
q = Synth(\reso2, [\mix, 0.9], addAction: 'addToTail');
r = Synth(\reverb, [\shimmerMix, 0.5, \mix, 0.6, \damping, 0.5],  addAction: 'addToTail')

q.set(\mix, 1)
q.set(\harmonics, 10)
q.set(\freqs, [100, 120, 1000, 300])

r.set(\mix, 1)
r.set(\shimmerMix, 0.3)
r.set(\damping, 0)
r.set(\decay, 0.5)

{XOut.ar(0 , 1, PitchShift.ar(In.ar(0), 0.1, 0.25))}.play

a = {PinkNoise.ar * 0.2 ! 2}.play;

a.release
r.free

s.scope
s.freqscope

MIDIClient.init;

