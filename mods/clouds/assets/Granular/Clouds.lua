local app = app
local clouds = require "clouds.libclouds"
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local GainBias = require "Unit.ViewControl.GainBias"
local Gate = require "Unit.ViewControl.Gate"
local Fader = require "Unit.ViewControl.Fader"
local OptionControl = require "Unit.ViewControl.OptionControl"

local Clouds = Class {}
Clouds:include(Unit)

function Clouds:init(args)
  args.title = "Clouds"
  args.mnemonic = "CL"
  Unit.init(self, args)
end

function Clouds:onLoadGraph(channelCount)
  local op = self:addObject("op", clouds.Clouds())

  -- Gate/Trigger controls
  local trigger = self:addComparatorControl("trigger", app.COMPARATOR_TRIGGER_ON_RISE)
  local freeze = self:addComparatorControl("freeze", app.COMPARATOR_GATE)

  -- Parameter controls
  local position = self:addGainBiasControl("position")
  local size = self:addGainBiasControl("size")
  local pitch = self:addGainBiasControl("pitch")
  local density = self:addGainBiasControl("density")
  local texture = self:addGainBiasControl("texture")
  local drywet = self:addGainBiasControl("drywet")
  local stereo = self:addGainBiasControl("stereo")
  local feedback = self:addGainBiasControl("feedback")
  local reverb = self:addGainBiasControl("reverb")

  -- Wire trigger/freeze
  connect(trigger, "Out", op, "Trigger")
  connect(freeze, "Out", op, "Freeze")

  -- Wire parameters
  tie(op, "Position", position, "Out")
  tie(op, "Size", size, "Out")
  tie(op, "Pitch", pitch, "Out")
  tie(op, "Density", density, "Out")
  tie(op, "Texture", texture, "Out")
  tie(op, "Dry/Wet", drywet, "Out")
  tie(op, "Stereo", stereo, "Out")
  tie(op, "Feedback", feedback, "Out")
  tie(op, "Reverb", reverb, "Out")

  -- Wire audio
  if channelCount == 1 then
    connect(self, "In1", op, "Left In")
    connect(self, "In1", op, "Right In")
    connect(op, "Left Out", self, "Out1")
  else
    connect(self, "In1", op, "Left In")
    connect(self, "In2", op, "Right In")
    connect(op, "Left Out", self, "Out1")
    connect(op, "Right Out", self, "Out2")
  end
end

function Clouds:onLoadViews()
  -- Encoder maps
  local unitMap = Encoder.getMap("unit")
  local pitchMap = app.LinearDialMap(-48, 48)
  pitchMap:setSteps(12, 1, 0.1, 0.01)

  return {
    trigger = Gate {
      button = "trig",
      description = "Trigger",
      branch = self.branches.trigger,
      comparator = self.objects.trigger
    },

    freeze = Gate {
      button = "fz",
      description = "Freeze",
      branch = self.branches.freeze,
      comparator = self.objects.freeze
    },

    position = GainBias {
      button = "pos",
      description = "Position",
      branch = self.branches.position,
      gainbias = self.objects.position,
      range = self.objects.positionRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0.5
    },

    size = GainBias {
      button = "size",
      description = "Grain Size",
      branch = self.branches.size,
      gainbias = self.objects.size,
      range = self.objects.sizeRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0.5
    },

    pitch = GainBias {
      button = "pitch",
      description = "Pitch",
      branch = self.branches.pitch,
      gainbias = self.objects.pitch,
      range = self.objects.pitchRange,
      biasMap = pitchMap,
      biasUnits = app.unitSemiTones,
      initialBias = 0
    },

    density = GainBias {
      button = "dens",
      description = "Density",
      branch = self.branches.density,
      gainbias = self.objects.density,
      range = self.objects.densityRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0.5
    },

    texture = GainBias {
      button = "tex",
      description = "Texture",
      branch = self.branches.texture,
      gainbias = self.objects.texture,
      range = self.objects.textureRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0.5
    },

    drywet = GainBias {
      button = "mix",
      description = "Dry/Wet",
      branch = self.branches.drywet,
      gainbias = self.objects.drywet,
      range = self.objects.drywetRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0.5
    },

    stereo = GainBias {
      button = "st",
      description = "Stereo Spread",
      branch = self.branches.stereo,
      gainbias = self.objects.stereo,
      range = self.objects.stereoRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0
    },

    feedback = GainBias {
      button = "fb",
      description = "Feedback",
      branch = self.branches.feedback,
      gainbias = self.objects.feedback,
      range = self.objects.feedbackRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0
    },

    reverb = GainBias {
      button = "rvb",
      description = "Reverb",
      branch = self.branches.reverb,
      gainbias = self.objects.reverb,
      range = self.objects.reverbRange,
      biasMap = unitMap,
      biasUnits = app.unitNone,
      initialBias = 0
    },

    mode = OptionControl {
      button = "mode",
      description = "Playback Mode",
      option = self.objects.op:getOption("Mode"),
      choices = { "granular", "stretch", "looping", "spectral" }
    },

    quality = OptionControl {
      button = "qual",
      description = "Quality",
      option = self.objects.op:getOption("Quality"),
      choices = { "16bit stereo", "16bit mono", "8bit stereo", "8bit mono" }
    }
  }, {
    expanded = { "trigger", "freeze", "position", "size", "pitch", "density", "texture" },
    collapsed = {}
  }
end

function Clouds:onShowMenu(objects)
  return {
    mode = objects.mode,
    quality = objects.quality
  }, { "mode", "quality" }
end

return Clouds
