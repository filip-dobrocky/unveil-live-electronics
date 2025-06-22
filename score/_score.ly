\version "2.24.3"

\include "macros.ly"

\layout {
  \context {
    \Voice
    \omit Stem
    \omit Flag
    \omit Beam
    \omit Dots
    \consists Duration_line_engraver
    \override NoteHead.duration-log = 2
    \consists "Horizontal_bracket_engraver"
    \override HorizontalBracket.direction = #UP
    \override HorizontalBracket.minimum-length = 0.5
    \override DurationLine.style = #'dashed-line
    \override DurationLine.thickness = #0.66
    \override Glissando.style = #'dashed-line
  }
  \context {
    \Score
    proportionalNotationDuration = #(ly:make-moment 1/20)
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
  }
  \header {
    title = "clearing"
  }

  \score {
    \header {
      title = "I"
      % opus = "clearing"
    }
    \new StaffGroup <<
      \new Staff \with {
        instrumentName = "Instrument"

        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      } {
        \noLines
        \cadenzaOn
        \override Staff.NoteHead.style = #'cross
        c'1\-\pp^"col legno tratto"
        \bar "!" \mark \markup \bold "1:00"
      }

      \new Staff \with {
        instrumentName = "Electronics"
        \override VerticalAxisGroup.staff-staff-spacing = #'((basic-distance . 30))
      }
      <<
        \new Voice {
          \noLines
          \shiftOff
          \relative c''''' {
            r2\-
            \bar "!" \mark \markup \bold "0:30"


            \knobNotes "FX2 mix" "" 0 1 0 1 #'lin c4. c4. f8
          }
        }
        
        \new Voice {
          \noLines
          \shiftOff
          % \omit r2
          % \relative c' {
          %   \once\override HorizontalBracketText.text = "38'"
          %   \knobNotes "Freq" "Hz" 500 1000 40 4000 #'exp e4 e4 g
          % }

        }
        \new Voice {
          \noLines
          % \relative c, {
          %   \shiftOff
          %   \faderNote "L1" "dB" -6 -80 12 #'lin c,1
          %   \faderNote "Pan" ""  1  0 1 #'lin c,4
          % }
        }
      >>

    >>

  }
}
