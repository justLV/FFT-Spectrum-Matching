/*
  Analog Input

  Demonstrates analog input by reading an analog sensor on analog pin
  0 and turning on and off the Maple's built-in light emitting diode
  (LED).  The amount of time the LED will be on and off depends on the
  value obtained by analogRead().

  Created by David Cuartielles
  Modified 16 Jun 2009
  By Tom Igoe

  http://leaflabs.com/docs/adc.html

  Ported to Maple 27 May 2010
  by Bryan Newbold
*/

#include <stdint.h>
#include "PlainFFT.h"

int sensorPin = 0;   // Select the input pin for the potentiometer
int sensorValue = 0; // Variable to store the value coming from the sensor






PlainFFT FFT = PlainFFT(); /* Create FFT object */
/* 
These values can be changed in order to evaluate the functions 
*/
const uint16_t samples = 64;
double signalFrequency = 1000;
double samplingFrequency = 5000;
uint8_t signalIntensity = 100;
/* 
These are the input and output vectors 
Input vectors receive computed results from FFT
*/
double vReal[samples]; 
double vImag[samples];

#define SCL_INDEX 0x00
#define SCL_TIME 0x01
#define SCL_FREQUENCY 0x02

void setup(){

    pinMode(sensorPin, INPUT_ANALOG);
    SerialUSB.println("Ready");

    pinMode(sensorPin, INPUT_ANALOG);
    // Declare the LED's pin as an OUTPUT.  (BOARD_LED_PIN is a built-in
    // constant which is the pin number of the built-in LED.  On the
    // Maple, it is 13.)
    pinMode(BOARD_LED_PIN, OUTPUT);

}

void loop() 
{
  
        //Read sensor (Justin)
        sensorValue = analogRead(sensorPin);
	




      /* Build raw data */
	double cycles = (((samples-1) * signalFrequency) / samplingFrequency);
	for (uint8_t i = 0; i < samples; i++) {
		vReal[i] = uint8_t((signalIntensity * (sin((i * (6.2831 * cycles)) / samples) + 1.0)) / 2.0);
	}
	PrintVector(vReal, samples, SCL_TIME);
	FFT.Windowing(vReal, samples, FFT_WIN_TYP_HAMMING, FFT_FORWARD);	/* Weigh data */
	PrintVector(vReal, samples, SCL_TIME);
	FFT.Compute(vReal, vImag, samples, FFT_FORWARD); /* Compute FFT */
	PrintVector(vReal, samples, SCL_INDEX);
	PrintVector(vImag, samples, SCL_INDEX);
	FFT.ComplexToMagnitude(vReal, vImag, samples); /* Compute magnitudes */
	PrintVector(vReal, (samples >> 1), SCL_FREQUENCY);	
	double x = FFT.MajorPeak(vReal, samples, samplingFrequency);
	Serial.println(x, 6);
	while(1); /* Run Once */
	// delay(2000); /* Repeat after delay */
}

void PrintVector(double *vData, uint8_t bufferSize, uint8_t scaleType) 
{	
	for (uint16_t i = 0; i < bufferSize; i++) {
		double abscissa;
		/* Print abscissa value */
		switch (scaleType) {
		case SCL_INDEX:
			abscissa = (i * 1.0);
			break;
		case SCL_TIME:
			abscissa = ((i * 1.0) / samplingFrequency);
			break;
		case SCL_FREQUENCY:
			abscissa = ((i * 1.0 * samplingFrequency) / samples);
			break;
		}
		Serial.print(abscissa, 6);
		Serial.print(" ");
		Serial.print(vData[i], 4);
		Serial.println();
	}
	Serial.println();
}
