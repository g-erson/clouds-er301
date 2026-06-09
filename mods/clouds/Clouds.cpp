// Clouds granular processor wrapper for ER-301
// Based on Mutable Instruments Clouds by Emilie Gillet
// MIT License

#include <od/config.h>
#include <hal/ops.h>
#include <cstring>
#include <cstdlib>
#include <cmath>

// Save ER-301 macro values that conflict with Clouds
#ifdef INTERPOLATION_LINEAR
#define ER301_INTERPOLATION_LINEAR INTERPOLATION_LINEAR
#undef INTERPOLATION_LINEAR
#endif

// Include MI Clouds code - we define TEST to avoid STM32 hardware dependencies
#define TEST

// MI stmlib compatibility layer
#include "stmlib/stmlib.h"
#include "stmlib/dsp/filter.h"
#include "stmlib/dsp/parameter_interpolator.h"
#include "stmlib/utils/buffer_allocator.h"

// MI Clouds DSP code
#include "clouds/dsp/granular_processor.h"
#include "clouds/resources.h"

// Restore ER-301 macros
#ifdef ER301_INTERPOLATION_LINEAR
#undef INTERPOLATION_LINEAR
#define INTERPOLATION_LINEAR ER301_INTERPOLATION_LINEAR
#undef ER301_INTERPOLATION_LINEAR
#endif

// Now include our header (which includes od/objects/Object.h)
#include "Clouds.h"

namespace clouds_er301 {

  Clouds::Clouds() {
    addInput(mLeftIn);
    addInput(mRightIn);
    addOutput(mLeftOut);
    addOutput(mRightOut);
    addInput(mTrigger);
    addInput(mFreeze);

    addParameter(mPosition);
    addParameter(mSize);
    addParameter(mPitch);
    addParameter(mDensity);
    addParameter(mTexture);
    addParameter(mDryWet);
    addParameter(mStereo);
    addParameter(mFeedback);
    addParameter(mReverb);

    addOption(mPlaybackMode);
    addOption(mQuality);
  }

  Clouds::~Clouds() {
    if (mProcessor) {
      clouds::GranularProcessor* processor = 
        static_cast<clouds::GranularProcessor*>(mProcessor);
      delete processor;
    }
    if (mLargeBuffer) {
      free(mLargeBuffer);
    }
    if (mSmallBuffer) {
      free(mSmallBuffer);
    }
  }

  void Clouds::initProcessor() {
    if (mInitialized) return;

    // Allocate buffers
    mLargeBuffer = malloc(CLOUDS_LARGE_BUFFER_SIZE);
    mSmallBuffer = malloc(CLOUDS_SMALL_BUFFER_SIZE);

    if (!mLargeBuffer || !mSmallBuffer) {
      return;
    }

    // Zero buffers
    memset(mLargeBuffer, 0, CLOUDS_LARGE_BUFFER_SIZE);
    memset(mSmallBuffer, 0, CLOUDS_SMALL_BUFFER_SIZE);

    // Create and initialize processor
    clouds::GranularProcessor* processor = new clouds::GranularProcessor();
    processor->Init(mLargeBuffer, CLOUDS_LARGE_BUFFER_SIZE,
                    mSmallBuffer, CLOUDS_SMALL_BUFFER_SIZE);

    mProcessor = processor;
    mInitialized = true;
  }

  void Clouds::processBlock(float *leftIn, float *rightIn,
                            float *leftOut, float *rightOut,
                            float *trigger, float *freeze,
                            int size) {
    clouds::GranularProcessor* processor = 
      static_cast<clouds::GranularProcessor*>(mProcessor);

    clouds::Parameters* params = processor->mutable_parameters();

    // Update parameters from control inputs
    params->position = CLAMP(0.0f, 1.0f, mPosition.value());
    params->size = CLAMP(0.0f, 1.0f, mSize.value());
    params->pitch = mPitch.value();  // Semitones, -48 to +48
    params->density = CLAMP(0.0f, 1.0f, mDensity.value());
    params->texture = CLAMP(0.0f, 1.0f, mTexture.value());
    params->dry_wet = CLAMP(0.0f, 1.0f, mDryWet.value());
    params->stereo_spread = CLAMP(0.0f, 1.0f, mStereo.value());
    params->feedback = CLAMP(0.0f, 1.0f, mFeedback.value());
    params->reverb = CLAMP(0.0f, 1.0f, mReverb.value());

    // Update playback mode
    int mode = mPlaybackMode.value();
    if (mode >= 0 && mode < clouds::PLAYBACK_MODE_LAST) {
      processor->set_playback_mode(static_cast<clouds::PlaybackMode>(mode));
    }

    // Update quality
    int quality = mQuality.value();
    processor->set_quality(quality);

    // Process trigger and freeze - check rising edges
    bool currentFreeze = freeze[0] > 0.1f;
    bool currentTrigger = trigger[0] > 0.1f;

    if (currentFreeze != mPreviousFreeze) {
      processor->set_freeze(currentFreeze);
      mPreviousFreeze = currentFreeze;
    }

    params->trigger = currentTrigger && !mPreviousTrigger;
    params->gate = currentTrigger;
    mPreviousTrigger = currentTrigger;

    // Prepare processor (handles mode changes, buffer allocation)
    processor->Prepare();

    // Convert float input to ShortFrame format (int16)
    clouds::ShortFrame input[clouds::kMaxBlockSize];
    clouds::ShortFrame output[clouds::kMaxBlockSize];

    for (int i = 0; i < size; i++) {
      input[i].l = static_cast<int16_t>(CLAMP(-1.0f, 1.0f, leftIn[i]) * 32767.0f);
      input[i].r = static_cast<int16_t>(CLAMP(-1.0f, 1.0f, rightIn[i]) * 32767.0f);
    }

    // Process
    processor->Process(input, output, size);

    // Convert output back to float
    for (int i = 0; i < size; i++) {
      leftOut[i] = static_cast<float>(output[i].l) / 32768.0f;
      rightOut[i] = static_cast<float>(output[i].r) / 32768.0f;
    }
  }

  void Clouds::process() {
    // Initialize on first process call
    if (!mInitialized) {
      initProcessor();
      if (!mInitialized) {
        // Failed to initialize, output silence
        float *leftOut = mLeftOut.buffer();
        float *rightOut = mRightOut.buffer();
        memset(leftOut, 0, FRAMELENGTH * sizeof(float));
        memset(rightOut, 0, FRAMELENGTH * sizeof(float));
        return;
      }
    }

    float *leftIn = mLeftIn.buffer();
    float *rightIn = mRightIn.buffer();
    float *leftOut = mLeftOut.buffer();
    float *rightOut = mRightOut.buffer();
    float *trigger = mTrigger.buffer();
    float *freeze = mFreeze.buffer();

    // Clouds processes in blocks of up to 32 samples
    const int blockSize = clouds::kMaxBlockSize;
    int remaining = FRAMELENGTH;
    int offset = 0;

    while (remaining > 0) {
      int toProcess = (remaining > blockSize) ? blockSize : remaining;
      processBlock(leftIn + offset, rightIn + offset,
                   leftOut + offset, rightOut + offset,
                   trigger + offset, freeze + offset,
                   toProcess);
      offset += toProcess;
      remaining -= toProcess;
    }
  }

} // namespace clouds_er301
