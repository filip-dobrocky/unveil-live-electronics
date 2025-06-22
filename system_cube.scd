(
// === Settings ===
~micIns = #[0, 1];
~micAmps = #[1, 1];
// ~micIns = #[0];
// ~micAmps = #[1];
~nLoops = 3;
~totalChans = ~micIns.size + ~nLoops;
~maxLoopLen = 30;
s.options.blockSize = 256;
s.options.memSize = 614400;
s.options.numOutputBusChannels = 25;
s.options.numWireBufs = 512;

~output = \cube; // \binaural, \cube


// === Chords ===
~chords = [
	[440, 660, 880, 1320],
	(72 + \CM7.asNotes).midicps,
	(72 + \Em7.asNotes).midicps,
	(72 + \GM7.asNotes).midicps,
	(84 + \Dm7.asNotes).midicps,
	(72 + \B7.asNotes).midicps,
	(72 + \Am7.asNotes).midicps,
	(72 + \BbM7.asNotes).midicps,
] * 0.5;

// === MIDI mapping ===
~recBtnNotes = Array.series(~nLoops, 73, 1);
~playBtnNotes = Array.series(~nLoops, 41, 1);
~loopLvlCCs = Array.series(~nLoops, 77, 1);
~xfadeCCs = Array.series(~nLoops, 80, 1);
~chordBtnNotes = Array.series(4, 57, 1) ++ Array.series(4, 89, 1);
~masterLvlCC = 84;
~inputLvlCC = 83;
~inputGainCC = 55;
~inputCThreshCC = 35;
~inputCRatioCC = 19;
~fx1CtlCC = [13, 29, 49]; // reso
~fx2CtlCC = [14, 30, 50]; // pitch shift
~fx3CtlCC = [15, 31, 51]; // destroyer
~fx4CtlCC = [16, 32, 52]; // reverb
~fx5CtlCC = [17, 33, 53]; // spectral
~fx6CtlCC = [18, 34, 54]; //
~fx8CtlCC = [20, 36, 56];
~fxToggleNote = 105;


// === Utils ===
~midiLvlScale = { |val|
	val.linexp(0, 127, 0.0005, 4).thresh(0.00051)
};


s.waitForBoot({

	// === Init ===

	Buffer.freeAll;

	~inBus = Bus.audio(s, ~micIns.size);
	~preBus = Bus.audio(s, ~totalChans);
	~postBus = Bus.audio(s, ~totalChans);
	~outBus = Bus.audio(s, ~totalChans);

	~ptrBus = Bus.audio(s, ~nLoops);

	~buffers = Array.fill(~nLoops, { Buffer.alloc(s, (~maxLoopLen * s.sampleRate).ceil) });

	~transferFunc = Buffer.alloc(s, 512);
	~transferFunc.cheby([1,1,0,1,0,1]);

	MIDIIn.connectAll;

	s.sync;

	// === Ambisonics ===
	~cubeDirections = [ [ 0, 0 ], [ 330, 0 ], [ 300, 0 ], [ 270, 0 ], [ 240, 0 ], [ 210, 0 ], [ 180, 0 ], [ 150, 0 ], [ 120, 0 ], [ 90, 0 ], [ 60, 0 ], [ 30, 0 ], [ 337.5, 30 ], [ 292.5, 30 ], [ 247.5, 30 ], [ 202.5, 30 ], [ 157.5, 30 ], [ 112.5, 30 ], [ 67.5, 30 ], [ 22.5, 30 ], [ 315, 60 ], [ 225, 60 ], [ 135, 60 ], [ 45, 60 ], [ 0, 90 ] ].degrad;

	~encoder = FoaEncoderMatrix.newPanto(~totalChans);
	~decoder = switch (~output)
	{ \cube } { FoaDecoderMatrix.newHoa1 }
	{ \binaural } { FoaDecoderKernel.newCIPIC }
	{ FoaDecoderMatrix.newStereo };

	if (~output == \cube) {
		~hoaMatrix = HoaMatrixDecoder.newModeMatch(
			~cubeDirections,
			\energy,
			\rms,
			1
		);
	};

	s.sync;


	// === SynthDefs ===

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

	// === Synths, routing ===
	s.sync;


	~directIn = Synth(\directIn, [\ins, ~micIns, \out, ~inBus]);

	~spectral = Synth.after(~directIn, \spectral, [
		\inBus, ~inBus,
		\ptrBus, ~ptrBus,
		\out, ~preBus,
		\buffers, ~buffers.collect({ |buf| buf.bufnum })
	]);

	~loopers = ~buffers.collect({ |buf, i|
		var channel = ~micIns.size + i;
		Synth.after(~directIn, \looper, [
			\buf, buf.bufnum,
			\in, ~postBus.subBus(0, ~micIns.size),
			\out, ~preBus.subBus(channel),
			\ptrBus, ~ptrBus.subBus(i)
		]);
	});

	~reso = Synth(\reso, [\bus, ~preBus], addAction: 'addToTail');
	~pitchShifter = Synth(\pitchShifter, [\bus, ~preBus], addAction: 'addToTail');
	~destroyer = Synth(\destroyer, [\bus, ~preBus], addAction: 'addToTail');
	~reverb = Synth(\reverb, [\bus, ~preBus, \shimmerMix, 0, \mix, 0, \damping, 0.9],  addAction: 'addToTail');
	Synth(\fxTail, [\in, ~preBus, \out, ~postBus], addAction: 'addToTail');
	~directOut = Synth(\directOut, [\in, ~preBus, \out, 0, \pushAngle, pi/2], addAction: 'addToTail');

	~fx = [~reso, ~pitchShifter, ~destroyer, ~reverb];

	// === Controls ===
	s.sync;

	~playBtnStates = Array.fill(~nLoops, { false });
	~recBtnStates = Array.fill(~nLoops, { false });
	~loopStates = Array.fill(~nLoops, { false });
	~loopAmps = Array.fill(~nLoops, { 1 });


	~clearRoutines = Array.fill(~nLoops, { });

	~fxStates = Array.fill(~fx.size, { 0 });
	~fxOn = { |on|
		~fx.do({ |fx, i|
			if (on) {
				fx.set(\mix, ~fxStates[i]);
			}
			{
				fx.get(\mix, { |val| ~fxStates[i] = val });
				fx.set(\mix, 0);
			};
		});
	};

	MIDIdef.noteOn(\buttonsOn, {
		arg val, num;
		var recIndex, playIndex;
		recIndex = ~recBtnNotes.indexOf(num);
		playIndex = ~playBtnNotes.indexOf(num);

		if (recIndex != nil) {

			// long press: clear
			~clearRoutines[recIndex] = Routine.new({
				2.wait;
				~buffers[recIndex].zero;
				~loopStates[recIndex] = false;
				~recBtnStates[recIndex] = false;
				"buffer % cleared".format(recIndex).postln;
			}).play;

			if (~recBtnStates[recIndex] == false)
			{
				// start recording
				if (~loopStates[recIndex] == false)
				{
					~loopers[recIndex].set(\recTrig, 1, \playTrig, 1, \run, 1, \recGain, 1, \fbGain, 1);
				}
				{
					~loopers[recIndex].set(\run, 0, \recGain, 1, \fbGain, -1.dbamp,
						\loopAmp, ~loopAmps[recIndex]);
				};

				("recording into buffer " ++ recIndex).postln;

				~recBtnStates[recIndex] = true;
				~loopStates[recIndex] = true;
			}
			{
				// stop recording, continue playing
				("recorded into buffer " ++ recIndex).postln;
				~loopers[recIndex].set(\run, 0, \recGain, 0, \fbGain, 1,
					\loopAmp, ~loopAmps[recIndex]);
				~recBtnStates[recIndex] = false;
				~playBtnStates[recIndex] = true;
			};

		};

		if (playIndex != nil) {
			if (~playBtnStates[playIndex] == false) {
				// start playing
				~loopers[playIndex].set(\playTrig, 1, \run, 0, \reclev, 0, \prelev, 1,
					\loopAmp, ~loopAmps[playIndex]);
				~playBtnStates[playIndex] = true;
				"loop % playing".format(playIndex).postln;
			}
			{
				// stop playing
				~loopers[playIndex].set(\run, 0, \reclev, 0, \prelev, 1, \loopAmp, 0);
				~playBtnStates[playIndex] = false;
				"loop % stopped".format(playIndex).postln;
			};

		};
	});

	MIDIdef.noteOff(\buttonsOff, {
		arg val, num;
		var recIndex = ~recBtnNotes.indexOf(num);
		if (recIndex != nil) {
			~clearRoutines[recIndex].stop;
		};
	});

	MIDIdef.noteOn(\chordButtons, {
		arg val, num;
		var index = ~chordBtnNotes.indexOf(num);
		if (index != nil) {
			~reso.set(\freqs, ~chords[index]);
		};
	});

	MIDIdef.cc(\loopLevels, {
		arg val, num;
		var loopIndex, loopAmp;
		loopIndex = ~loopLvlCCs.indexOf(num);
		if (loopIndex != nil) {
			loopAmp = ~midiLvlScale.(val);
			~loopAmps[loopIndex] = loopAmp;
			if (~playBtnStates[loopIndex]) {
				~loopers[loopIndex].set(\loopAmp, loopAmp);
			};
			"loop % level: % dB".format(loopIndex, loopAmp.ampdb).postln;
		};
	});

	MIDIdef.cc(\xfades, {
		arg val, num;
		var index, xfade;
		index = ~xfadeCCs.indexOf(num);
		if (index != nil) {
			xfade = val.linlin(0, 127, 0, 1);
			~spectral.set("mix" ++ (index+1), xfade);
			"xfade %: %".format(index, xfade).postln;
		};
	});

	MIDIdef.cc(\masterLevel, {
		arg val, num;
		var amp;
		if (num == ~masterLvlCC) {
			amp = ~midiLvlScale.(val);
			s.volume.volume = amp.ampdb;
			"master level: % dB".format(s.volume.volume).postln;
		}
	});

	MIDIdef.cc(\inputControls, {
		arg val, num;
		var scaled;

		switch (num)
		{~inputLvlCC} {
			scaled = ~midiLvlScale.(val);
			~directIn.set(\amp, scaled);
			"input level: % dB".format(scaled.ampdb).postln;
		}
		{~inputGainCC} {
			scaled = val.linlin(0, 127, 0, 18);
			~directIn.set(\gain, scaled.dbamp);
			"input gain: % dB".format(scaled).postln;
		}
		{~inputCThreshCC} {
			scaled = val.linlin(0, 127, 0.001, 1);
			~directIn.set(\thresh, scaled);
			"input compressor threshold: %".format(scaled).postln;
		}
		{~inputCRatioCC} {
			scaled = val.linlin(0, 127, 1, 8);
			~directIn.set(\ratio, scaled);
			"input compressor ratio: 1:%".format(scaled).postln;
		}{};

	});

	MIDIdef.cc(\fxControls, {
		arg val, num;
		var scaled;

		switch (num)
		{~fx1CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~reso.set(\mix, scaled);
			"resonator mix: %".format(scaled).postln;

		}
		{~fx1CtlCC[1]} {
			scaled = (val - 64).midiratio;
			~reso.set(\freqScale, scaled);
			"resonator f scale: %".format(scaled).postln;
		}
		{~fx1CtlCC[2]} {
			scaled = val.linlin(0, 127, 0.001, 2);
			~reso.set(\decayScale, scaled);
			"resonator decay scale: %".format(scaled).postln;
		}
		{~fx2CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~pitchShifter.set(\mix, scaled);
			"pitch shifter mix: %".format(scaled).postln;

		}
		{~fx2CtlCC[1]} {
			scaled = (val - 64).midiratio;
			~pitchShifter.set(\ratio, scaled);
			"pitch shifter ratio: %".format(scaled).postln;
		}
		{~fx2CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 1);

			": %".format(scaled).postln;
		}
		{~fx3CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~destroyer.set(\mix, scaled);
			"destroyer mix: %".format(scaled).postln;
		}
		{~fx3CtlCC[1]} {
			scaled = val.linlin(0, 127, 0, 1);
			~destroyer.set(\crush, scaled);
			"destroyer crush: %".format(scaled).postln;
		}
		{~fx3CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 1);
			~destroyer.set(\bass, scaled);
			"destroyer bass: %".format(scaled).postln;
		}
		{~fx4CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~reverb.set(\mix, scaled);
			"reverb mix: %".format(scaled).postln;

		}
		{~fx4CtlCC[1]} {
			scaled = val.linlin(0, 127, 0, 1);
			~reverb.set(\shimmerMix, scaled);
			"reverb shimmer mix: %".format(scaled).postln;

		}
		{~fx4CtlCC[2]} {
			scaled = val.linlin(0, 127, 0.001, 0.99);
			~reverb.set(\damping, scaled);
			"reverb damping: %".format(scaled).postln;
		}

		{~fx5CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			": %".format(scaled).postln;

		}
		{~fx5CtlCC[1]} {
			scaled = val.linlin(0, 127, 0, 1);
			~spectral.set(\freezeThresh, scaled);
			"spectral freeze threshold: %".format(scaled).postln;

		}
		{~fx5CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 2);
			~spectral.set(\amp, scaled);
			"spectral amp: %".format(scaled).postln;
		}

		{~fx6CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~directOut.set(\reverbMix, scaled);
			"ambiverb mix: %".format(scaled).postln;
		}
		{~fx6CtlCC[1]} {
			scaled = val.linlin(0, 127, -pi, pi);
			": %".format(scaled).postln;
		}
		{~fx6CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 200);
			~directOut.set(\rttFreq, scaled);
			"rtt freq: %".format(scaled).postln;
		}

		{~fx8CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, pi / 2);
			~directOut.set(\pushAngle, scaled);
			"push angle: %".format(scaled).postln;
		}
		{~fx8CtlCC[1]} {
			scaled = val.linlin(0, 127, -pi, pi);
			~directOut.set(\rotY, scaled);
			"tumble: %".format(scaled).postln;
		}
		{~fx8CtlCC[2]} {
			scaled = val.linlin(0, 127, pi, -pi);
			~directOut.set(\rotX, scaled);
			"rotate: %".format(scaled).postln;
		}

		{ /*default case*/ };

	});

	~fxToggleState = true;
	MIDIdef.noteOn(\fxToggle, {
		arg val, num;

		~fxToggleState = ~fxToggleState.not;
		~fxOn.(~fxToggleState);

	}, ~fxToggleNote);

});

)

