\version "2.24.3"

\include "macros.ly"

\layout {
  \context {
    \Voice
    \omit Stem
    \omit Flag
    \omit Beam
    \omit Dots
    \omit TupletBracket
    \omit TupletNumber
    \omit Rest
    \omit Accidental

    \consists Duration_line_engraver
    \override NoteHead.duration-log = 2

    % \consists Horizontal_bracket_engraver
    % \override HorizontalBracket.direction = #UP
    % \override HorizontalBracket.minimum-length = 0.5
    \override DurationLine.style = #'dashed-line
    \override DurationLine.thickness = #0.66
    \override Glissando.style = #'dashed-line
  }
  \context {
    \Score
    proportionalNotationDuration = #(ly:make-moment 1/36)

    \consists Bar_number_engraver
    \override BarNumber.stencil = #make-mmss-stencil
    \override BarNumber.break-visibility = ##(#t #t #t)
    \override BarNumber.self-alignment-X = #CENTER
    \override BarNumber.padding = #2
  }
  \context {
    \Staff
    \omit Clef
    \omit TimeSignature
  }
}

\book {
  \paper {
    print-all-headers = ##t
    #(set-paper-size "a4landscape")
  }
  \header {
    % title = "clearing"
  }

  \score {
    \header {
      title = "I"
      % opus = "clearing"
    }
    \new StaffGroup <<
      \new Staff \with {
        instrumentName = "Instrument"
        \noLines
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      } {
        % \cadenzaOn
        \time 2/4
        \override Staff.NoteHead.style = #'cross
        \override Score.BarNumber.break-visibility = ##(#t #t #t)
        \override Rest.direction = #CENTER

        c'1\-\pp^"col legno tratto" _"slightly varying noise"
        \override Staff.NoteHead.style = #'none
        c'1\-
        \undo \omit Rest
        r2 r2 r2 r2
        \omit Score.BarNumber
      }

      \new Staff \with {
        instrumentName = "Electronics"
        \noLines
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      }
      <<
        \new Voice {
          \shiftOff
          \relative c'''' {
            \override Rest.direction = #CENTER
            r2
            \knobNotes "FX2 mix" "" 0 0.8 0 1 #'lin c4. c8 f
            \omit r4
            \knobNotes "FX3 mix" "" 0 0.6 0 1 #'lin c2 c4 f
            \cueDown "L1 rec"
            \break
            % \bar "!" \mark \markup \bold "1:20"
            \knobNotes "Push" "" 1.57 0.0 0 1.57 #'lin c2. c4 g
            % \omit r4
            \knobNotes "FX4 mix" "" 0 0.8 0 1 #'lin c4. c8 f
            \knobNote "FX4 mix" "" 0 0 1 #'lin c4
            ^"change parameters to 0 fairly quickly"
            \knobNote "RTT" "" 0 0 1 #'lin c4
            \cueUp "L1 stop"
          }
        }

        \new Voice {
          \override Staff.StaffSymbol.staff-space = #2
          \shiftOff
          \omit r2
          \relative c'' {
            r4.
            \cueUp "L1 rec"
            \knobNotes "FX1 mix" "" 0 0.5 0 1 #'lin c4. c8 e
            r4  r1 r4
            \knobNotes "FX3 crush" "" 0.5 0.7 0 1 #'lin c4. c8 e
            r4
            \knobNote "FX3 mix" "" 0 0 1 #'lin c4
            \knobNote "FX1 mix" "" 0 0 1 #'lin c4
          }

        }
        \new Voice {
          \relative c {
            \shiftOff
            r\breve r1
            \knobNotes "FX3 bass" "" 0.5 0.8 0 1 #'lin f4. f8 g
            \knobNote "FX3 bass" "" 0 0 1 #'lin f4
            \knobNote "FX2 mix" "" 0 0 1 #'lin f4
          }
        }
      >>

    >>

  }

  \pageBreak

  \score {
    \header {
      title = "II"
      % opus = "clearing"
    }
    \new StaffGroup <<
      \new Staff \with {
        instrumentName = "Instrument"
        \noLines
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 33))
      } {
        % \cadenzaOn
        \time 8/4
        \set Score.currentBarNumber = #10
        \override Staff.NoteHead.style = #'cross
        \override Score.BarNumber.break-visibility = ##(#t #t #t)
        \override Rest.direction = #CENTER

        c8->\f ^"col legno battuto"
        \tuplet 6/6 {
          c32\pp\< c32. c16 c16. c8 c8\f
        }
        r8
        c8->
        \tuplet 6/6 {
          c32\pp\< c32. c16 c16. c8 c8\f_"reverb with accent"
        }
        r4 r16 r4.
        \revert Staff.NoteHead.style
        g,2\mf^"arco" \-
        d2\-
        d4\glissando _"gliss"
        a8 \glissando f'8 \glissando e'8 \glissando e'8 \glissando d8
        r8
        \undo \omit Rest
        r2
        {
          \override NoteHead.style = #'harmonic
          g,16 _"harmonics"
          \glissando g \glissando d' \glissando g' \glissando bes' \glissando d'' \glissando f'' \glissando g'' \glissando a'' \glissando bes''
          % Descending
          \glissando a''32 \glissando g'' \glissando f'' \glissando d'' \glissando bes' \glissando g' \glissando d' \glissando g \glissando g
          % Repeat some to fill 32 notes
          \glissando d' \glissando g' \glissando bes' \glissando g' \glissando d' \glissando g \glissando g
          % Repeat some to fill 32 notes
          \glissando d' \glissando g' \glissando bes' \glissando g' \glissando d' \glissando g \glissando g
        }
        \omit Rest
        r8
        \revert Staff.NoteHead.style
        \undo \omit Rest
        r1 \omit Rest r1
        r1 r1 r1 r1
      }

      \new Staff \with {
        instrumentName = "Electronics"
        \noLines
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      }
      <<
        \new Voice {
          \shiftOff
          \relative c'''' {
            \override Rest.direction = #CENTER
            \cueUp "L2 rec"
            \faderNote "L2" "dB" -65 -65 12 #'lin c4
            r2.
            \knobNotes "FX4 mix" "" 0.4 0 0 1 #'lin c4 c4 g
            \cueUp "L2 rec"
            r2
            \faderNotes "L2" "dB" -65 0 -65 12 #'lin c2. c4 f
            r2 \break
            r4.
            \knobNote "FX2 mix" "" 0.4 0 1 #'lin c4
            r4
            \knobNote "FX2 mix" "" 1 0 1 #'lin c4

            r1 r4 r4 \break
            \knobNotes "FX1 mix" "" 0 1 0 1 #'lin c1. c2 f
            \cueUp "L3 rec"
            \knobNotes "FX3 mix" "" 0 0.2 0 1 #'lin c2. c4 f
            r4
            \knobNote "FX3 mix" "" 0 0 1 #'lin c4
            \cueDown "L3 rec"

            r1 r2
            \knobNote "Tumble" "" 0 -3.14 3.14 #'lin c4
            r4 r4 r4

            \faderNote "L1" "dB" 0 -65 12 #'lin c4
            \knobNote "Push" "" 0 0 1 #'lin c2.
          }
        }

        \new Voice {
          \override Staff.StaffSymbol.staff-space = #2
          \shiftOff
          \omit r2
          \relative c'' {
            r2 r4 \cueDown "L2 rec"
            \knobNote "FX2 ratio" "" 1.3 0.025 38 #'exp c4
            r1 r2 r2 r2
            \knobNote "Tumble" "" 1.5 -3.14 3.14 #'lin c4
            r1 r2 r8        \cueDown "L2 rec"
            r1 r1
            \knobNote "Push" "" 1 0 1 #'lin c2.

            r1 r2
            \knobNote "FX1 mix" "" 0 0 1 #'lin c2
            \knobNote "FX2 mix" "" 0 0 1 #'lin c2
            r1
            \faderNote "L2" "dB" -65 -65 12 #'lin c1

          }

        }
        \new Voice {
          \relative c {
            r1 r r r r r r r r r r r
            \faderNote "L3" "dB" -65 -65 12 #'lin c1

          }
        }
      >>

    >>
  }

  \score {
    \header {
      title = "III"
      % opus = "clearing"
      subsubtitle = \markup {
        \column {
          \vspace #1
          \justify {
            aleatoric, duration ~1:30
          }
          \vspace #1
        }
      }
    }

    \new Staff \with {
      instrumentName = "Electronics"

      \noLines
      \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 33))
    } {
      \cadenzaOn
      r8
      ^"let loop play, change chords and parameters"
      \cueUp "chord change"
      \knobNote "FX1 mix" "" 1 0 1 #'lin c4
      \knobNote "FX1 mix" "" 0 0 1 #'lin c4
      \knobNote "Rotate" "" 1 -3.14 3.14 #'lin c4
      ^"arbitrary value"
      \knobNote "Tumble" "" -1 -3.14 3.14 #'lin c4
      ^"arbitrary value"
      r4^"possibly change other FX parameters at will"
      _"or occasionally fade in other loops"
      _"repeat"
      \cadenzaOff
    }
  }
  \score {
    \header {
      title = "IV"
      % opus = "clearing"
    }
    \new StaffGroup <<
      \new Staff \with {
        instrumentName = "Instrument"
        \noLines
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      } {
        % \cadenzaOn
        \time 8/4
        \override Staff.NoteHead.style = #'cross
        \override Score.BarNumber.break-visibility = ##(#t #t #t)
        \override Rest.direction = #CENTER

        r4 ^"reset stopwatch"
        c'32 ^"col legno battuto" \mf
        16 16 16 32 32 64 128 4

        r4 r1
        c'8 8 8 8 8 8 8 8
        r1
        c'2 c'8 8 4
        16 16 16 32 32 64 128 4
        r1 r1 r1
      }

      \new Staff \with {
        instrumentName = "Electronics"
        \noLines
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      }
      <<
        \new Voice {
          \shiftOff
          \relative c'''' {
          \faderNote "S1" "" 0.8 0 1 #'lin c4 ^"spectral freeze"
          r2. r4
          \faderNote "S2" "" 1 0 1 #'lin c4
          r4
          \knobNote "FX4 mix" "" 0.4 0 1 #'lin c4.
          \faderNotes "S1" "" 0.8 0 0 1 #'lin c2. c4 g
          r8
          \knobNotes "FX2 mix" "" 0 1 0 1 #'lin c4. c8 f
          \knobNote "FX2 mix" "" 0 0 1 #'lin c4
          \break
          \faderNotes "S3" "" 0 1 0 1 #'lin c2. c4 f
          \faderNote "S1" "" 1 0 1 #'lin c2
          \knobNotes "FX3 mix" "" 0 0.4 0 1 #'lin c2. c4 
          r2
          \knobNote "FX3 mix" "" 0 0 1 #'lin c4
          r2.
          \faderNote "S1" "" 0 0 1 #'lin c8
          \faderNote "S2" "" 0 0 1 #'lin c8
          \faderNote "S3" "" 0 0 1 #'lin c8
          r1

          }
          

        }

        \new Voice {
          \override Staff.StaffSymbol.staff-space = #2
          \shiftOff
          \relative c'' {
            \faderNote "L1" "dB" -65 -65 12 #'lin c4
          }

        }
        \new Voice {
          \relative c {
            \shiftOff

          }
        }
      >>

    >>

  }

  \score {
    \header {
      title = "V"
      % opus = "clearing"
      subsubtitle = \markup {
        \column {
          \vspace #1
          \justify {
            duration ~2:30
          }
          \vspace #1
        }
      }
    }

    \new Staff \with {
      instrumentName = "Electronics"

      \noLines
      \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 33))
    } {
      \cadenzaOn
      r8
      ^"slowly fade in all loops one by one"
      \faderNote "L1" "dB" 0 -65 12 #'lin c8
      \faderNote "L2" "dB" 0 -65 12 #'lin c8
      \faderNote "L3" "dB" 0 -65 12 #'lin c8
      r4 ^"gradually apply FX and fade out"

      \cadenzaOff
    }
  }

}
