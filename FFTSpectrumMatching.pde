
#include <stdint.h>
#include "PlainFFT.h"

#define SENSORPIN 0

#define NSAMPLES 64
#define SIGNALFREQUENCY 1000
#define SAMPLEFREQUENCY 5000

#define SCL_INDEX     0x00
#define SCL_TIME      0x01
#define SCL_FREQUENCY 0x02

static PlainFFT FFT = PlainFFT();
static double vReal[NSAMPLES];
static double vImag[NSAMPLES];
static int count = 0;

void PrintVector(double *vData, uint8_t bufferSize, uint8_t scaleType)  {	
	for (uint16_t i = 0; i < bufferSize; i++) {
		double abscissa = 0;
		/* Print abscissa value */
		switch (scaleType) {
		case SCL_INDEX:
			abscissa = (i * 1.0);
			break;
		case SCL_TIME:
			abscissa = ((i * 1.0) / SAMPLEFREQUENCY);
			break;
		case SCL_FREQUENCY:
			abscissa = ((i * 1.0 * SAMPLEFREQUENCY) / NSAMPLES);
			break;
		}
		SerialUSB.print(abscissa, 6);
		SerialUSB.print(" ");
		SerialUSB.print(vData[i], 4);
		SerialUSB.println();
	}
	SerialUSB.println();
}

void process() {

  	//PrintVector(vReal, NSAMPLES, SCL_TIME);

	FFT.Windowing(vReal, NSAMPLES, FFT_WIN_TYP_HAMMING, FFT_FORWARD); /* Weigh data */
	PrintVector(vReal, NSAMPLES, SCL_TIME);

	FFT.Compute(vReal, vImag, NSAMPLES, FFT_FORWARD); /* Compute FFT */
	PrintVector(vReal, NSAMPLES, SCL_INDEX);
	PrintVector(vImag, NSAMPLES, SCL_INDEX);

	FFT.ComplexToMagnitude(vReal, vImag, NSAMPLES); /* Compute magnitudes */
	//PrintVector(vReal, (NSAMPLES >> 1), SCL_FREQUENCY);

	double x = FFT.MajorPeak(vReal, NSAMPLES, SAMPLEFREQUENCY);
	SerialUSB.println(x, 6);
}

void loop()  {

  // xxx todo:
  // - what is the maximum htz of this loop? we need to throttle it to a specific rate - probably 24000 or so to catch frequencies we want.
  // - we need a delay or else the serial output will overload the mac serial port

        int sensorValue = analogRead(SENSORPIN);

        vReal[count] = sensorValue;
        count++;
        if(count>=64) {
          count = 0;
          process();
        }



        // make a test sine wave
  	//double cycles = (((NSAMPLES-1) * SIGNALFREQUENCY) / SAMPLEFREQUENCY);
	//for (uint8_t i = 0; i < NSAMPLES; i++) {
	//	vReal[i] = uint8_t((SIGNALINTENSITY * (sin((i * (6.2831 * cycles)) / NSAMPLES) + 1.0)) / 2.0);
	//}

}

void setup() {

    pinMode(SENSORPIN, INPUT_ANALOG);

    // Declare the LED's pin as an OUTPUT.  (BOARD_LED_PIN is a built-in
    // constant which is the pin number of the built-in LED.  On the
    // Maple, it is 13.)
    pinMode(BOARD_LED_PIN, OUTPUT);

}

