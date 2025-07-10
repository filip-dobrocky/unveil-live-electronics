\version "2.24.2"

#(define pi (* 2 (acos 0)))
#(define deg->rad (/ pi 180))

#(define (db->lin db)
   (expt 10 (/ db 20)))

#(define (scaled-value value min max scaling)
   (cond
    ((eq? scaling 'lin)
     (/ (- value min) (- max min)))

    ((eq? scaling 'exp)
     ;; value, min, max must all be > 0
     (let* ((exp-min (log min))
            (exp-max (log max)))
       (/ (- (log value) exp-min)
          (- exp-max exp-min))))

    ((eq? scaling 'dblin)
     ;; Convert dB to linear scale
     (let* ((val-lin (db->lin value))
            (min-lin (db->lin min))
            (max-lin (db->lin max)))
       (/ (- val-lin min-lin)
          (- max-lin min-lin))))

    (else
     (error "Unsupported scaling mode:" scaling))))

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

#(define (knob-with-label name unit value min max scaling)
   (markup
    #:override '(box-padding . 0.6) #:box
    #:center-column (
                      (draw-knob value min max scaling)
                      #:tiny
                      #:center-align
                      (markup (string-append name ": " (number->string value) " " unit))
                      )))

noLines =
#(define-music-function (parser location) ()
   #{ 
    \override Staff.StaffSymbol.line-count = #0 
   #})

knobNote =
#(define-music-function
  (name unit value min max scaling music)
  (string? string? number? number? number? symbol? ly:music?)
  #{  
    \once \override NoteHead.stencil =
    #(lambda (grob)
       (grob-interpret-markup grob
                              (knob-with-label name unit value min max scaling)))
    $music
  #})

knobNotes =
#(define-music-function
  (name unit value1 value2 min max scaling dur1 dur2 midnote)
  (string? string? number? number? number? number? symbol? ly:music? ly:music? ly:music?)
  #{
    \knobNote #name #unit #value1 #min #max #scaling #dur1
    \startGroup
    \glissando
    \hideNotes
    \grace #midnote
    \unHideNotes
    \knobNote #name #unit #value2 #min #max #scaling #dur2
    \stopGroup
  #})

#(define (draw-slider value min max scaling)
   (let* (
           (norm-val (scaled-value value min max scaling))
           (slider-height 4.0)
           (slider-width 0.5)
           (x 2) ;; horizontal center
           (line-length 1.0)
           (y-base 0.5)
           (y-top (+ y-base slider-height))
           (y-indicator (+ y-base (* norm-val slider-height)))
           (x1 (- x (/ line-length 2)))
           (x2 (+ x (/ line-length 2)))
           )
     (markup
      #:override '(baseline-skip . 0)
      #:with-dimensions '(0 . 4) '(0 . 4)
      #:postscript (format #f "
        0.2 setlinewidth
        newpath
        ~a ~a moveto
        ~a ~a lineto
        stroke
        0.45 setlinewidth
        newpath
        ~a ~a moveto
        ~a ~a lineto
        stroke"
                           x y-base x y-top     ;; vertical track
                           x1 y-indicator x2 y-indicator  ;; horizontal marker line
                           ))))

#(define (fader-with-label name unit value min max scaling)
   (markup
    #:override '(box-padding . 1) #:box
    #:center-column (
                      (draw-slider value min max scaling)
                      #:tiny
                      #:center-align
                      (markup (string-append name ": " (number->string value) " " unit))
                      )))

faderNote =
#(define-music-function
  (name unit value min max scaling music)
  (string? string? number? number? number? symbol? ly:music?)
  #{
    \once \override NoteHead.stencil =
    #(lambda (grob)
       (grob-interpret-markup grob
                              (fader-with-label name unit value min max scaling)))
    $music
  #})

faderNotes =
#(define-music-function
  (name unit value1 value2 min max scaling dur1 dur2 midnote)
  (string? string? number? number? number? number? symbol? ly:music? ly:music? ly:music?)
  #{
    \faderNote #name #unit #value1 #min #max #scaling #dur1
    \startGroup
    \glissando
    \hideNotes
    \grace #midnote
    \unHideNotes
    \faderNote #name #unit #value2 #min #max #scaling #dur2
    \stopGroup
  #})

#(define (cue-up-markup text)
   (let ((label-markup
           (if (markup? text)
               (make-small-markup text)
               (make-small-markup (make-simple-markup "")))))
     (make-center-column-markup
      (list
       (make-combine-markup
        (make-draw-line-markup '(0 . 3.5))         ; arrow shaft pointing up
        (make-translate-markup '(0 . 3.5)
          (make-arrow-head-markup Y UP #t)))      ; arrow head at top
       (make-translate-markup '(0 . 1.5) label-markup) ; text below the arrow
       ))))


cueUp =
#(define-music-function
  (text)
  (markup?)
  #{
    \once \override Score.RehearsalMark.direction = #DOWN
    \mark \markup #(cue-up-markup text)
  #})

#(define (cue-down-markup text)
   (let ((label-markup
           (if (markup? text)
               (make-small-markup text)
               (make-small-markup (make-simple-markup "")))))
     (make-center-column-markup
      (list
       (make-combine-markup
        (make-draw-line-markup '(0 . 3.5))         ; arrow shaft pointing up
        (make-translate-markup '(0 . 0)
          (make-arrow-head-markup Y DOWN #t)))      ; arrow head at top
       (make-translate-markup '(0 . 1.5) label-markup) ; text below the arrow
       ))))


cueDown =
#(define-music-function
  (text)
  (markup?)
  #{
    \once \override Score.RehearsalMark.direction = #DOWN
    \mark \markup #(cue-down-markup text)
  #})

#(define (seconds->mmss secs)
   (let* ((mins (quotient secs 60))
          (secs-rem (remainder secs 60)))
     (format #f "~2,'0d:~2,'0d" mins secs-rem)))

#(define (make-mmss-stencil grob)
  (let* ((bar-text (ly:grob-property grob 'text))
         (bar-num (if (string? bar-text) (string->number bar-text) 0))
         (seconds (* (- bar-num 1) 20))
         (label (seconds->mmss seconds)))
    (grob-interpret-markup grob
      (markup #:small #:bold label))))

