##########################################################################
# Copyright (c) 2009, 2010, 2011, 2012 ETH Zurich.
# All rights reserved.
#
# This file is distributed under the terms in the attached LICENSE file.
# If you do not find this file, copies can be found by writing to:
# ETH Zurich D-INFK, Haldeneggsteig 4, CH-8092 Zurich. Attn: Systems Group.
#
# This file defines symbolic (i.e. non-file) targets for the Makefile
# generated by Hake.  Edit this to add your own symbolic targets.
#
##########################################################################

# Disable built-in implicit rules. GNU make adds environment's MAKEFLAGS too.
MAKEFLAGS=r

# Set default architecture to the first specified by Hake in generated Makefile.
ARCH ?= $(word 1, $(HAKE_ARCHS))

all: $(MODULES) menu.lst
	@echo "You've just run the default ("all") target for Barrelfish"
	@echo "using Hake.  The following modules have been built:"
	@echo $(MODULES)
	@echo "If you want to change this target, edit the file called"
	@echo "'symbolic_targets.mk' in your build directory."
.PHONY: all

$(ARCH)/menu.lst: $(SRCDIR)/hake/menu.lst.$(ARCH)
	cp $< $@

# ARM GEM5 Simulation Targets

ARM_PREFIX=arm-linux-gnueabi-

menu.lst.arm_gem5: $(SRCDIR)/hake/menu.lst.arm_gem5
	cp $< $@

# Source indexing targets
cscope.files:
	find $(abspath .) $(abspath $(SRCDIR)) -name '*.[ch]' -type f -print | sort | uniq > $@
.PHONY: cscope.files

cscope.out: cscope.files
	cscope -k -b -i$<

TAGS: cscope.files
	etags - < $< # for emacs
	cat $< | xargs ctags -o TAGS_VI # for vim

# force rebuild of the Makefile
rehake: ./hake/hake
	./hake/hake --source-dir $(SRCDIR)
.PHONY: rehake

clean::
	$(RM) -r tools $(HAKE_ARCHS)
.PHONY: clean

realclean:: clean
	$(RM) hake/*.o hake/*.hi hake/hake Hakefiles.hs cscope.*
.PHONY: realclean

doxygen: Doxyfile
	doxygen $<
.PHONY: doxygen

# pretend to be CMake's CONFIGURE_FILE command
# TODO: clean this up
Doxyfile: $(SRCDIR)/doc/Doxyfile.cmake
	sed -r 's#@CMAKE_SOURCE_DIR@#$(SRCDIR)#g' $< > $@

#######################################################################
#
# Pandaboard builds
#
#######################################################################

PANDABOARD_MODULES=\
	arm_gem5/sbin/cpu_omap44xx 

menu.lst.pandaboard: $(SRCDIR)/hake/menu.lst.pandaboard
	cp $< $@

pandaboard_image: $(PANDABOARD_MODULES) \
		tools/bin/arm_molly \
		menu.lst.pandaboard
	# Translate each of the binary files we need
	$(SRCDIR)/tools/arm_molly/build_data_files.sh menu.lst.pandaboard molly_panda
	# Build a C file to link into a single image for the 2nd-stage
	# bootloader
	tools/bin/arm_molly menu.lst.pandaboard panda_mbi.c
	# Compile the complete boot image into a single executable
	$(ARM_PREFIX)gcc -std=c99 -g -fPIC -pie -Wl,-N -fno-builtin \
		-nostdlib -march=armv7-a -mapcs -fno-unwind-tables \
		-T$(SRCDIR)/tools/arm_molly/molly_ld_script \
		-I$(SRCDIR)/include \
		-I$(SRCDIR)/include/arch/arm \
		-I./arm_gem5/include \
		-I$(SRCDIR)/include/oldc \
		-I$(SRCDIR)/include/c \
		-imacros $(SRCDIR)/include/deputy/nodeputy.h \
		$(SRCDIR)/tools/arm_molly/molly_boot.S \
		$(SRCDIR)/tools/arm_molly/molly_init.c \
		$(SRCDIR)/tools/arm_molly/lib.c \
		./panda_mbi.c \
		$(SRCDIR)/lib/elf/elf32.c \
		./molly_panda/* \
		-o pandaboard_image
	@echo "OK - pandaboard boot image is built."
	@echo "If your boot environment is correctly set up, you can now:"
	@echo "$ usbboot ./pandaboard_image"
