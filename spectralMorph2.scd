(
b = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/sul_ponticello_tremolo/Vc-pont_trem-A2-mf-4c-N.wav");
c = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/behind_the_bridge/Vc-behind_bridge-N-N-3c-N.wav");
b.normalize;
c.normalize;

~delayTime = 2;
d = Buffer.alloc(s, 2 * ~delayTime * s.sampleRate);

~looperBus = Bus.audio(s, 1);
)

(
SynthDef(\looper, { arg outbus = 0, bufnum = 0, delayTime = 10, feedback = 0;
	var phasor, record, play;
	phasor = Phasor.ar(0, BufRateScale.kr(bufnum), 0, BufFrames.kr(bufnum));
	record = BufWr.ar(SoundIn.ar(0) + (feedback * LocalIn.ar),
		bufnum, phasor);
	play = BufRd.ar(1, bufnum, phasor - (delayTime * SampleRate.ir));
	LocalOut.ar(play);
	Out.ar(outbus, play);
}).play(s, [\outbus, ~looperBus, \delayTime, ~delayTime, \bufnum, d.bufnum]);


SynthDef(\morph, { arg out=0, bufnum=0, gateThresh=0.4, inBBus = 0;
    var inA, chainA, inB, chainB, chain, fftSize = 2048, ampEnvA, ampEnvB, ampCompensation;
    inA = SoundIn.ar(0);
    inA = Compander.ar(inA, inA,
        thresh: gateThresh,
        slopeBelow: 10,
        slopeAbove:  1,
        clampTime:   0.001,
        relaxTime:   1.0
    );
    inB = In.ar(inBBus, 1);
    chainA = FFT(LocalBuf(fftSize), inA);
    chainA = PV_MagSmooth(chainA, MouseY.kr(0, 1));
    chainB = FFT(LocalBuf(fftSize), inB);
    chainB = PV_MagSmooth(chainB, MouseY.kr(0, 1));
    chain = PV_Morph(chainA, chainB, MouseX.kr);

    // Calculate amplitude envelopes for inA and inB
    ampEnvA = Amplitude.kr(inA, 0.01, 2.0);
    ampEnvB = Amplitude.kr(inB, 0.01, 2.0);
    // Calculate compensation factor
    ampCompensation = ampEnvA / (ampEnvB + 0.0001); // Avoid division by zero

    // Apply compensation to the output
    Out.ar(out, (IFFT(chain)).dup);
}).play(s, [\out, 0, \bufnum, c.bufnum, \gateThresh, 0.0, \inBBus, ~looperBus]);
)


(
SynthDef(\reso,
	{
		arg freq = 440, decay = 1.0, amp = 1, harmonics = 10, outbus = 0;
		var sig, in, mix;

		mix = MouseX.kr;
		in = SoundIn.ar;
		sig = RLPF.ar(CombN.ar(in, 0.2, freq.reciprocal, decay), harmonics*freq, 0.6);
		Out.ar(outbus, ((mix * sig) + ((1 - mix) * in)).dup);
}).play(s);
)


(
SynthDef(\looper, { arg outbus = 0, bufnum = 0, delayTime = 10, feedback = 0;
	var phasor, record, play;
	phasor = Phasor.ar(0, BufRateScale.kr(bufnum), 0, BufFrames.kr(bufnum));
	record = BufWr.ar(SoundIn.ar(0) + (feedback * LocalIn.ar),
		bufnum, phasor);
	play = BufRd.ar(1, bufnum, phasor - (delayTime * SampleRate.ir));
	LocalOut.ar(play);
	Out.ar(outbus, play);
}).play(s, [\outbus, 0, \delayTime, ~delayTime, \bufnum, d.bufnum]);

)

