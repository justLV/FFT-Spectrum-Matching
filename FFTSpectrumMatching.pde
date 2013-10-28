
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

        // first we need to weight the data - http://www.arduinoos.com/2010/10/fast-fourier-transform-fft-cont/
	FFT.Windowing(vReal, NSAMPLES, FFT_WIN_TYP_HAMMING, FFT_FORWARD);
	//PrintVector(vReal, NSAMPLES, SCL_TIME);

        // then we compute the fft - http://www.arduinoos.com/2010/10/fast-fourier-transform-fft-cont/
	FFT.Compute(vReal, vImag, NSAMPLES, FFT_FORWARD);
	PrintVector(vReal, NSAMPLES, SCL_INDEX);
	PrintVector(vImag, NSAMPLES, SCL_INDEX);

        // testing only : for analysis we need to convert numbers from imaginary to mangitude - but we may not need this to fingerprint audio.
	FFT.ComplexToMagnitude(vReal, vImag, NSAMPLES);
	PrintVector(vReal, (NSAMPLES >> 1), SCL_FREQUENCY);

        // testing only : and the final goal for an example like this is to show we can pick out the major tone
	double x = FFT.MajorPeak(vReal, NSAMPLES, SAMPLEFREQUENCY);
	SerialUSB.println(x, 6);
}

void loop()  {

  // xxx todo
  
  // we need something like this :
 
  // http://www.arduinoos.com/2010/10/sound-capture-cont/
  // http://forums.leaflabs.com/topic.php?id=12668
  // http://leaflabs.com/2010/07/audio-and-guitar-effects-on-maple/
  // http://forums.leaflabs.com/topic.php?id=162
  // http://forums.leaflabs.com/topic.php?id=154#post-1001
  
  // the last link above is a good example - they have a busy wait loop that watches the raw input and accumulates as fast as it can.
  // once they are happy with what they have they stop and do some processing.
  // we could do this, throwing away data at a certain rate.
 
  // we also need a general delay() just to print debug without thrashing our serial port
  
  
//    ADC.acquireData(vData);
//    for (uint16_t i = 0; i < samples; i++) {
//        vReal[i] = double(vData[i]);
//    }


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

void myhandler() {
}

void setup() {
  
    // led

    pinMode(BOARD_LED_PIN, OUTPUT);

    // audio
  
    pinMode(SENSORPIN, INPUT_ANALOG);

    // timer - a timer has a bunch of counters, when one of those counters rolls over specified value the timer fires.


    Timer3.pause();
    Timer3.refresh();
    Timer3.setChannel1Mode(TIMER_OUTPUTCOMPARE);
    Timer3.setCompare1(1);
    Timer3.attachCompare1Interrupt(myhandler);

    // uint32_t cycles = (uint32_t)(22.671f * (float)CYCLES_PER_MICROSECOND);
    // uint16_t pre = (uint16_t)((cycles >> 16) + 1);
    // Timer3.setPrescaleFactor(pre);
    // Timer3.setOverflow((cycles / pre) - 1);

    Timer3.setPeriod( 22.671f);
    Timer3.resume();

}

