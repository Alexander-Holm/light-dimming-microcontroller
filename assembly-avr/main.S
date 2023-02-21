; WIP
; Assembly AVR: https://ww1.microchip.com/downloads/en/devicedoc/atmel-0856-avr-instruction-set-manual.pdf
; 16MHz clock frequency

#define __SFR_OFFSET 0
#include "avr/io.h"

#define BRIGTHNESS_MIN 0
#define BRIGTHNESS_MAX 255
#define DIM_DELAY 200

; --- Pins ---
; LED måste använda pin 6 eftersom timer0A används för PWM
#define PIN_LED PD6
#define LED_PWM OCR0A
#define PIN_BUTTON PB5

; --- Registers ---
#define brightness r16
#define brightnessAdjustment r17
/* 
  Register pair / word
  Register är 1 byte men går att använda tillsammans (jämnt+ojämnt nummer), 
  för att lagra ett värde som är 2 byte.
  lo8(numberX) = low byte
  hi8(numberX) = high byte
  https://sourceware.org/binutils/docs-2.18/as/AVR_002dModifiers.html
  Båda sätts till så många ms som ska väntas med lo8() och hi8()
  Exempel för 100ms:
  ldi waitAmount_lo8, lo8(100) 
  ldi waitAmount_hi8, hi8(100)

*/
#define waitAmount_lo8 r24
#define waitAmount_hi8 r25
; r26 och r27 (X-register) används av funktionen wait

.global setup
.global loop

setup:
  ldi brightness, 80 ; 0 - 255
  ldi brightnessAdjustment, 5 ; Hur stort steg brightness ska ändras med
  /*
    https://wolles-elektronikkiste.de/en/timer-and-pwm-part-1-8-bit-timer0-2
    Sätter timer0 till fast PWM.
  */
  ; Tar register r26 eftersom det redan används senare
  ldi r26, (1<<COM0A1) | (1<<WGM21) | (1<<WGM20)
  out TCCR0A, r26 ; 
  /*
    Sätter PWM-intervall till brightness %
    t.ex. brightness = 80, brightness / 255 = 31%
    on 31%, off 69%
  */  
  out LED_PWM, brightness
  cbi DDRD, PIN_LED ; Sätter pin till input för att stänga av LED.

  cbi DDRB, PIN_BUTTON  ; pin input
  sbi PORTB, PIN_BUTTON ; input_pullup

  ret

loop:
  call waitForButtonPress

  ; (DDRD bit för LED == 0) = pin-mode:input = LED avstängd
  sbis DDRD, PIN_LED
    jmp turnLightOn ; hoppa över om (bit == 1) = pin-mode:output
  
  ; Vänta och kolla om knappen fortfarande hålls ner
  ldi waitAmount_lo8, lo8(DIM_DELAY)
  ldi waitAmount_hi8, hi8(DIM_DELAY)
  call wait
  sbic PINB, PIN_BUTTON
    jmp turnLightOff; Har knappen släppts släcks LED
  jmp adjustBrightness

  endLoop:
  call waitForButtonRelease
  jmp loop



; --- LED ---
; Alla funktioner hoppar till endLoop

turnLightOn:
  sbi DDRD, PIN_LED
  jmp endLoop
turnLightOff:
  cbi DDRD, PIN_LED
  jmp endLoop
adjustBrightness:
  1: ; do
  add brightness, brightnessAdjustment 
	out LED_PWM, brightness
  ldi waitAmount_lo8, lo8(20)
  ldi waitAmount_hi8, hi8(20)
  call wait

  ; while
  ; Går ur loopen om något condition är true
  sbic PINB, PIN_BUTTON
    jmp 2f
  cpi brightness, BRIGTHNESS_MIN
    breq 2f
  cpi brightness, BRIGTHNESS_MAX
    breq 2f    

  rjmp 1b; Alla conditions false, fortsätt loopa
  2: ; Gå ur loop
  neg brightnessAdjustment; Nästa gång ska ljusstyrkan ändras åt andra hållet
  jmp endLoop



; --- Button ---

waitForButtonPress:
  ; pin är 0/LOW när knappen är nedtryckt, pga. input_pullup.
  sbic PINB, PIN_BUTTON
    rjmp waitForButtonPress
  ret   
waitForButtonRelease:
  sbis PINB, PIN_BUTTON
    rjmp waitForButtonRelease
  ret



; --- ---

wait:
  /*
    16MHz clock frequency
    16 000 000 cycles per sekund
    16 000 cycles per millisekund (1ms = 1s/1000)
    Inre loopen tar 4 cycles
    16 000 / 4 = 4000
    1ms = inre loopen 4000 gånger

    Men eftersom setup + yttre loopen är 8 cycles
    behöver inre loopen köras 2 gånger mindre.
  */  

  1: ; setup          ; Totalt: 2 cycles
  ; X-register håller hur många gånger inre loopen ska köras
  ldi   XL, lo8(3998) ; 1 cycle
  ldi   XH, hi8(3998) ; 1 cycle
  
  2: ; inner loop         ; Totalt: 4 cycles
  sbiw X, 1               ; 2 cycles
  brne 2b                 ; 2 cycles (1 för sista utan branch)
  nop                     ; 1 cycle efter loopen pga. sista brne

  ; outer loop            ; Totalt: 8 cycles = 6 (outer loop) + 2 (setup)
  sbiw waitAmount_lo8, 1  ; 2 cycles
  nop                     ; 1 cycle
  nop                     ; 1 cycle
  brne 1b                 ; 2 cycles (1 för sista utan branch)
  nop                     ; 1 cycle efter loopen pga. sista brne
  ret