(
// GUI

this.executeFile(~dir +/+ "stopwatch.scd");
~dir = "E:/Projects/_live_electronic/CMKK-live-electronic";
fork {
	VSTPlugin.search(s);
	s.sync;
	~vis = VSTPluginController(~directOut);
	~vis.open('EnergyVisualizer', verbose: true);
	s.sync;
	~vis.editor;
}
)

// TEST SOUND
(
a = {Out.ar(~preBus,
	BPF.ar(WhiteNoise.ar, Rand(600 ! ~totalChans, 1000), 0.1)
)}.play
)
a.free

~fxOnOff.(true)

~loopers[2].get(\fbBus, { |value| value.postln });

~reso.set(\mix, 0.6)·;
~reso.set(\freqs, Array.geom(4, 100, 1.1));
~reverb.set(\mix, 0.5);

~spectral.set(\freezeThresh, 0.9)

~directIn.set(\inAmps, [1, 0]);

PeakMonitor(~preBus);
PeakMonitor(~postBus);
~preBus
2.clip(0, 1)

(
a = {Out.ar(~preBus,
	BPF.ar(WhiteNoise.ar, Rand(600 ! ~totalChans, 1000), 0.1) *
	(LFDNoise3.kr(7 ! ~totalChans))
)}.play
)

MIDIIn.connectAll;
MIDIFunc.trace(true);
MIDIFunc.trace(false);

s.options.numInputBusChannels

AmbiVerbGUI(s)