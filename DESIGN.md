# ER-301 Unit Architecture

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        ER-301 Unit                          │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Lua)                                             │
│  ├── ViewControl/*.lua    - Custom UI controls              │
│  └── Unit.lua             - View definitions                │
├─────────────────────────────────────────────────────────────┤
│  Lua Unit Definition                                        │
│  ├── <Unit>.lua           - Graph wiring, lifecycle         │
│  └── toc.lua              - Unit registry                   │
├─────────────────────────────────────────────────────────────┤
│  SWIG Bindings                                              │
│  └── <mod>.cpp.swig       - Exposes C++ to Lua              │
├─────────────────────────────────────────────────────────────┤
│  DSP Layer (C++)                                            │
│  ├── <Unit>.h             - Class declaration               │
│  └── <Unit>.cpp           - process() implementation        │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Directory Structure

```
mods/<modname>/
├── mod.mk                      # Module makefile
├── <modname>.cpp.swig          # SWIG bindings
├── assets/                     # Lua code (deployed to ER-301)
│   ├── toc.lua                 # Unit registry
│   ├── <Category>/             # Unit category folders
│   │   └── <Unit>.lua          # Unit definition
│   └── ViewControl/            # Custom Lua UI controls
│       └── <Control>.lua
├── <Unit>.h                    # DSP header
├── <Unit>.cpp                  # DSP implementation
└── controls/                   # Custom C++ UI controls
    └── <Control>.h
```

**Shared code location:**
```
common/
├── assets/
│   ├── UnitShared.lua          # Common unit helpers
│   └── ViewControl/            # Shared UI controls
├── dsp/                        # Shared DSP headers
│   ├── filter.h                # SVF, biquad, onepole
│   ├── osc.h                   # Oscillator primitives
│   ├── env.h                   # Envelope generators
│   ├── pitch.h                 # V/Oct calculations
│   └── quantizer.h             # Scale quantization
└── util/                       # Math utilities (SIMD)
```

---

## 3. DSP Layer (C++)

### Base Class

All DSP units inherit from `od::Object`.

### Inlets, Outlets, Parameters, Options

```cpp
#pragma once
#include <od/objects/Object.h>

namespace modname {
  class MyUnit : public od::Object {
    public:
      MyUnit() {
        addInput(mIn);
        addOutput(mOut);
        addInput(mGate);
        addParameter(mFreq);
        addOption(mMode);
      }

#ifndef SWIGLUA
      virtual void process();

      // Audio/CV I/O
      od::Inlet  mIn   { "In" };
      od::Outlet mOut  { "Out" };
      od::Inlet  mGate { "Gate" };

      // Modulatable parameters
      od::Parameter mFreq   { "Frequency", 440.0f };
      od::Parameter mAmount { "Amount", 0.5f };

      // Discrete choices (integers)
      od::Option mMode  { "Mode", 0 };
      od::Option mSense { "Sense", 0 };
#endif
  };
}
```

### process() Function

```cpp
#include <MyUnit.h>
#include <hal/simd.h>

namespace modname {
  void MyUnit::process() {
    float *in   = mIn.buffer();
    float *gate = mGate.buffer();
    float *out  = mOut.buffer();

    float freq = mFreq.value();

    for (int i = 0; i < FRAMELENGTH; i++) {
      out[i] = in[i] * freq;
    }
  }
}
```

**Key constants:**
- `FRAMELENGTH` - Audio buffer size (128 samples)
- `globalConfig.sampleRate` - Current sample rate
- `globalConfig.samplePeriod` - 1/sampleRate

### SIMD Processing (ARM NEON)

```cpp
#include <hal/simd.h>

void MyUnit::process() {
  float *in  = mIn.buffer();
  float *out = mOut.buffer();

  for (int i = 0; i < FRAMELENGTH; i += 4) {
    // Load 4 floats
    float32x4_t v = vld1q_f32(in + i);

    // Operations
    float32x4_t result = vmulq_f32(v, vdupq_n_f32(2.0f));

    // Store 4 floats
    vst1q_f32(out + i, result);
  }
}
```

**Common NEON operations:**

| Operation | Function |
|-----------|----------|
| Load 4 floats | `vld1q_f32(ptr)` |
| Store 4 floats | `vst1q_f32(ptr, v)` |
| Broadcast scalar | `vdupq_n_f32(x)` |
| Add | `vaddq_f32(a, b)` |
| Multiply | `vmulq_f32(a, b)` |
| Multiply-accumulate | `vmlaq_f32(acc, a, b)` |
| Compare > | `vcgtq_f32(a, b)` → `uint32x4_t` |
| Compare >= | `vcgeq_f32(a, b)` |
| Bitwise AND | `vandq_u32(a, b)` |
| Bitwise OR | `vorrq_u32(a, b)` |
| Select (mask) | `vbslq_f32(mask, a, b)` |
| Min | `vminq_f32(a, b)` |
| Max | `vmaxq_f32(a, b)` |
| Convert u32→f32 | `vcvtq_n_f32_u32(v, 32)` |

---

## 4. SWIG Bindings

**File:** `<modname>.cpp.swig`

```cpp
%module modname_libmodname
%include <od/glue/mod.cpp.swig>

// Include common bindings if using shared code
%include <common.cpp.swig>

%{
// Compilation includes (not parsed by SWIG)
#undef SWIGLUA
#include <MyUnit.h>
#include <AnotherUnit.h>
#define SWIGLUA
%}

// SWIG parsing includes
%include <MyUnit.h>
%include <AnotherUnit.h>
```

**Template instantiation (for C++ templates):**

```cpp
%{
#include <PolyVoice.h>
%}

%include <PolyVoice.h>

%template(Quartet) modname::PolyVoice<4>;
%template(Octet) modname::PolyVoice<8>;
```

---

## 5. Lua Unit Definition

### Required Imports

```lua
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local modname = require "modname.libmodname"  -- SWIG bindings

-- Optional common helpers
local UnitShared = require "common.assets.UnitShared"
```

### Class Structure

```lua
local MyUnit = Class {}
MyUnit:include(Unit)
MyUnit:include(UnitShared)  -- Optional helpers

function MyUnit:init(args)
  args.title = "My Unit"
  args.mnemonic = "MU"
  Unit.init(self, args)
end

return MyUnit
```

### Lifecycle Methods

| Method | Purpose |
|--------|---------|
| `init(args)` | Set title, mnemonic, call `Unit.init(self, args)` |
| `onLoadGraph(channelCount)` | Create DSP objects, wire connections |
| `onLoadViews()` | Define UI controls, return views table and layout |
| `onShowMenu(objects)` | Define context menu options |
| `serialize()` | Save custom state |
| `deserialize(t)` | Restore custom state |
| `onRemove()` | Cleanup on unit removal |

### onLoadGraph

```lua
function MyUnit:onLoadGraph(channelCount)
  -- Create DSP object
  local op = self:addObject("op", modname.MyUnit())

  -- Create controls
  local gate = self:addComparatorControl("gate", app.COMPARATOR_GATE)
  local freq = self:addGainBiasControl("freq")

  -- Wire inputs
  connect(self, "In1", op, "In")
  connect(gate, "Out", op, "Gate")
  connect(freq, "Out", op, "Frequency")

  -- Wire outputs
  for i = 1, channelCount do
    connect(op, "Out", self, "Out" .. i)
  end

  -- Bind parameters
  tie(op, "Amount", someAdapter, "Out")
end
```

### Connection Functions

```lua
-- Audio/CV connection
connect(sourceObject, "OutletName", destObject, "InletName")

-- Parameter binding (adapter output controls parameter)
tie(dspObject, "ParameterName", adapterObject, "Out")
```

---

## 6. Control Types

### Adding Controls in onLoadGraph

| Control Type | Function | Purpose |
|--------------|----------|---------|
| Comparator | `self:addComparatorControl(name, type)` | Gate/trigger input |
| GainBias | `self:addGainBiasControl(name)` | CV with gain + offset |
| ConstantOffset | `self:addConstantOffsetControl(name)` | V/Oct pitch input |
| ParameterAdapter | `self:addParameterAdapterControl(name)` | Modulatable parameter |

**Comparator types:**

| Type | Constant |
|------|----------|
| Gate | `app.COMPARATOR_GATE` |
| Trigger (rise) | `app.COMPARATOR_TRIGGER_ON_RISE` |
| Trigger (fall) | `app.COMPARATOR_TRIGGER_ON_FALL` |
| Toggle | `app.COMPARATOR_TOGGLE` |

### Control Objects Created

```lua
-- addComparatorControl creates:
self.objects.gate        -- The comparator object
self.branches.gate       -- Branch for sub-chain

-- addGainBiasControl creates:
self.objects.freq        -- GainBias object
self.objects.freqRange   -- MinMax object for range display
self.branches.freq       -- Branch for sub-chain

-- addConstantOffsetControl creates:
self.objects.tune        -- ConstantOffset object
self.objects.tuneRange   -- MinMax object
self.branches.tune       -- Branch

-- addParameterAdapterControl creates:
self.objects.amount      -- ParameterAdapter object
self.branches.amount     -- Branch
```

---

## 7. UI Layer

### onLoadViews

```lua
function MyUnit:onLoadViews()
  return {
    -- View control definitions
    gate = self:gateView("gate", "Gate"),

    freq = self:gainBiasView("freq", "Frequency", {
      biasMap = Encoder.getMap("oscFreq"),
      biasUnits = app.unitHertz,
      initialBias = 440
    }),

    tune = self:pitchView("tune", "V/Oct"),

    scope = self:scopeView("scope")
  }, {
    -- View layouts
    expanded  = { "gate", "freq", "tune" },
    collapsed = {},
    scope     = { "scope" }
  }
end
```

### Standard View Controls

```lua
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Pitch = require "Unit.ViewControl.Pitch"
local Fader = require "Unit.ViewControl.Fader"
local OptionControl = require "Unit.ViewControl.OptionControl"
local OutputScope = require "Unit.ViewControl.OutputScope"
local InputGate = require "Unit.ViewControl.InputGate"
```

### UnitShared Helper Views

If using `UnitShared`:

```lua
self:gateView(name, description)
self:gainBiasView(name, description, options)
self:pitchView(name, description)
self:intView(name, description, options)
self:scopeView(name)
```

### Manual View Definition

```lua
freq = GainBias {
  button      = "freq",
  description = "Frequency",
  branch      = self.branches.freq,
  gainbias    = self.objects.freq,
  range       = self.objects.freqRange,
  biasMap     = Encoder.getMap("oscFreq"),
  biasUnits   = app.unitHertz,
  initialBias = 27.5
}
```

### Option Control

```lua
mode = OptionControl {
  button      = "mode",
  description = "Output Mode",
  option      = self.objects.op:getOption("Mode"),
  choices     = { "trigger", "gate", "through" }
}
```

### Dial Maps

```lua
local Encoder = require "Encoder"

-- Built-in maps
Encoder.getMap("oscFreq")
Encoder.getMap("unit")
Encoder.getMap("gain")

-- Custom linear map
local map = app.LinearDialMap(min, max)
map:setSteps(superCoarse, coarse, fine, superFine)
map:setRounding(0.1)  -- Optional rounding

-- Custom integer map
local intMap = app.LinearDialMap(1, 16)
intMap:setSteps(5, 1, 1, 1)
intMap:setRounding(1)
```

### Custom C++ Graphics

```cpp
// In controls/MyGraphic.h
#pragma once
#include <od/graphics/Graphic.h>

namespace modname {
  class MyGraphic : public od::Graphic {
    public:
      MyGraphic(int left, int bottom, int width, int height);

      virtual void draw(od::FrameBuffer &fb) override {
        fb.clear(BLACK);
        fb.line(WHITE, x1, y1, x2, y2);
        fb.circle(WHITE, cx, cy, radius);
        fb.fillCircle(WHITE, cx, cy, radius);
        fb.box(WHITE, left, bottom, right, top);
        fb.text(WHITE, x, y, "text", 10);
      }

      void follow(MyUnit *pUnit) {
        mpUnit = pUnit;
      }

    private:
      MyUnit *mpUnit = nullptr;
  };
}
```

### Custom Lua View Control

```lua
-- ViewControl/MyControl.lua
local app = app
local Class = require "Base.Class"
local Base = require "Unit.ViewControl.EncoderControl"
local modname = require "modname.libmodname"
local ply = app.SECTION_PLY

local MyControl = Class {}
MyControl:include(Base)

function MyControl:init(args)
  Base.init(self, "mycontrol")

  -- Create C++ graphic
  local width = 2 * ply
  self.pDisplay = modname.MyGraphic(0, 0, width, 64)
  self:setMainCursorController(self.pDisplay)
  self:setControlGraphic(self.pDisplay)

  -- Add readouts
  self.readout = app.Readout(0, 0, ply, 10)
  self.readout:setParameter(args.param)
  self.pDisplay:addChild(self.readout)
end

function MyControl:encoder(change, shifted)
  self.readout:encoder(change, shifted, false)
  return true
end

return MyControl
```

---

## 8. Unit Registry (toc.lua)

```lua
return {
  name    = "modname",
  title   = "Module Display Name",
  keyword = "modname",
  contact = "author@email.com",
  author  = "Author Name",
  units   = {
    {
      title      = "My Unit",
      moduleName = "Category.MyUnit",  -- Path: assets/Category/MyUnit.lua
      keywords   = "keyword1, keyword2"
    },
    {
      title      = "Another Unit",
      moduleName = "Category.AnotherUnit",
      keywords   = "keyword3"
    }
  }
}
```

---

## 9. Build System

### mod.mk

```makefile
PKGVERSION = 1.0.0
include scripts/mod-builder.mk
```

### Build Commands

```bash
# Build single module (development)
make -j modname

# Build and install to emulator
make modname-install

# Build all modules
make -j all

# Build for ER-301 hardware (via Docker)
make release

# Clean
make modname-clean
make clean
```

### Build Output

Creates `<modname>-<version>.pkg` containing:
- `lib<modname>.so` - Compiled shared library
- All files from `assets/`
- Common Lua utilities

---

## 10. Common DSP Patterns

### Gate/Trigger Detection

```cpp
// Sense threshold (low = 0.0, high = 0.1)
#define INPUT_SENSE_LOW  0
#define INPUT_SENSE_HIGH 1

inline float getSense(od::Option &option) {
  return option.value() == INPUT_SENSE_HIGH ? 0.1f : 0.0f;
}

// In process():
float sense = getSense(mSense);
for (int i = 0; i < FRAMELENGTH; i += 4) {
  uint32x4_t isHigh = vcgtq_f32(vld1q_f32(gate + i), vdupq_n_f32(sense));
  // Use isHigh as mask...
}
```

### Edge Detection

```cpp
// Track previous state
bool mPrevHigh = false;

// In process():
for (int i = 0; i < FRAMELENGTH; i++) {
  bool high = gate[i] > sense;
  bool rise = high && !mPrevHigh;
  bool fall = !high && mPrevHigh;
  mPrevHigh = high;
}
```

### V/Oct Frequency Scaling

```cpp
#include <pitch.h>

// Base frequency with V/Oct modulation
float baseFreq = mFreq.value();
float *vpo = mVOct.buffer();

for (int i = 0; i < FRAMELENGTH; i += 4) {
  float32x4_t vOct = vld1q_f32(vpo + i);
  float32x4_t tune = simd::exp(vOct * vdupq_n_f32(FULLSCALE_IN_VOLTS * logf(2.0f)));
  float32x4_t freq = vmulq_f32(vdupq_n_f32(baseFreq), tune);
}
```

### Phase Accumulator Oscillator

```cpp
float mPhase = 0.0f;

void process() {
  float freq = mFreq.value();
  float phaseInc = freq * globalConfig.samplePeriod;

  for (int i = 0; i < FRAMELENGTH; i++) {
    out[i] = mPhase;  // Or apply waveshaping
    mPhase += phaseInc;
    if (mPhase >= 1.0f) mPhase -= 1.0f;
  }
}
```

### Slew Limiter / Envelope Follower

```cpp
float mValue = 0.0f;

void process() {
  float rise = mRise.value();  // seconds
  float fall = mFall.value();  // seconds

  float riseCoef = 1.0f / (rise * globalConfig.sampleRate + 1.0f);
  float fallCoef = 1.0f / (fall * globalConfig.sampleRate + 1.0f);

  for (int i = 0; i < FRAMELENGTH; i++) {
    float target = in[i];
    float coef = (target > mValue) ? riseCoef : fallCoef;
    mValue += (target - mValue) * coef;
    out[i] = mValue;
  }
}
```

### State Variable Filter

```cpp
#include <filter.h>

filter::svf::Coefficients mCoef;
filter::svf::State mState;

void process() {
  float cutoff = mCutoff.value();
  float res = mResonance.value();

  mCoef.update(cutoff, res, globalConfig.sampleRate);

  for (int i = 0; i < FRAMELENGTH; i++) {
    mState.process(mCoef, in[i]);
    lpOut[i] = mState.lp;
    bpOut[i] = mState.bp;
    hpOut[i] = mState.hp;
  }
}
```

---

## 11. Serialization

```lua
function MyUnit:serialize()
  local t = Unit.serialize(self)

  -- Save custom state
  t.customValue = self.customValue
  t.dspState = self.objects.op:getState()

  return t
end

function MyUnit:deserialize(t)
  Unit.deserialize(self, t)

  -- Restore custom state
  if t.customValue then
    self.customValue = t.customValue
  end
  if t.dspState then
    self.objects.op:setState(t.dspState)
  end
end
```

---

## 12. Complete Minimal Example

### And.h

```cpp
#pragma once
#include <od/objects/Object.h>
#include <hal/simd.h>

namespace lojik {
  class And : public od::Object {
    public:
      And() {
        addInput(mIn);
        addInput(mGate);
        addOutput(mOut);
        addOption(mSense);
      }

#ifndef SWIGLUA
      virtual void process();

      od::Inlet  mIn   { "In" };
      od::Inlet  mGate { "Gate" };
      od::Outlet mOut  { "Out" };
      od::Option mSense { "Sense", 0 };
#endif
  };
}
```

### And.cpp

```cpp
#include <And.h>

namespace lojik {
  void And::process() {
    float *in   = mIn.buffer();
    float *gate = mGate.buffer();
    float *out  = mOut.buffer();

    float sense = mSense.value() == 1 ? 0.1f : 0.0f;

    for (int i = 0; i < FRAMELENGTH; i += 4) {
      uint32x4_t inHigh   = vcgtq_f32(vld1q_f32(in + i), vdupq_n_f32(sense));
      uint32x4_t gateHigh = vcgtq_f32(vld1q_f32(gate + i), vdupq_n_f32(sense));
      uint32x4_t result   = vandq_u32(inHigh, gateHigh);
      vst1q_f32(out + i, vcvtq_n_f32_u32(result, 32));
    }
  }
}
```

### lojik.cpp.swig

```cpp
%module lojik_liblojik
%include <od/glue/mod.cpp.swig>

%{
#undef SWIGLUA
#include <And.h>
#define SWIGLUA
%}

%include <And.h>
```

### assets/Logic/And.lua

```lua
local app = app
local lojik = require "lojik.liblojik"
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Gate = require "Unit.ViewControl.Gate"

local And = Class {}
And:include(Unit)

function And:init(args)
  args.title = "And"
  args.mnemonic = "&&"
  Unit.init(self, args)
end

function And:onLoadGraph(channelCount)
  local gate = self:addComparatorControl("gate", app.COMPARATOR_GATE)
  local op = self:addObject("op", lojik.And())

  connect(self, "In1", op, "In")
  connect(gate, "Out", op, "Gate")

  for i = 1, channelCount do
    connect(op, "Out", self, "Out" .. i)
  end
end

function And:onLoadViews()
  return {
    gate = Gate {
      button      = "gate",
      description = "Gate",
      branch      = self.branches.gate,
      comparator  = self.objects.gate
    }
  }, {
    expanded  = { "gate" },
    collapsed = {}
  }
end

return And
```

### assets/toc.lua

```lua
return {
  name    = "lojik",
  title   = "Lojik",
  keyword = "lojik",
  contact = "author@example.com",
  author  = "Author",
  units   = {
    {
      title      = "And",
      moduleName = "Logic.And",
      keywords   = "and, logic, gate"
    }
  }
}
```

### mod.mk

```makefile
PKGVERSION = 1.0.0
include scripts/mod-builder.mk
```
