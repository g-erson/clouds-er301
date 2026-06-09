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
      od::Inlet  mLeftIn   { "Left In" };
      od::Inlet  mRightIn  { "Right In" };
      od::Outlet mLeftOut  { "Left Out" };
      od::Outlet mRightOut { "Right Out" };

      // Trigger/Gate inputs
      od::Inlet mTrigger { "Trigger" };
      od::Inlet mFreeze  { "Freeze" };

      // Main parameters (0-1 range unless noted)
      od::Parameter mPosition  { "Position", 0.5f };   // Buffer position
      od::Parameter mSize      { "Size", 0.5f };       // Grain size
      od::Parameter mPitch     { "Pitch", 0.0f };      // Pitch shift in semitones (-48 to +48)
      od::Parameter mDensity   { "Density", 0.5f };    // Grain density
      od::Parameter mTexture   { "Texture", 0.5f };    // Grain texture/quality
      od::Parameter mDryWet    { "Dry/Wet", 0.5f };    // Dry/wet mix
      od::Parameter mStereo    { "Stereo", 0.0f };     // Stereo spread
      od::Parameter mFeedback  { "Feedback", 0.0f };   // Feedback amount
      od::Parameter mReverb    { "Reverb", 0.0f };     // Reverb amount

      // Mode and quality options
      od::Option mPlaybackMode { "Mode", 0 };          // 0=Granular, 1=Stretch, 2=Looping, 3=Spectral
      od::Option mQuality      { "Quality", 0 };       // 0=16bit stereo, 1=16bit mono, 2=8bit stereo, 3=8bit mono

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
                        int size);
#endif
  };

} // namespace clouds_er301
