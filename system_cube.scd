(
~dir = "/home/filip/Documents/_live_electronics";

// === Settings ===
~micIns = #[0, 1];
~micAmps = #[1, 1];
// ~micIns = #[0];
// ~micAmps = #[1];
~nLoops = 3;
~totalChans = ~micIns.size + ~nLoops;
~maxLoopLen = 40;·
s.options.blockSize = 256;
s.options.memSize = 614400;
s.options.numOutputBusChannels = 25;
s.options.numWireBufs = 512;

~output = \binaural; // \binaural, \cube


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

	this.executeFile(~dir +/+ "synthdefs.scd");

	// === Synths, routing ===
	s.sync;


	~directIn = Synth(\directIn, [\ins, ~micIns, \out, ~inBus]);

	~spectral = Synth.after(~directIn, \spectral, [
		\inBus, ~inBus,
		\ptrBus, ~ptrBus,
		\out, ~preBus,
		\buffers, ~buffers.collect({ |buf| buf.bufnum }),
		\loopAmp, 1.5
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
	~reverb = Synth(\reverb, [\bus, ~preBus, \shimmerMix, 0.66, \mix, 0, \damping, 0.9],  addAction: 'addToTail');
	Synth(\fxTail, [\in, ~preBus, \out, ~postBus], addAction: 'addToTail');
	~directOut = Synth(\directOut, [\in, ~preBus, \out, 0, \pushAngle, pi/2], addAction: 'addToTail');

	~fx = [~reso, ~pitchShifter, ~destroyer, ~reverb];

	// Initial parameters
	~destroyer.set(\crush, 0.5);
	~destroyer.set(\bass, 0);
	~pitchShifter.set(\ratio, 38);
	~reso.set(\freqScale, 0.14);
	~directOut.set(\rttFreq, 22);

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
			"input level: % dB".format(scaled.round(1e-3).ampdb).postln;
		}
		{~inputGainCC} {
			scaled = val.linlin(0, 127, 0, 18);
			~directIn.set(\gain, scaled.dbamp);
			"input gain: % dB".format(scaled.round(1e-3)).postln;
		}
		{~inputCThreshCC} {
			scaled = val.linlin(0, 127, 0.001, 1);
			~directIn.set(\thresh, scaled);
			"input compressor threshold: %".format(scaled.round(1e-3)).postln;
		}
		{~inputCRatioCC} {
			scaled = val.linlin(0, 127, 1, 8);
			~directIn.set(\ratio, scaled);
			"input compressor ratio: 1:%".format(scaled.round(1e-3)).postln;
		}{};

	});

	MIDIdef.cc(\fxControls, {
		arg val, num;
		var scaled;

		switch (num)
		{~fx1CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~reso.set(\mix, scaled);
			"resonator mix: %".format(scaled.round(1e-3)).postln;

		}
		{~fx1CtlCC[1]} {
			scaled = (val - 64).midiratio;
			~reso.set(\freqScale, scaled);
			"resonator f scale: %".format(scaled.round(1e-3)).postln;
		}
		{~fx1CtlCC[2]} {
			scaled = val.linlin(0, 127, 0.001, 2);
			~reso.set(\decayScale, scaled);
			"resonator decay scale: %".format(scaled.round(1e-3)).postln;
		}
		{~fx2CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~pitchShifter.set(\mix, scaled);
			"pitch shifter mix: %".format(scaled.round(1e-3)).postln;

		}
		{~fx2CtlCC[1]} {
			scaled = (val - 64).midiratio;
			~pitchShifter.set(\ratio, scaled);
			"pitch shifter ratio: %".format(scaled.round(1e-3)).postln;
		}
		{~fx2CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 1);

			": %".format(scaled.round(1e-3)).postln;
		}
		{~fx3CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~destroyer.set(\mix, scaled);
			"destroyer mix: %".format(scaled.round(1e-3)).postln;
		}
		{~fx3CtlCC[1]} {
			scaled = val.linlin(0, 127, 0, 1);
			~destroyer.set(\crush, scaled);
			"destroyer crush: %".format(scaled.round(1e-3)).postln;
		}
		{~fx3CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 1);
			~destroyer.set(\bass, scaled);
			"destroyer bass: %".format(scaled.round(1e-3)).postln;
		}
		{~fx4CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~reverb.set(\mix, scaled);
			"reverb mix: %".format(scaled.round(1e-3)).postln;

		}
		{~fx4CtlCC[1]} {
			scaled = val.linlin(0, 127, 0, 1);
			~reverb.set(\shimmerMix, scaled);
			"reverb shimmer mix: %".format(scaled.round(1e-3)).postln;

		}
		{~fx4CtlCC[2]} {
			scaled = val.linlin(0, 127, 0.001, 0.99);
			~reverb.set(\damping, scaled);
			"reverb damping: %".format(scaled.round(1e-3)).postln;
		}

		{~fx5CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			": %".format(scaled.round(1e-3)).postln;

		}
		{~fx5CtlCC[1]} {
			scaled = val.linlin(0, 127, 0, 1);
			~spectral.set(\freezeThresh, scaled);
			"spectral freeze threshold: %".format(scaled.round(1e-3)).postln;

		}
		{~fx5CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 2);
			~spectral.set(\loopAmp, scaled);
			"spectral amp: %".format(scaled.round(1e-3)).postln;
		}

		{~fx6CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, 1);
			~directOut.set(\reverbMix, scaled);
			"ambiverb mix: %".format(scaled.round(1e-3)).postln;
		}
		{~fx6CtlCC[1]} {
			scaled = val.linlin(0, 127, -pi, pi);
			": %".format(scaled.round(1e-3)).postln;
		}
		{~fx6CtlCC[2]} {
			scaled = val.linlin(0, 127, 0, 200);
			~directOut.set(\rttFreq, scaled);
			"rtt freq: %".format(scaled.round(1e-3)).postln;
		}

		{~fx8CtlCC[0]} {
			scaled = val.linlin(0, 127, 0, pi / 2);
			~directOut.set(\pushAngle, scaled);
			"push angle: %".format(scaled.round(1e-3)).postln;
		}
		{~fx8CtlCC[1]} {
			scaled = val.linlin(0, 127, -pi, pi);
			~directOut.set(\rotY, scaled);
			"tumble: %".format(scaled.round(1e-3)).postln;
		}
		{~fx8CtlCC[2]} {
			scaled = val.linlin(0, 127, pi, -pi);
			~directOut.set(\rotX, scaled);
			"rotate: %".format(scaled.round(1e-3)).postln;
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
s.meter;
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
a.free

MIDIIn.connectAll;
MIDIFunc.trace(true);
MIDIFunc.trace(false);

s.options.numInputBusChannels

AmbiVerbGUI(s)