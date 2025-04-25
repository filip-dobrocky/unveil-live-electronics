(
~micIns = #[0, 1];
~nLoops = 3;
~totalChans = ~micIns.size + ~nLoops;
~maxLoopLen = 30;

// MIDI mapping
~recBtnNotes = Array.series(~nLoops, 73, 1);
~playBtnNotes = Array.series(~nLoops, 41, 1);

s.options.blockSize = 256;

s.waitForBoot({
	Buffer.freeAll;

	~preBus = Bus.audio(s, ~totalChans);
	~postBus = Bus.audio(s, ~totalChans);
	~outBus = Bus.audio(s, ~totalChans);

	~buffers = Array.fill(~nLoops, { Buffer.alloc(s, (~maxLoopLen * s.sampleRate).ceil) });

	MIDIIn.connectAll;

	s.sync;

	SynthDef(\directIn, {
		Out.ar(\out.ir(0), SoundIn.ar(\in.ir(~micIns)));
	}).add;

	SynthDef(\looper, {
		var mic, trig, max, ptr, loop, rec, feedback;
		var xfade = \xfade.kr(0.02);
		var buf = \buf.kr(0);

		mic = Mix.ar(InFeedback.ar(\in.ir(~micIns)));
		trig = Trig1.ar(\trig.tr(0), ControlDur.ir);
		max = Sweep.ar(trig, SampleRate.ir * \run.kr(0));
		ptr = Phasor.ar(trig, 1, 0, max, 0);
		loop = BufRd.ar(1, buf, ptr);

		rec = Mix.ar([
			mic * \recGain.kr(0).varlag(xfade,-2),
			loop * \fbGain.kr(0).varlag(xfade,-2)
		]);
		rec = rec * \recAmp.kr(1).varlag(xfade,-2);
		BufWr.ar(rec, buf, ptr);

		loop = loop * \loopAmp.kr(1).varlag(xfade,-2);
		Out.ar(\out.ir(0), loop);
	}).add;

	s.sync;

	~directIn = Synth(\directIn, [\in, ~micIns, \out, ~preBus]);
	~loopers = ~buffers.collect({ |buf, i|
		var channel = ~micIns.size + i;
		Synth.after(~directIn, \looper, [\buf, buf.bufnum, \in, ~postBus.subBus(0, ~micIns.size), \out, ~preBus.subBus(channel)
		]);
	});

	SynthDef(\reso, {
		arg freq = 440, decay = 1.0, amp = 1, harmonics = 10, bus = 0, mix = 0.5;
		var sig, in;

		in = In.ar(bus, ~totalChans);
		sig = RLPF.ar(CombN.ar(in, 0.2, freq.reciprocal, decay), harmonics*freq, 0.6);
		XOut.ar(bus, mix, sig);
	}).add;

	SynthDef(\fxTail, {
		Out.ar(\out.ir(0), In.ar(\in.ir(0), ~totalChans));
	}).add;

	SynthDef(\directOut, {
		Out.ar(\out.ir(0), Splay.ar(In.ar(\in.ir(0), ~totalChans)));
	}).add;

	s.sync;

	~reso = Synth(\reso, [\bus, ~preBus], addAction: 'addToTail');
	Synth(\fxTail, [\in, ~preBus, \out, ~postBus], addAction: 'addToTail');
	Synth(\directOut, [\in, ~preBus, \out, 0], addAction: 'addToTail');
});

~playBtnStates = Array.fill(~nLoops, { false });
~recBtnStates = Array.fill(~nLoops, { false });
~loopStates = Array.fill(~nLoops, { false });


~clearRoutines = Array.fill(~nLoops, { });

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
			("buffer " ++ recIndex ++ " cleared").postln;
		}).play;

		if (~recBtnStates[recIndex] == false)
		{
			// start recording
			if (~loopStates[recIndex] == false)
			{
				~loopers[recIndex].set(\trig, 1, \run, 1, \recGain, 1, \fbGain, 1, \xfade, 0.02)
			}
			{
				~loopers[recIndex].set(\run, 0, \recGain, 1, \fbGain, -1.dbamp)
			};

			("recording into buffer " ++ recIndex).postln;

			~recBtnStates[recIndex] = true;
			~loopStates[recIndex] = true;
		}
		{
			// stop recording, continue playing
			("recorded into buffer " ++ recIndex).postln;
			~loopers[recIndex].set(\run, 0, \recGain, 0, \fbGain, 1);
			~recBtnStates[recIndex] = false;
		};

	};

	if (playIndex != nil) {
		if (~playBtnStates[playIndex]) {
			// stop playing
			~loopers[playIndex].set(\run, 0, \reclev, 0, \prelev, 1, \loopAmp, 1);
			~playBtnStates[playIndex] = false;
		}
		{
			// start playing
			~loopers[playIndex].set(\run, 0, \reclev, 0, \prelev, 1, \loopAmp, 0);
			~playBtnStates[playIndex] = true;
		};

	};
});

MIDIdef.noteOff(\buttonsOff, {
	arg val, num;
	var recIndex;
	recIndex = ~recBtnNotes.indexOf(num);

	if (recIndex != nil) {
		"off".postln;
		~clearRoutines[recIndex].stop;
	};
});

)


~loopers[0].set(\trig, 1, \run, 1, \recGain, 1, \fbGain, 1, \xfade, 0.02);

~loopers[0].set(\run, 0, \recGain, 0, \fbGain, 1);

~loopers[2].get(\fbBus, { |value| value.postln });

~reso.set(\mix, 0);
~reso.set(\freq, 200);

PeakMonitor(~preBus);
PeakMonitor(~postBus);
~preBus

MIDIFunc.trace(true);
MIDIFunc.trace(false);

s.options.numInputBusChannels