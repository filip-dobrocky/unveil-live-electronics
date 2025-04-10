// By Nathaniel Virgo
// https://listarc.cal.bham.ac.uk/lists/sc-users-2009/msg55766.html

// This comes from the mailing list as an attempt to simulate the vst Shapee

(
s.boot.doWhenBooted {
c = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/sul_ponticello_tremolo/Vc-pont_trem-A2-mf-4c-N.wav");
d = Buffer.read(s, "/home/filip/Downloads/_OrchideaSOL2020_release/OrchideaSOL2020/Strings/Violoncello/behind_the_bridge/Vc-behind_bridge-N-N-3c-N.wav");
}
)

(
x = {
    // parameters to play with - width should be an integer - I think 4 is the theoretical optimum
    var fftsize = 512, width=4;

    var in, chain, in2, chain2, out;

    // timbre source - vocal sample
    in = PlayBuf.ar(1, c, BufRateScale.kr(c), loop: 1);

    // pitch source - random polyphonic line
    in2 = PlayBuf.ar(1, d, BufRateScale.kr(c), loop: 1);

    chain = FFT(LocalBuf(fftsize), in, wintype:1);
    chain2 = FFT(LocalBuf(fftsize), in2, wintype:1);

    chain = chain.pvcalc2(chain2, fftsize, {|e_mags, e_phases, f_mags, f_phases|

        var fbins = e_mags.clump(width).collect(_.sum) / f_mags.clump(width).collect(_.sum);

        [f_mags*fbins.stutter(width), f_phases];
        //[e_mags, f_phases];
    });


    out = IFFT(chain);
    Out.ar(0, 0.5 * out.dup);
}.play(s);
)

{PlayBuf.ar(1, c, BufRateScale.kr(c), loop: 1)}.play
{Pan2.ar(PlayBuf.ar(1, d, BufRateScale.kr(c), loop: 1), 1)}.play
