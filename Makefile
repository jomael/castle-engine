# Most useful targets:
#
#   all (default target) --
#     Compile all units
#   any subdirectory name, like base or 3dgraph --
#     Compile all units inside that subdirectory (and all used units
#     in other directories)
#
#   info --
#     Some information about what this Makefile sees, how will it work etc.
#
#   examples --
#     Compile all examples and tools (things inside examples/ and tools/
#     subdirectories). Note that you can also compile each example separately,
#     just run appropriate xxx_compile.sh scripts.
#
#   clean --
#     Delete FPC 1.0.x Windows trash (*.ppw, *.ow), FPC trash, Delphi trash,
#     Lazarus trash (*.compiled),
#     binaries of example programs,
#     also FPC compiled trash in packages/*/lib/,
#     and finally pasdoc generated documentation in doc/pasdoc/
#
# Not-so-commonly-useful targets:
#
#   container_units --
#     Create special container All*Units.pas units in all subdirectories.
#     Note that regenerating these units is not so easy -- you'll
#     need Emacs and my kambi-pascal-functions.el Elisp
#     code to do it (available inside SVN repository,
#     see http://michalis.ii.uni.wroc.pl/).
#
#   cleanmore --
#     Same as clean + delete Emacs backup files (*~) and Delphi backup files
#     (*.~??? (using *.~* would be too unsafe ?))
#
#   clean_container_units --
#     Cleans special units All*Units.pas.
#     This may be uneasy to undo, look at comments at container_units.
#
#   cleanall --
#     Same as cleanmore + clean_container_units.
#     This target should not be called unless you know
#     that you really want to get rid of ALL files that can be automatically
#     regenerated. Note that some of the files deleted by this target may
#     be not easy to regenerate -- see comments at container_units.
#
# Internal notes (not important if you do not want to read/modify
# this Makefile):
#
# Note: In many places in this Makefile I'm writing some special code
# to not descend to 'private' and 'old' subdirectories.
# This is something that is usable only for me (Michalis),
# if you're trying to understand this Makefile you can just ignore
# such things (you may be sure that I will never have here directory
# called 'private' or 'old').
#
# This Makefile must be updated when adding new subdirectory to my units.
# To add new subdirectory foo, add rules
# 1. rule 'foo' to compile everything in foo
# 2. rule to recreate file foo/allkambifoounits.pas
# 3. add to $(ALL_CONTAINER_UNITS) to delete on clean_container_units

# compiling ------------------------------------------------------------

.PHONY: all

UNITS_SUBDIRECTORIES := $(shell \
  find * -maxdepth 0 -type d \
    '(' -not -name 'private' ')' '(' -not -name 'old' ')' \
    '(' -not -name 'packages' ')' '(' -not -name 'doc' ')' \
    -print)

all: $(UNITS_SUBDIRECTORIES)

# compiling rules for each subdirectory

.PHONY: $(UNITS_SUBDIRECTORIES)

COMPILE_ALL_DIR_UNITS=fpc -dRELEASE @kambi.cfg $<

3dgraph: 3dgraph/allkambi3dgraphunits.pas
	$(COMPILE_ALL_DIR_UNITS)

3dmodels.gl: 3dmodels.gl/allkambi3dmodelsglunits.pas
	$(COMPILE_ALL_DIR_UNITS)

3dmodels: 3dmodels/allkambi3dmodelsunits.pas
	$(COMPILE_ALL_DIR_UNITS)

audio: audio/allkambiaudiounits.pas
	$(COMPILE_ALL_DIR_UNITS)

base: base/allkambibaseunits.pas
	$(COMPILE_ALL_DIR_UNITS)

fonts: fonts/allkambifontsunits.pas
	$(COMPILE_ALL_DIR_UNITS)

images: images/allkambiimagesunits.pas
	$(COMPILE_ALL_DIR_UNITS)

opengl: opengl/allkambiopenglunits.pas
	$(COMPILE_ALL_DIR_UNITS)

# creating All*Units.pas files ----------------------------------------

.PHONY: container_units clean_container_units

EMACS_BATCH := emacs -batch --eval="(require 'kambi-pascal-functions)"

ALL_CONTAINER_UNITS := 3dgraph/allkambi3dgraphunits.pas \
  3dmodels.gl/allkambi3dmodelsglunits.pas \
  3dmodels/allkambi3dmodelsunits.pas \
  audio/allkambiaudiounits.pas \
  base/allkambibaseunits.pas \
  fonts/allkambifontsunits.pas \
  images/allkambiimagesunits.pas \
  opengl/allkambiopenglunits.pas

# This is a nice target to call before doing a distribution of my sources,
# because I always want to distribute these All*Units.pas units.
# (so noone except me should ever need to run emacs to generate them)
container_units: $(ALL_CONTAINER_UNITS)

clean_container_units:
	rm -f $(ALL_CONTAINER_UNITS)

3dgraph/allkambi3dgraphunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"3dgraph/\" \"AllKambi3dGraphUnits\") \
  (save-buffer))"

3dmodels.gl/allkambi3dmodelsglunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"3dmodels.gl/\" \"AllKambi3dModelsGLUnits\") \
  (save-buffer))"

