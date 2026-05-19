//Bibliotheken en Initialisatie 

  

#include <Wire.h> //I2C-communicatie voor DAC  

#include "DFRobot_GP8403.h" //DFRobot-bibliotheek  

#include <math.h> 

  

DFRobot_GP8403 dac(&Wire, 0x5F); // 0x5F is serieel adres van DAC. Kijken in site wat het is (https://wiki.dfrobot.com/SKU_DFR0971_2_Channel_I2C_0_10V_DAC_Module ): I2C Address Table 

  

//Variabelen 

  

float amplitude = 5.0; //variabele aanhalen en in welke vorm het verwacht wordt. Dit is de amplitude van de voltage, de hoogte in voltage. Piekenhoogte boven offset (V), max 10V.  

float offset = 0; // variabele aanhalen en in welke vorm het verwacht wordt. Moet op 0 staan want dit bepaalt baseline voltage (bij laser uit). Basisspanning (V); 0V = laser uit. 

float frequency = 10.0; //variabele aanhalen en in welke vorm het verwacht wordt. 1/duur van 1 cycle (100ms bij 10ms aan en 90ms uit).  

float duty = 0.5; //variabele aanhalen en in welke vorm het verwacht wordt. Hoe lang laser aan is in totale duur. Bv 10% van 100ms is 10ms aan en 90m uit. (0-1) 

unsigned long duration = 0; // Duration in ms // variabele aanhalen en in welke vorm het verwacht wordt.  

unsigned long startTime = 0; //variabele aanhalen en in welke vorm het verwacht wordt. 

bool waveformActive = false; //variabele aanhalen en in welke vorm het verwacht wordt. Om alleen positieve deel van blokgolf te krijgen 

  

//Serial Input Buffer 

  

String inputString = ""; // Buffer voor inkomende serial data (GUI met input via python) 

boolean stringComplete = false; 

  

//Setup() 

  

void setup() { 

  Serial.begin(115200);  

  inputString.reserve(200); 

  Wire.begin(); // Start I2C 

  

  while (dac.begin() != 0) { 

    Serial.println("init error"); 

    delay(1000); 

  } 

  Serial.println("init succeed"); 

  dac.setDACOutRange(dac.eOutputRange10V); // Stel 0-10V range in (0-10000=10V). Hij is ingested op 10V 

  

  Serial.println("Enter: A6.0 F25 O0.0 DC0.5 T1000"); // Voorbeeldcommando vanuit Arduino IDE Serial monitor 

} 

  

// Loop(): Serial Parsing en Golf Generatie 

  

void loop() { 

  if (stringComplete) { 

    parseCommands(inputString); 

    inputString = ""; 

    stringComplete = false; 

  } 

  

  if (waveformActive) { //om alleen positieve deel van blokgolf te krijgen 

    unsigned long now = millis(); 

    if (now - startTime >= duration) { 

      waveformActive = false; 

      dac.setDACOutVoltage(offset * 1000, 0); // Set to low (offset) 

      Serial.println("Waveform stopped."); 

    } else { 

      float periodMs = 1000.0 / frequency; 

      float onTime = periodMs * duty; 

      float offTime = periodMs - onTime; 

      uint16_t low = offset * 1000; 

      uint16_t high = (offset + amplitude) * 1000; 

  

      float timeInCycle = fmod((now - startTime), periodMs); 

      if (timeInCycle < onTime) { 

        dac.setDACOutVoltage(high, 0); 

      } else { 

        dac.setDACOutVoltage(low, 0); 

      } 

    } 

  } 

} 

  

// SerialEvent(): Input Verzamelen (om te spreken met python code) 

  

void serialEvent() { 

  while (Serial.available()) { 

    char inChar = (char)Serial.read(); 

    inputString += inChar; 

    if (inChar == '\n') { 

      stringComplete = true; 

    } 

  } 

} 

// parseCommands(): Spaties Scheiden (Splits spaties: "A6.0 F25" → "A6.0", "F25".) 

  

void parseCommands(String commands) { 

  commands.trim(); 

  int start = 0; 

  int spaceIndex = -1; 

  

  while (start < commands.length()) { 

    spaceIndex = commands.indexOf(' ', start); 

    if (spaceIndex == -1) spaceIndex = commands.length(); 

  

    String token = commands.substring(start, spaceIndex); 

    parseToken(token); 

  

    start = spaceIndex + 1; 

  } 

} 

  

// parseToken(): Parameter Update (max en min ranges van alle parameters hierin instellen o.a. ) 

  

void parseToken(String token) { 

  token.trim(); 

  if (token.startsWith("A")) { // Amplitude. 

    amplitude = token.substring(1).toFloat(); 

    amplitude = constrain(amplitude, 0, 10); 

    Serial.print("Amplitude set to: "); 

    Serial.println(amplitude); 

  } else if (token.startsWith("F")) { // Frequency. 

    frequency = token.substring(1).toFloat(); 

    frequency = max(frequency, 0.01); 

    Serial.print("Frequency set to: "); 

    Serial.println(frequency); 

  } else if (token.startsWith("O")) { // Offset. 

    offset = token.substring(1).toFloat(); 

    offset = constrain(offset, 0, 10); 

    Serial.print("Offset set to: "); 

    Serial.println(offset); 

  } else if (token.startsWith("DC")) { // Duty cycle. 

    duty = token.substring(2).toFloat(); 

    duty = constrain(duty, 0, 1); 

    Serial.print("Duty cycle set to: "); 

    Serial.println(duty); 

  } else if (token.startsWith("T")) { // Duration (start golf). 

    duration = token.substring(1).toInt(); 

    duration = constrain(duration, 100UL,300000UL); //max 5min nu  

    startTime = millis(); 

    waveformActive = true; 

    Serial.print("Duration set to: "); 

    Serial.println(duration); 

  } else { 

    Serial.print("Unknown token ignored: "); 

    Serial.println(token); 

  } 

} 

 

 
