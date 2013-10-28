

#include <stdint.h>
#include <string.h>


#include "PlainFFT.h"

#define twoPi 6.28318531
#define fourPi 12.56637061

// High level matching

typedef struct
{
    int DataSize;
    float TotalError;
    float AbsError;       //< Total Absolute Error
    float SqError;        //< Total Squared Error
    float MeanError;
    float MeanAbsError;
    float MeanSqError;
    float RMSError;     //< Root Mean Square Error
} DIVERGENCE_ERROR_TYPE;

void Divergence__Error(int size, float expected[], float actual[], DIVERGENCE_ERROR_TYPE *error);

#ifndef ABS
#define ABS(x) ((x)>0) ? (x) : (0-(x))
#endif

void Divergence__Error(int size, float expected[], float actual[], DIVERGENCE_ERROR_TYPE *error)
{
    double total_err = 0.0;
    double abs_err = 0.0;
    double abs_sqr_err = 0.0;
    double temp = 0.0;
    int index = 0;
    
    for(index=0; index<size; index++)
    {
        temp = (double)(actual[index])-(double)(expected[index]);
        total_err+=temp;
        abs_err+=ABS(temp);
        abs_sqr_err+=pow(ABS(temp),2);
    }
    
    temp = (double)size;
    error->DataSize = (int)size;
    error->TotalError = (float)total_err;
    error->AbsError = (float)abs_err;
    error->SqError = (float)abs_sqr_err;
    error->MeanError = (float)(total_err/temp);
    error->MeanAbsError = (float)(abs_err/temp);
    error->MeanSqError = (float)(abs_sqr_err/temp);
    error->RMSError = (float)(sqrt(abs_sqr_err/temp));
}


/////////////////////////////////////////////////////////////////////////////////////////
// Learning phase
/////////////////////////////////////////////////////////////////////////////////////////

// each sound sample buffer is this size
#define SAMPLESIZE 512

// our frequency per sound sample is every n milliseconds
#define SAMPLEBINDURATION 10

// each chirp can have up to this many samples
#define SAMPLESMAX 25

// we allow this many different chirps maximum
#define NCHIRPS 8

// this is the representation of all of our chirps
int state = 0;
int sample = 0;
int chirp = 0;
int matchindex = 0;
int chirplen[NCHIRPS];
bool matched[NCHIRPS];
float chirps[NCHIRPS][SAMPLESMAX][SAMPLESIZE];

void learn(float* sampledata,bool loud) {

    if(state == 1) {
        // if we've become quiet then do nothing
        if(!loud) state = 0;
    } else {
        // if we've become active and we have more chirps to accumulate go to the next chirp
        if(loud) {
            // save this one if it is big enough
            if(chirp < NCHIRPS-1) {
                if(sample > 1) {
                    //printf("saved a chirp %d-%d\n",chirp,sample);
                    chirp++;
                }
                state = 1;
                sample = 0;
            }
        }
    }

    if(state == 1) {
        // if we are recording into a chirp and have room then continue to do so
        if(sample < SAMPLESMAX) {
            memcpy(chirps[chirp][sample],sampledata,SAMPLESIZE);
            sample++;
            chirplen[chirp] = sample;
            //printf("saving part of a chirp %d-%d\n",chirp,sample);
        }
    }
    
}

void match(float* sampledata) {
    
    if(chirp<NCHIRPS-1)return; // don't match until we have learned
    
    if(!sampledata) {
        matchindex = 0;
        return;
    }

    for(int i = 0; i < NCHIRPS; i++) {
        // if the length of chirp is still not reached, or we are at start of match then match
        if(chirplen[i] > matchindex && (matchindex == 0 || matched[i])) {
            DIVERGENCE_ERROR_TYPE stats;
            Divergence__Error(512, sampledata, chirps[i][matchindex], &stats );
            if(stats.MeanSqError < 5) {
                //printf("...Found a matching sound at slot: %d with error %f\n",i,stats.MeanSqError);
                matched[i] = 1;
                if(chirplen[i] == matchindex + 1) {
                    //printf("...Found a matching chirp! %d\n",i);
                }
            } else {
                matched[i] = 0;
            }
        }
    }
    matchindex++;
}


