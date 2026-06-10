PKGVERSION = 0.1.0

# Path to MI eurorack code
MI_PATH = $(HOME)/projects/mi-eurorack

include scripts/mod-builder.mk

# Define TEST to avoid STM32 dependencies (must be after include since mod-builder.mk resets SYMBOLS)
CFLAGS += -DTEST

# Add MI includes AFTER including mod-builder.mk since it overwrites INCLUDES
CFLAGS += -I$(MI_PATH) -I$(MI_PATH)/stmlib

# Override compiler for Apple Silicon M1+ compatibility (gcc-11 doesn't support apple-m1 arch)
ifeq ($(ARCH),darwin)
  CC := gcc-14 -fdiagnostics-color -fmax-errors=5
  CPP := g++-14 -fdiagnostics-color -fmax-errors=5
  AR := gcc-ar-14
  # gcc-14 uses -shared, not Apple's -dynamic flags
  LFLAGS = -shared -undefined dynamic_lookup
endif

# MI source files - we put objects in $(OUT_DIR)/mi/
MI_OBJ_DIR = $(OUT_DIR)/mi
MI_CC_OBJECTS = \
	$(MI_OBJ_DIR)/granular_processor.o \
	$(MI_OBJ_DIR)/correlator.o \
	$(MI_OBJ_DIR)/mu_law.o \
	$(MI_OBJ_DIR)/phase_vocoder.o \
	$(MI_OBJ_DIR)/stft.o \
	$(MI_OBJ_DIR)/frame_transformation.o \
	$(MI_OBJ_DIR)/resources.o \
	$(MI_OBJ_DIR)/units.o \
	$(MI_OBJ_DIR)/random.o \
	$(MI_OBJ_DIR)/atan.o

# Add MI objects to the link - we override the lib file rule
$(LIB_FILE): $(MI_CC_OBJECTS)

# Compilation rules for MI source files
$(MI_OBJ_DIR)/granular_processor.o: $(MI_PATH)/clouds/dsp/granular_processor.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/correlator.o: $(MI_PATH)/clouds/dsp/correlator.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/mu_law.o: $(MI_PATH)/clouds/dsp/mu_law.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/phase_vocoder.o: $(MI_PATH)/clouds/dsp/pvoc/phase_vocoder.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/stft.o: $(MI_PATH)/clouds/dsp/pvoc/stft.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/frame_transformation.o: $(MI_PATH)/clouds/dsp/pvoc/frame_transformation.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/resources.o: $(MI_PATH)/clouds/resources.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/units.o: $(MI_PATH)/stmlib/dsp/units.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/random.o: $(MI_PATH)/stmlib/utils/random.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

$(MI_OBJ_DIR)/atan.o: $(MI_PATH)/stmlib/dsp/atan.cc
	@echo [C++ MI $<]
	@mkdir -p $(@D)
	@$(CPP) $(CFLAGS) -std=gnu++11 -c $< -o $@

# Override the LIB_FILE recipe to include MI objects
$(LIB_FILE): $(OBJECTS) $(MI_CC_OBJECTS)
	@echo [LINK $@]
	@$(CC) $(CFLAGS) -o $@ $(OBJECTS) $(MI_CC_OBJECTS) $(LFLAGS)