3dmodels/allkambi3dmodelsunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"3dmodels/\" \"AllKambi3dModelsUnits\") \
  (save-buffer))"

audio/allkambiaudiounits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"audio/\" \"AllKambiAudioUnits\") \
  (save-buffer))"

base/allkambibaseunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"base/\" \"AllKambiBaseUnits\") \
  (save-buffer))"

# FIXME: kam-simple-replace-buffer here is dirty hack to correct problems
# with all-units-in-dir
fonts/allkambifontsunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"fonts/\" \"AllKambiFontsUnits\") \
  (kam-simple-replace-buffer \"ttfontstypes,\" \"ttfontstypes {\$$ifdef MSWINDOWS}, {\$$endif}\") \
  (save-buffer))"

images/allkambiimagesunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"images/\" \"AllKambiImagesUnits\") \
  (save-buffer))"

opengl/allkambiopenglunits.pas:
	$(EMACS_BATCH) --eval="(progn \
  (write-unit-all-units-in-dir \"opengl/\" \"AllKambiOpenGLUnits\") \
  (save-buffer))"

# examples and tools -----------------------------------------------------------

EXAMPLES_BASE_NAMES := \
  audio/examples/algets \
  audio/examples/alplay \
  base/examples/demo_parseparameters \
  base/examples/demo_textreader \
  base/examples/test_platform_specific_utils \
  base/examples/kambi_calc \
  images/examples/image_convert \
  images/tools/image_to_pas \
  opengl/examples/gl_win_events \
  opengl/examples/menu_test_alternative \
  opengl/examples/menu_test \
  opengl/examples/test_glwindow_gtk_mix \
  opengl/examples/test_font_break \
  opengl/examples/multi_glwindow \
  opengl/examples/multi_texturing_demo \
  opengl/examples/shading_langs/shading_langs_demo \
  opengl/examples/demo_matrix_navigation \
  opengl/examples/fog_coord \
  3dgraph/examples/draw_space_filling_curve \
  3dmodels/examples/many2vrml \
  3dmodels/examples/test_blender_exported_hierarchy \
  3dmodels/tools/gen_light_map \
  3dmodels/tools/md3tovrmlsequence \
  3dmodels.gl/examples/simple_view_model_2 \
  3dmodels.gl/examples/simple_view_model \
  3dmodels.gl/examples/demo_animation \
  3dmodels.gl/examples/fog_culling \
  3dmodels.gl/examples/shadow_volume_test/shadow_volume_test \
  3dmodels.gl/examples/bump_mapping/bump_mapping \
  3dmodels.gl/examples/plane_mirror_and_shadow

EXAMPLES_UNIX_EXECUTABLES := $(EXAMPLES_BASE_NAMES) \
  audio/examples/test_al_source_allocator \
  3dmodels.gl/examples/view3dscene_mini_by_lazarus/view3dscene_mini_by_lazarus

EXAMPLES_WINDOWS_EXECUTABLES := $(addsuffix .exe,$(EXAMPLES_BASE_NAMES)) \
  audio/examples/test_al_source_allocator.exe \
  3dmodels.gl/examples/view3dscene_mini_by_lazarus/view3dscene_mini_by_lazarus.exe

.PHONY: examples
examples:
	$(foreach NAME,$(EXAMPLES_BASE_NAMES),$(NAME)_compile.sh && ) true

.PHONY: cleanexamples
cleanexamples:
	rm -f $(EXAMPLES_UNIX_EXECUTABLES) $(EXAMPLES_WINDOWS_EXECUTABLES)

# information ------------------------------------------------------------

.PHONY: info

info:
	@echo "All available units subdirectories (they are also targets"
	@echo "for this Makefile):"
	@echo $(UNITS_SUBDIRECTORIES)

check_is_gpl_licensed:
	find . '(' -type d -name '.svn' -prune ')' -or \
	       '(' -type f '(' -iname '*.pas' -or -iname '*.pasprogram' ')' \
	           -exec check_is_gpl_licensed '{}' ';' ')'

# cleaning ------------------------------------------------------------

.PHONY: clean cleanmore cleanall

clean: cleanexamples
	find . -type f '(' -iname '*.ow'  -or -iname '*.ppw' -or -iname '*.aw' -or \
	                   -iname '*.o'   -or -iname '*.ppu' -or -iname '*.a' -or \
			   -iname '*.compiled' -or \
	                   -iname '*.dcu' -or -iname '*.dpu' ')' \
	     -print \
	     | xargs rm -f
	rm -Rf packages/unix/lib/ packages/unix/kambi_units.pas \
	  packages/unix/kambi_glwindow.pas \
	  packages/unix/kambi_glwindow_navigated.pas \
	  packages/windows/lib/ packages/windows/kambi_units.pas \
	  packages/components/lib/ packages/components/kambi_components.pas \
	  tests/test_kambi_units tests/test_kambi_units.exe
	$(MAKE) -C doc/pasdoc/ clean

cleanmore: clean
	find . -type f '(' -iname '*~' -or \
	                   -iname '*.bak' -or \
	                   -iname '*.~???' -or \
			   -iname '*.blend1' \
			')' -exec rm -f '{}' ';'

cleanall: cleanmore clean_container_units

# eof ------------------------------------------------------------
