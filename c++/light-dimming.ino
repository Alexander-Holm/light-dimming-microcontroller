/* 
  Library för displayen.
  https://www.arduino.cc/reference/en/libraries/liquidcrystal-i2c/
  https://www.arduino.cc/reference/en/libraries/liquidcrystal/
*/
#include <LiquidCrystal_I2C.h>

#define PIN_LED 11
#define PIN_BUTTON 13
/*
  Hur lång tid (ms) man måste hålla inne knappen innan ljusstyrkan ändras.
  Det är också hur lång tid det tar för lampan att stängas av när man tryckt på knappen.

  För högt värde gör att knappen inte känns responsiv när lampan 
  stängs av en lång stund efter man tryckt på knappen.

  För lågt värde gör det svårt att stänga av lampan då den 
  försöker ändra ljusstyrka istället.
*/
#define DIM_DELAY 200
// Går inte ner till 0 för att man inte ska stänga av lampan genom att justera ljusstyrkan
#define BRIGHTNESS_MIN 5
#define BRIGHTNESS_MAX 255
// Displayen får problem under 30ms
#define BRIGHTNESS_ADJUSTMENT_INTERVAL 30 //ms
#define DISPLAY_I2C_ADDRESS 0x27
/* 
  Konstruktorn till LiquidCrystal vill ha antal kolumner och rader, 
  men jag märker ingen skillnad oavsett vilka värden de har.
  Sätter det antal kolumner och rader som displayen har för säkerhets skull.
*/
#define DISPLAY_COLUMNS 16
#define DISPLAY_ROWS 2

LiquidCrystal_I2C display(
  DISPLAY_I2C_ADDRESS, 
  DISPLAY_COLUMNS, 
  DISPLAY_ROWS
);
// Får inte vara utanför BRIGHTNESS_MIN eller BRIGHTNESS_MAX 
int brightness = 100;
// Får inte göra så att brightness hamnar utanför min eller max
int brightnessAdjustment = 5;
bool lightOn = false;

void setup() {
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  display.init();
  display.backlight();
  display.setCursor(0,0);
  display.print("BRIGHTNESS: ");
  updateDisplay();
}

void loop() {
  if( isButtonPressed() == false ) return;

  if(lightOn){
    delay(DIM_DELAY);
    if(isButtonPressed() == false){
      turnLightOff();
    }
    else {
      adjustBrightness();
      /*         
        Väntar på att knappen släpps så att loopen inte går direkt tillbaka hit.
        brightness ska stanna på max eller min, inte börja gå åt andra hållet, 
        även om knappen fortsätter hållas in.
      */
      waitForButtonRelease();
    } 
  }

  else if(lightOn == false){
    turnLightOn();
    /*
      Vill inte att ljusstyrkan ska ändras med samma tryck som startar lampan,
      måste släppa knappen först och trycka igen.
    */
    waitForButtonRelease();
  }
}


// --- Led ---

void turnLightOn(){
  lightOn = true;
  analogWrite(PIN_LED, brightness); 
  updateDisplay();
}
void turnLightOff(){
  lightOn = false;
  analogWrite(PIN_LED, 0);
  updateDisplay();
}
void adjustBrightness(){  
  do{
    brightness += brightnessAdjustment;
    analogWrite(PIN_LED, brightness);
    updateDisplay();
    delay(BRIGHTNESS_ADJUSTMENT_INTERVAL);
  } while( 
    isButtonPressed()
    && brightness > BRIGHTNESS_MIN && brightness < BRIGHTNESS_MAX
  );
  // Nästa gång ska ljusstyrkan ändras åt andra hållet
  brightnessAdjustment *= -1;
}


// --- Display ---

void updateDisplay(){
  // Ta bort fyra tecken (max längd på brightness + %-tecken)
  display.setCursor(12, 0);  
  display.print("    ");

  // Skriv det nya värdet
  display.setCursor(12, 0);
  if(lightOn){
    int brightnessPercentage = (brightness * 100) / BRIGHTNESS_MAX;
    display.print(brightnessPercentage);
    display.print("%");
  }
  else display.print("OFF");
}


// --- Button ---
/*
  https://docs.arduino.cc/built-in-examples/digital/Debounce
  Ingen kod för debouncing av knappen.
  Det går att lösa bouncing med både 
  hårdvara: https://hackaday.com/2015/12/09/embed-with-elliot-debounce-your-noisy-buttons-part-i/
  kod: https://www.e-tinkers.com/2021/05/the-simplest-button-debounce-solution/
  
  I Wokwi går det inte att lösa med hårdvara (resistors + capacitor),
  men det går att stänga av bouncing för knappen (i diagram.json).
  Koden här fungerar endast med en knapp utan bouncing.
*/

// pinMode måste vara INPUT_PULLUP
bool isButtonPressed(){
  return !digitalRead(PIN_BUTTON);
}
void waitForButtonRelease(){
  while(isButtonPressed()) delay(100);
}
