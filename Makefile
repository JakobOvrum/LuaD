MODEL ?= $(shell getconf LONG_BIT)
BUILD ?= debug
LUA ?= lua

ifneq ($(MODEL), 32)
	ifneq ($(MODEL), 64)
		$(error Unsupported architecture: $(MODEL))
	endif
endif

ifneq ($(BUILD), debug)
	ifneq ($(BUILD), release)
		ifneq ($(BUILD), test)
			$(error Unknown build mode: $(BUILD))
		endif
	endif
endif

ifeq ($(LUA), )
	$(error No Lua library set)
endif

DFLAGS = -w -wi -ignore -m$(MODEL)

ifeq ($(BUILD), release)
	DFLAGS += -release -O -inline -noboundscheck
else
	DFLAGS += -debug -gc

	ifeq ($(BUILD), test)
		DFLAGS += -unittest -cov
	endif
endif

ifeq ($(BUILD), test)
	LUAD_NAME = luad_unittest
	LUAD_OUTPUT = test/$(LUAD_NAME)
else
	ifeq ($(BUILD), debug)
		LUAD_NAME = libluad-d
	else
		LUAD_NAME = libluad
	endif
	LUAD_OUTPUT = lib/$(LUAD_NAME).a
endif

all: $(LUAD_OUTPUT)

clean:
	-rm -f lib/$(LUAD_NAME).o
	-rm -f lib/$(LUAD_NAME).a
	-rm -f lib/$(LUAD_NAME).deps
	-rm -f lib/$(LUAD_NAME).json
	-rm -f $(wildcard lib/luad.*.lst)
	-rm -f test/luad_unittest
	-rm -f test/luad_unittest.o
	-rm -f $(wildcard *.lst)

LUAD_DFLAGS = $(DFLAGS) -L-l$(LUA)

ifneq ($(BUILD), test)
	LUAD_DFLAGS += -lib -X -Xf"lib/libluad.json" -deps="lib/libluad.deps"
else
	LUAD_DFLAGS += -version=luad_unittest_main
endif

lib/libluad.a: $(LUAD_SOURCES)
	if ! test -d lib; then mkdir lib; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);

lib/libluad-d.a: $(LUAD_SOURCES)
	if ! test -d lib; then mkdir lib; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);

test/luad_unittest: $(LUAD_SOURCES)
	if ! test -d test; then mkdir test; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);
	gdb --command=luad.gdb test/luad_unittest;

LUAD_SOURCES = \
	source/app.d \
	source/luad/base.d \
	source/luad/dynamic.d \
	source/luad/error.d \
	source/luad/lfunction.d \
	source/luad/lmodule.d \
	source/luad/stack.d \
	source/luad/state.d \
	source/luad/table.d \
	source/luad/testing.d \
	source/luad/c/all.d \
	source/luad/c/lauxlib.d \
	source/luad/c/lua.d \
	source/luad/c/luaconf.d \
	source/luad/c/lualib.d \
	source/luad/c/tostring.d \
	source/luad/conversions/arrays.d \
	source/luad/conversions/assocarrays.d \
	source/luad/conversions/classes.d \
	source/luad/conversions/functions.d \
	source/luad/conversions/structs.d \
	source/luad/conversions/variant.d
