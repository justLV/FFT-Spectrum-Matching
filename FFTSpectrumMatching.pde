
#include <stdint.h>
#include "PlainFFT.h"


#define SAMPLEFREQUENCY 22671
#define SCL_INDEX     0x00
#define SCL_TIME      0x01
#define SCL_FREQUENCY 0x02

#define MYAUDIOPIN 0

#define NSAMPLESBITS 8
#define NSAMPLES (2<<NSAMPLESBITS)

#define NCIRCULARBITS 16
#define NCIRCULAR (2<<NCIRCULARBITS)

static double circularBuffer[NCIRCULAR];
static int circularBufferIndex = 0;
static int circularBufferVisited = 0;

static PlainFFT FFT = PlainFFT();

/////////////////////////////////////////////////////////////////////////////////////////////////
// audio processing
/////////////////////////////////////////////////////////////////////////////////////////////////

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
 
  toggleLED();
  
  static double audioReal[NSAMPLES];
  static double audioImaginary[NSAMPLES];

  for(int i = 0; i < NSAMPLES; i++ ) audioReal[i] = circularBuffer[i+circularBufferVisited]; // memcpy?

  // first we need to weight the data - http://www.arduinoos.com/2010/10/fast-fourier-transform-fft-cont/
  FFT.Windowing(audioReal, NSAMPLES, FFT_WIN_TYP_HAMMING, FFT_FORWARD);
  //PrintVector(audioReal, NSAMPLES, SCL_TIME);

  // then we compute the fft - http://www.arduinoos.com/2010/10/fast-fourier-transform-fft-cont/
  FFT.Compute(audioReal, audioImaginary, NSAMPLES, FFT_FORWARD);
  PrintVector(audioReal, NSAMPLES, SCL_INDEX);
  PrintVector(audioImaginary, NSAMPLES, SCL_INDEX);

  // testing only : for analysis we need to convert numbers from imaginary to mangitude - but we may not need this to fingerprint audio.
  FFT.ComplexToMagnitude(audioReal, audioImaginary, NSAMPLES);
  PrintVector(audioReal, (NSAMPLES >> 1), SCL_FREQUENCY);

  // testing only : and the final goal for an example like this is to show we can pick out the major tone
  double x = FFT.MajorPeak(audioReal, NSAMPLES, SAMPLEFREQUENCY);
  SerialUSB.println(x, 6);
}

void process_setup() {
    pinMode(BOARD_LED_PIN, OUTPUT);
}


////////////////////////////////////////////////////////////////////////////////////////
// circular capture
////////////////////////////////////////////////////////////////////////////////////////

void circular_handler() {
   int sensorValue = analogRead(MYAUDIOPIN);
   circularBuffer[circularBufferIndex] = sensorValue;
   circularBufferIndex = (circularBufferIndex+1)&(NCIRCULAR-1);
}

void circular_setup() {

    // audio
  
    pinMode(MYAUDIOPIN, INPUT_ANALOG);

    // timer - a timer has a bunch of counters, when one of those counters rolls over specified value the timer fires...

    Timer3.pause();
    Timer3.refresh();
    Timer3.setChannel1Mode(TIMER_OUTPUTCOMPARE);
    Timer3.setCompare1(1);
    Timer3.attachCompare1Interrupt(circular_handler);

    // uint32_t cycles = (uint32_t)(22.671f * (float)CYCLES_PER_MICROSECOND);
    // uint16_t pre = (uint16_t)((cycles >> 16) + 1);
    // Timer3.setPrescaleFactor(pre);
    // Timer3.setOverflow((cycles / pre) - 1);

    Timer3.setPeriod( SAMPLEFREQUENCY / 1000 );
    Timer3.resume();

}

void circular_process() {
  while(true) {
    // if we are in the same general block - then wait for the block to be finished
    if((circularBufferVisited >> NSAMPLESBITS) == (circularBufferIndex >> NSAMPLESBITS) ) break;
    // otherwise move forward to the next block
    circularBufferVisited += ((circularBufferVisited+NSAMPLES)&(NCIRCULAR-1));
    // and chew on it
    process();
  }
}

/////////////////////////////////////////////////////////////////////////////////////////////////
// main
/////////////////////////////////////////////////////////////////////////////////////////////////

void loop() {
    circular_process();
}

void setup() {
    process_setup();  
    circular_setup();
}

