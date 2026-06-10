# Clouds for ER-301 - Top level Makefile

PROJECTS = clouds

docker_image = tomjfiset/er-301-am335x-build-env:1.1.2

# Paths for Docker mounts (sibling directories)
ER301_PATH ?= $(realpath ../er-301-custom-units)
MI_PATH ?= $(realpath ../mi-eurorack)

all: $(PROJECTS)

$(PROJECTS):
	+$(MAKE) -j -f mods/$@/mod.mk PKGNAME=$@

$(addsuffix -install,$(PROJECTS)):
	$(eval PROJECT := $(@:-install=))
	+$(MAKE) -f mods/$(PROJECT)/mod.mk install PKGNAME=$(PROJECT)

$(addsuffix -clean,$(PROJECTS)):
	$(eval PROJECT := $(@:-clean=))
	+$(MAKE) -f mods/$(PROJECT)/mod.mk clean PKGNAME=$(PROJECT)

emu:
	@cd er-301; make -j emu && testing/darwin/emu/emu.elf

# Docker-based builds for AM335x (real ER-301 hardware)
# Mounts er-301 and mi-eurorack at /workspace paths
# Creates symlinks inside container since host symlinks don't work across mount points
release:
	docker run --rm --platform linux/amd64 \
		-v `pwd`:/workspace/clouds-er301 \
		-v $(ER301_PATH):/workspace/er-301-custom-units \
		-v $(MI_PATH):/workspace/mi-eurorack \
		-w /workspace/clouds-er301 \
		$(docker_image) \
		bash -c "\
			rm -f scripts er-301 mi && \
			ln -s /workspace/er-301-custom-units/scripts scripts && \
			ln -s /workspace/er-301-custom-units/er-301 er-301 && \
			ln -s /workspace/mi-eurorack mi && \
			make -j all ARCH=am335x PROFILE=release MI_PATH=/workspace/mi-eurorack \
		"

testing:
	docker run --rm --platform linux/amd64 \
		-v `pwd`:/workspace/clouds-er301 \
		-v $(ER301_PATH):/workspace/er-301-custom-units \
		-v $(MI_PATH):/workspace/mi-eurorack \
		-w /workspace/clouds-er301 \
		$(docker_image) \
		bash -c "\
			rm -f scripts er-301 mi && \
			ln -s /workspace/er-301-custom-units/scripts scripts && \
			ln -s /workspace/er-301-custom-units/er-301 er-301 && \
			ln -s /workspace/mi-eurorack mi && \
			make -j 4 all ARCH=am335x PROFILE=testing MI_PATH=/workspace/mi-eurorack \
		"

clean:
	rm -rf testing debug release

.PHONY: all clean $(PROJECTS) $(addsuffix -install,$(PROJECTS)) $(addsuffix -clean,$(PROJECTS)) emu release testing
