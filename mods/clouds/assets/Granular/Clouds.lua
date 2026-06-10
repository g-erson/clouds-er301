local app = app
local clouds = require "clouds.libclouds"
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local GainBias = require "Unit.ViewControl.GainBias"
local Gate = require "Unit.ViewControl.Gate"
local Pitch = require "Unit.ViewControl.Pitch"

local Clouds = Class {}
Clouds:include(Unit)

function Clouds:init(args)
  args.title = "Clouds"
  args.mnemonic = "CL"
  Unit.init(self, args)
end

function Clouds:onLoadGraph(channelCount)
  -- Main DSP object
  local op = self:addObject("op", clouds.Clouds())

  -- Gate/Trigger controls
  local trigger = self:addObject("trigger", app.Comparator())
  trigger:setTriggerMode()
  local freeze = self:addObject("freeze", app.Comparator())
  freeze:setToggleMode()

  -- Parameter controls with GainBias and MinMax for range display
  local position = self:addObject("position", app.GainBias())
  local positionRange = self:addObject("positionRange", app.MinMax())
  local size = self:addObject("size", app.GainBias())
  local sizeRange = self:addObject("sizeRange", app.MinMax())
  local pitch = self:addObject("pitch", app.ConstantOffset())
  local pitchRange = self:addObject("pitchRange", app.MinMax())
  local density = self:addObject("density", app.GainBias())
  local densityRange = self:addObject("densityRange", app.MinMax())
  local texture = self:addObject("texture", app.GainBias())
  local textureRange = self:addObject("textureRange", app.MinMax())
  local drywet = self:addObject("drywet", app.GainBias())
  local drywetRange = self:addObject("drywetRange", app.MinMax())
  local inGain = self:addObject("inGain", app.GainBias())
  local inGainRange = self:addObject("inGainRange", app.MinMax())
  local stereo = self:addObject("stereo", app.GainBias())
  local stereoRange = self:addObject("stereoRange", app.MinMax())
  local feedback = self:addObject("feedback", app.GainBias())
  local feedbackRange = self:addObject("feedbackRange", app.MinMax())
  local reverb = self:addObject("reverb", app.GainBias())
  local reverbRange = self:addObject("reverbRange", app.MinMax())

  -- Wire trigger/freeze
  connect(trigger, "Out", op, "Trigger")
  connect(freeze, "Out", op, "Freeze")

  -- Wire parameters to MinMax for range display
  connect(position, "Out", positionRange, "In")
  connect(size, "Out", sizeRange, "In")
  connect(pitch, "Out", pitchRange, "In")
  connect(density, "Out", densityRange, "In")
  connect(texture, "Out", textureRange, "In")
  connect(drywet, "Out", drywetRange, "In")
  connect(inGain, "Out", inGainRange, "In")
  connect(stereo, "Out", stereoRange, "In")
  connect(feedback, "Out", feedbackRange, "In")
  connect(reverb, "Out", reverbRange, "In")

  -- Wire parameters to the Clouds object
  connect(position, "Out", op, "Position")
  connect(size, "Out", op, "Size")
  connect(pitch, "Out", op, "Pitch")
  connect(density, "Out", op, "Density")
  connect(texture, "Out", op, "Texture")
  connect(drywet, "Out", op, "Dry/Wet")
  connect(inGain, "Out", op, "In Gain")
  connect(stereo, "Out", op, "Stereo")
  connect(feedback, "Out", op, "Feedback")
  connect(reverb, "Out", op, "Reverb")

  -- Wire audio
  if channelCount == 1 then
    connect(self, "In1", op, "In1")
    connect(op, "Out1", self, "Out1")
  else
    connect(self, "In1", op, "In1")
    connect(self, "In2", op, "In2")
    connect(op, "Out1", self, "Out1")
    connect(op, "Out2", self, "Out2")
  end

  -- Create branches for modulation inputs
  self:addMonoBranch("trigger", trigger, "In", trigger, "Out")
  self:addMonoBranch("freeze", freeze, "In", freeze, "Out")
  self:addMonoBranch("position", position, "In", position, "Out")
  self:addMonoBranch("size", size, "In", size, "Out")
  self:addMonoBranch("pitch", pitch, "In", pitch, "Out")
  self:addMonoBranch("density", density, "In", density, "Out")
  self:addMonoBranch("texture", texture, "In", texture, "Out")
  self:addMonoBranch("drywet", drywet, "In", drywet, "Out")
  self:addMonoBranch("inGain", inGain, "In", inGain, "Out")
  self:addMonoBranch("stereo", stereo, "In", stereo, "Out")
  self:addMonoBranch("feedback", feedback, "In", feedback, "Out")
  self:addMonoBranch("reverb", reverb, "In", reverb, "Out")
end

local views = {
  expanded = {
    "trigger", "freeze",
    "position", "size", "pitch", "density", "texture",
    "drywet", "inGain", "stereo", "feedback", "reverb"
  },
  collapsed = {}
}

function Clouds:onLoadViews(objects, branches)
  local controls = {}

  -- Encoder maps
  local zeroToOne = Encoder.getMap("[0,1]")

  controls.trigger = Gate {
    button = "trig",
    description = "Trigger",
    branch = branches.trigger,
    comparator = objects.trigger
  }

  controls.freeze = Gate {
    button = "freeze",
    description = "Freeze",
    branch = branches.freeze,
    comparator = objects.freeze
  }

  controls.position = GainBias {
    button = "pos",
    description = "Position",
    branch = branches.position,
    gainbias = objects.position,
    range = objects.positionRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.size = GainBias {
    button = "size",
    description = "Grain Size",
    branch = branches.size,
    gainbias = objects.size,
    range = objects.sizeRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.pitch = Pitch {
    button = "pitch",
    description = "Pitch",
    branch = branches.pitch,
    offset = objects.pitch,
    range = objects.pitchRange
  }

  controls.density = GainBias {
    button = "dens",
    description = "Density",
    branch = branches.density,
    gainbias = objects.density,
    range = objects.densityRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.texture = GainBias {
    button = "tex",
    description = "Texture",
    branch = branches.texture,
    gainbias = objects.texture,
    range = objects.textureRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.drywet = GainBias {
    button = "mix",
    description = "Dry/Wet",
    branch = branches.drywet,
    gainbias = objects.drywet,
    range = objects.drywetRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.inGain = GainBias {
    button = "gain",
    description = "Input Gain",
    branch = branches.inGain,
    gainbias = objects.inGain,
    range = objects.inGainRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.stereo = GainBias {
    button = "st",
    description = "Stereo Spread",
    branch = branches.stereo,
    gainbias = objects.stereo,
    range = objects.stereoRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0
  }

  controls.feedback = GainBias {
    button = "fb",
    description = "Feedback",
    branch = branches.feedback,
    gainbias = objects.feedback,
    range = objects.feedbackRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0
  }

  controls.reverb = GainBias {
    button = "rvb",
    description = "Reverb",
    branch = branches.reverb,
    gainbias = objects.reverb,
    range = objects.reverbRange,
    biasMap = zeroToOne,
    biasUnits = app.unitNone,
    initialBias = 0
  }

  return controls, views
end

return Clouds
