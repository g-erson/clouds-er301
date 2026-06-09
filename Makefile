# Clouds for ER-301 - Top level Makefile

PROJECTS = clouds

docker_image = tomjfiset/er-301-am335x-build-env:1.1.2

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

release:
	docker run -it -v `pwd`:/clouds-er301 -w /clouds-er301 $(docker_image) \
		make -j all ARCH=am335x PROFILE=release

testing:
	docker run -it -v `pwd`:/clouds-er301 -w /clouds-er301 --platform=linux/amd64 $(docker_image) \
		make -j 4 all ARCH=am335x PROFILE=testing

clean:
	rm -rf testing debug release

.PHONY: all clean $(PROJECTS) $(addsuffix -install,$(PROJECTS)) $(addsuffix -clean,$(PROJECTS)) emu release testing
