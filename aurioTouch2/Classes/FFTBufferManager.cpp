

#include "FFTBufferManager.h"
#include "CABitOperations.h"
#include "CAStreamBasicDescription.h"

#define min(x,y) (x < y) ? x : y

FFTBufferManager::FFTBufferManager(UInt32 inNumberFrames) :
mNeedsAudioData(0),
mHasAudioData(0),
mFFTNormFactor(1.0/(2*inNumberFrames)),
mAdjust0DB(1.5849e-13),
m24BitFracScale(16777216.0f),
mFFTLength(inNumberFrames/2),
mLog2N(Log2Ceil(inNumberFrames)),
mNumberFrames(inNumberFrames),
mAudioBufferSize(inNumberFrames * sizeof(Float32)),
mAudioBufferCurrentIndex(0)

{
    mAudioBuffer = (Float32*) calloc(mNumberFrames,sizeof(Float32));
    mDspSplitComplex.realp = (Float32*) calloc(mFFTLength,sizeof(Float32));
    mDspSplitComplex.imagp = (Float32*) calloc(mFFTLength, sizeof(Float32));
    mSpectrumAnalysis = vDSP_create_fftsetup(mLog2N, kFFTRadix2);
	OSAtomicIncrement32Barrier(&mNeedsAudioData);
}

FFTBufferManager::~FFTBufferManager()
{
    vDSP_destroy_fftsetup(mSpectrumAnalysis);
    free(mAudioBuffer);
    free (mDspSplitComplex.realp);
    free (mDspSplitComplex.imagp);
}

void FFTBufferManager::GrabAudioData(AudioBufferList *inBL)
{
	if (mAudioBufferSize < inBL->mBuffers[0].mDataByteSize)	return;
	
	UInt32 bytesToCopy = min(inBL->mBuffers[0].mDataByteSize, mAudioBufferSize - mAudioBufferCurrentIndex);
	memcpy(mAudioBuffer+mAudioBufferCurrentIndex, inBL->mBuffers[0].mData, bytesToCopy);
	
	mAudioBufferCurrentIndex += bytesToCopy / sizeof(Float32);
	if (mAudioBufferCurrentIndex >= mAudioBufferSize / sizeof(Float32))
	{
		OSAtomicIncrement32Barrier(&mHasAudioData);
		OSAtomicDecrement32Barrier(&mNeedsAudioData);
	}
}

void learn(float* frame,int size);

Boolean	FFTBufferManager::ComputeFFT(int32_t *outFFTData)
{
	if (HasNewAudioData())
	{
        //Generate a split complex vector from the real data
        vDSP_ctoz((COMPLEX *)mAudioBuffer, 2, &mDspSplitComplex, 1, mFFTLength);
        
        //Take the fft and scale appropriately
        vDSP_fft_zrip(mSpectrumAnalysis, &mDspSplitComplex, 1, mLog2N, kFFTDirection_Forward);
        vDSP_vsmul(mDspSplitComplex.realp, 1, &mFFTNormFactor, mDspSplitComplex.realp, 1, mFFTLength);
        vDSP_vsmul(mDspSplitComplex.imagp, 1, &mFFTNormFactor, mDspSplitComplex.imagp, 1, mFFTLength);
        
        //Zero out the nyquist value
        mDspSplitComplex.imagp[0] = 0.0;
        
        //Convert the fft data to dB
        Float32 tmpData[mFFTLength];
        vDSP_zvmags(&mDspSplitComplex, 1, tmpData, 1, mFFTLength);
        
        //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
        vDSP_vsadd(tmpData, 1, &mAdjust0DB, tmpData, 1, mFFTLength);
        Float32 one = 1;
        vDSP_vdbcon(tmpData, 1, &one, tmpData, 1, mFFTLength, 0);
        
        //Convert floating point data to integer (Q7.24)
        vDSP_vsmul(tmpData, 1, &m24BitFracScale, tmpData, 1, mFFTLength);
        for(UInt32 i=0; i<mFFTLength; ++i)
            outFFTData[i] = (SInt32) tmpData[i];

        learn(tmpData,mFFTLength);
        
        OSAtomicDecrement32Barrier(&mHasAudioData);
		OSAtomicIncrement32Barrier(&mNeedsAudioData);
		mAudioBufferCurrentIndex = 0;
		return true;
	}
	else if (mNeedsAudioData == 0)
		OSAtomicIncrement32Barrier(&mNeedsAudioData);
	
	return false;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// matcher
///////////////////////////////////////////////////////////////////////////////////////////////////

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
// Comparator
/////////////////////////////////////////////////////////////////////////////////////////

const int FRAMESMAX = 8;
const int FRAMESIZE = 2048;

typedef struct {
    int nframes;
    int nframesmatched;
    float frames[FRAMESMAX][FRAMESIZE];
    void reset() {
        nframesmatched = 0;
    }
    bool learn(float* frame) {
        if(nframes < FRAMESMAX) {
            memcpy(frames[nframes],frame,FRAMESIZE*sizeof(float));
            nframes++;
            return true;
        }
        return false;
    }
    bool match(float* frame) {
        if(nframes==0)return false;
        DIVERGENCE_ERROR_TYPE stats;
        Divergence__Error(512, frame, frames[nframesmatched], &stats);
        if(stats.MeanSqError < 5) {
            nframesmatched++;
            if(nframesmatched >= nframes) {
                nframesmatched = 0;
                return true;
            } else {
                return false;
            }
        }
        nframesmatched = 0;
        return false;
    }
} Chirp;

#define NCHIRPSMAX 4
Chirp chirps[NCHIRPSMAX];
int nchirps = 0;
int state = 0;

void learn(float* frame, int size) {

    bool loud = false;
    
    if(size != 2048) { // hack
        return;
    }

    // test
    //float buffer[2048];
    //memcpy(buffer,frame,2048*sizeof(float));
    //float biggest = 0;
    //for(int i = 0; i < 2048; i++) {
    //    if(i==0 || buffer[i] > biggest) biggest = buffer[i];
    //}
    //printf("biggest is %f\n",biggest);
    
    for(int i = 0; i < 2048; i++) {
        if(frame[i] > -966478848.0) {
            loud = 1;
            break;
        }
    }
    
    switch(state) {
            
        case 0:
            if(!loud) break;
            state = 1;
            
        case 1:
            if(!loud) {
                nchirps++;
                state = nchirps>=NCHIRPSMAX ? 2 : 0;
                printf("learned a sound\n");
            } else {
                chirps[nchirps].learn(frame);
            }
            break;

        case 2:
            for(int i = 0; i < nchirps && i<NCHIRPSMAX;i++) {
                if( chirps[i].match(frame) ) {
                    printf("found a match against sound %d\n",i);
                    for(int j = 0; j < NCHIRPSMAX;j++) chirps[j].reset();
                    break;
                }
            }
    }

}







