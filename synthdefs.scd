SynthDef(\directIn, {
		var sig;
		sig = SoundIn.ar(\ins.ir(~micIns));
		sig = sig * \inAmps.kr(~micAmps);
		sig = sig * \gain.kr(1);
		sig = Compander.ar(sig, sig,
			\thresh.kr(0.5),
			1,
			1 / \ratio.kr(4),
			0.01,
			0.1
		);
		Out.ar(\out.ir(0), sig * \amp.kr(1));
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
		mix1 = 0, mix2 = 0, mix3 = 0, amp = 1;

		var in, loopIns, mixes, chainIn, frozenChains, freezeTrig, filtered, final, sig, ptrs, chainWet;
		var fftSize = 1024;
		var chans =  ~micIns.size;

		in = In.ar(inBus, chans);

		ptrs = In.ar(ptrBus, ~nLoops);
		loopIns = buffers.collect { |buf, i|
			BufRd.ar(1, buf, ptrs[i]);
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
		sig = amp * sig;
		Out.ar(out, sig);
	}).add;

	SynthDef(\reverb, {
		arg
		predelay = 0.001,
		inputDiff1 = 1,
		inputDiff2 = 1,
		bandwidth = 0.1,
		decay = 0.9,
		decayDiff1 = 1,
		decayDiff2 = 1,
		damping = 0.999,
		shimmerMix = 0,
		pitchShift = 12,
		bus = 0;

		var src, input, local, sig, shimmerMixLag;
		var dlTimesInput, dlTimesTank1, dlTimesTank2;
		var output, numChans;

		// Read in multichannel audio
		src = In.ar(bus, ~totalChans);  // or replace ~totalChans with a fixed value if needed
		numChans = src.size;

		// Feedback loop per channel
		local = LocalIn.ar(numChans);

		// Predelay + input bandwidth filter per channel
		input = Integrator.ar(
			DelayC.ar(src * bandwidth, 0.08, predelay),
			coef: 1 - bandwidth
		);

		// Define delay times
		dlTimesInput = [0.00477, 0.00359, 0.01273, 0.0093];
		dlTimesTank1 = [0.02257, 0.14962, 0.06048, 0.12499];
		dlTimesTank2 = [0.03050, 0.14169, 0.08924, 0.10628] * 0.5;

		// Make sure delay arrays are long enough
		while {
			dlTimesInput.size < numChans
		} {
			dlTimesInput = dlTimesInput ++ dlTimesInput;
			dlTimesTank1 = dlTimesTank1 ++ dlTimesTank1;
			dlTimesTank2 = dlTimesTank2 ++ dlTimesTank2;
		};

		// Per-channel tank processing
		output = Array.fill(numChans, { |i|
			var inChan = input[i];
			var fbChan = local[i];

			var chain, dti, dt1, dt2;

			dti = dlTimesInput[i];
			dt1 = dlTimesTank1[i];
			dt2 = dlTimesTank2[i];

			chain = inChan + fbChan;

			// Input diffusion
			chain = AllpassN.ar(chain, dti, dti, decaytime: inputDiff1);
			chain = AllpassN.ar(chain, dti * 1.1, dti * 1.1, decaytime: inputDiff2);

			// Tank feedback structure
			chain = AllpassL.ar(chain, dt1, dt1 + LFNoise2.kr(0.5, 0.0001), decaytime: decayDiff1);
			chain = DelayC.ar(chain, dt1, dt1);
			chain = Integrator.ar(chain * (1 - damping), damping) * decay;

			chain = AllpassL.ar(chain, dt2, dt2, decaytime: decayDiff2);
			chain = DelayC.ar(chain, dt2, dt2 - ControlDur.ir) * decay;

			chain
		});

		LocalOut.ar(output.neg);  // feedback loop

		shimmerMixLag = Lag.kr(shimmerMix, 5);

		// Optional shimmer (applied per channel)
		sig = ((1 - shimmerMixLag) * output)
		+ (shimmerMixLag * PitchShift.ar(output, pitchRatio: (2 ** (pitchShift / 12)), pitchDispersion: 0.01, timeDispersion: 0.1 ));

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