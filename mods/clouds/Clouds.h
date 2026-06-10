// Clouds granular processor wrapper for ER-301
// Based on Mutable Instruments Clouds by Emilie Gillet
// MIT License

#pragma once

#include <od/objects/Object.h>

// Buffer sizes for Clouds granular processor
// Large buffer: ~120KB for audio recording
// Small buffer: ~64KB for FX workspace
#define CLOUDS_LARGE_BUFFER_SIZE (118784)
#define CLOUDS_SMALL_BUFFER_SIZE (65536 - 128)

namespace clouds_er301 {

  class Clouds : public od::Object {
    public:
      Clouds();
      virtual ~Clouds();

#ifndef SWIGLUA
      virtual void process();

      // Audio I/O
      od::Inlet  mLeftIn   { "In1" };
      od::Inlet  mRightIn  { "In2" };
      od::Outlet mLeftOut  { "Out1" };
      od::Outlet mRightOut { "Out2" };

      // Trigger/Gate inputs
      od::Inlet mTrigger { "Trigger" };
      od::Inlet mFreeze  { "Freeze" };

      // Parameter control inlets (0-1 range unless noted)
      od::Inlet mPosition  { "Position" };   // Buffer position
      od::Inlet mSize      { "Size" };       // Grain size
      od::Inlet mPitch     { "Pitch" };      // Pitch shift in semitones (-48 to +48)
      od::Inlet mDensity   { "Density" };    // Grain density
      od::Inlet mTexture   { "Texture" };    // Grain texture/quality
      od::Inlet mDryWet    { "Dry/Wet" };    // Dry/wet mix
      od::Inlet mInGain    { "In Gain" };    // Input gain
      od::Inlet mStereo    { "Stereo" };     // Stereo spread
      od::Inlet mFeedback  { "Feedback" };   // Feedback amount
      od::Inlet mReverb    { "Reverb" };     // Reverb amount

      // Mode and quality options
      od::Option mPlaybackMode { "Mode", 0 };     // 0=Granular, 1=Stretch, 2=Looping, 3=Spectral
      od::Option mQuality      { "Quality", 0 };  // 0=16bit stereo, 1=16bit mono, 2=8bit stereo, 3=8bit mono

    private:
      void* mLargeBuffer = nullptr;
      void* mSmallBuffer = nullptr;
      void* mProcessor = nullptr;

      bool mInitialized = false;
      bool mPreviousFreeze = false;
      bool mPreviousTrigger = false;

      void initProcessor();
      void processBlock(float *leftIn, float *rightIn, 
                        float *leftOut, float *rightOut, 
                        float *trigger, float *freeze,
                        float *position, float *size, float *pitch,
                        float *density, float *texture, float *drywet,
                        float *inGain, float *stereo, float *feedback, float *reverb,
                        int blockSize);
#endif
  };

} // namespace clouds_er301
