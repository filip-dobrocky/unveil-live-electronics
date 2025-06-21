\version "2.24.3"

#(define pi (* 2 (acos 0)))
#(define deg->rad (/ pi 180))

#(define (scaled-value value min max scaling)
   (cond
     ((eq? scaling 'linear)
      (/ (- value min) (- max min)))
     ((eq? scaling 'exponential)
      (let* ((norm (/ (- value min) (- max min)))
             (exp-min (log min))
             (exp-max (log max)))
        (/ (- (log value) exp-min)
           (- exp-max exp-min))))
     (else
      (/ (- value min) (- max min)))))

#(define (draw-knob value min max scaling)
   (let* (
          (start-angle (* 240 deg->rad))
          (end-angle (* -60 deg->rad))
          (norm-val (scaled-value value min max scaling))
          (angle (+ start-angle (* norm-val (- end-angle start-angle))))
          (cx 2)
          (cy 2)
          (r 1.8)
          (x (+ cx (* r (cos angle))))
          (y (+ cy (* r (sin angle))))
         )
     (markup
      #:override '(baseline-skip . 0)
      #:with-dimensions '(0 . 4) '(0 . 4)
      #:postscript (format #f "
        0.3 setlinewidth
        newpath
        ~a ~a 2 0 360 arc
        stroke
        newpath
        ~a ~a moveto
        ~a ~a lineto
        stroke"
        cx cy cx cy x y))))

#(define (knob-with-label name value min max scaling)
   (markup
     #:scale '(0.5 . 0.5)
     #:center-align
     #:column (
       (draw-knob value min max scaling)
       #:translate '(0 . -1.5)
       #:small (markup (string-append name ": " (number->string value)))
     )))

noLines =
#(define-music-function (parser location) ()
   #{ \override Staff.StaffSymbol.line-count = #0 #})

knobNote =
#(define-music-function
  (name value min max scaling music)
  (string? number? number? number? symbol? ly:music?)
#{
  \once \override NoteHead.stencil =
    #(lambda (grob)
       (grob-interpret-markup grob
         (knob-with-label name value min max scaling)))
  $music
#})

knobNotes = 
#(define-music-function
  (name value1 value2 min max scaling dur1 dur2 midnote)
  (string? number? number? number? number? symbol? ly:music? ly:music? ly:music?)
#{
  \knobNote #name #value1 #min #max #scaling #dur1
  \glissando
  \hideNotes
  \grace #midnote
  \unHideNotes
  \knobNote #name #value2 #min #max #scaling #dur2
#})


\layout {
  \context {
    \Voice
    \consists "Horizontal_bracket_engraver"
    \omit Stem
    \omit Flag
    \omit Beam
    \override NoteHead.duration-log = 2
    \override HorizontalBracket.direction = #UP
  }
  \context {
    \Score
    proportionalNotationDuration = #(ly:make-moment 1/20)
  }
}

\score {
  <<
  \new Staff {
    \noLines
    c'4\pp
    d'4
    e'4
    f'4
    g'4
  }


  \new Staff <<
  
  
  \new Voice {
    \noLines
    
    \shiftOff
    \once\override HorizontalBracketText.text = "30'"
    \startGroup
    \once\override HorizontalBracketText.text = "20'"
    \startGroup
    \knobNotes "Gain" 0.75 1 0 1 #'linear c''''4 c''''8 d''''
    \stopGroup
    \knobNote "Pan"  0.2  0 1 #'linear c''''4
    \stopGroup
  }
  \new Voice {
    \noLines
    
    \shiftOff
    \knobNotes "Freq" 500 1000 40 4000 #'exponential c''4 c''4 f''
    
  }
  \new Voice {
    \noLines
    
    \shiftOff
    \knobNote "Ratio"  1 0.025 38.05 #'exponential c1
    \knobNote "Pan"  0.2  0 1 #'linear c4
  }
>>

>>

}
