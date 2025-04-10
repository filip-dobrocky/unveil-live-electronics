(
~micIns = #[0, 1];
~nLoops = 3;
~totalChans = ~micIns.size + ~nLoops;
~maxLoopLen = 30;

s.waitForBoot({
	Buffer.freeAll;

	~preBus = Bus.audio(s, ~totalChans);
	~postBus = Bus.audio(s, ~totalChans);
	~outBus = Bus.audio(s, ~totalChans);

	~buffers = Array.fill(~nLoops, { Buffer.alloc(s, (~maxLoopLen * s.sampleRate).ceil) });

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

)

~loopers[0].set(\trig, 1, \run, 1, \recGain, 1, \fbGain, 1, \xfade, 0.02);

~loopers[0].set(\run, 0, \recGain, 0, \fbGain, 1);

~loopers[2].get(\fbBus, { |value| value.postln });

~reso.set(\mix, 0.4);
~reso.set(\freq, 200);

PeakMonitor(~preBus);
PeakMonitor(~postBus);
~preBus

s.options.numInputBusChannels