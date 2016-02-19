MODEL ?= $(shell getconf LONG_BIT)
BUILD ?= debug
LUA ?= lua
LIB ?= static

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

ifneq ($(LIB), static)
	ifneq ($(LIB), shared)
		$(error Unknown library type: $(LIB))
	endif
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
	ifeq ($(LIB), static)
		LUAD_OUTPUT = lib/$(LUAD_NAME).a
	else
		LUAD_OUTPUT = lib/$(LUAD_NAME).so
	endif
endif

all: $(LUAD_OUTPUT)

clean:
	-rm -f lib/$(LUAD_NAME).o
	-rm -f lib/$(LUAD_NAME).a
	-rm -f $(wildcard lib/$(LUAD_NAME).so*)
	-rm -f $(wildcard lib/libluad*.deps)
	-rm -f $(wildcard lib/libluad*.json)
	-rm -f $(wildcard lib/luad.*.lst)
	-rm -f test/luad_unittest
	-rm -f test/luad_unittest.o
	-rm -f $(wildcard *.lst)

LUAD_DFLAGS = $(DFLAGS) -L-l$(LUA)

ifneq ($(BUILD), test)
	ifeq ($(LIB), static)
		LUAD_DFLAGS += -lib -X -Xf"lib/libluad.json" -deps="lib/libluad.deps"
	else
		LUAD_DFLAGS += -shared -fPIC -defaultlib=libphobos2.so -L-soname=$(LUAD_NAME).so.0 -X -Xf"lib/libluad.json" -deps="lib/libluad.deps"
	endif
else
	LUAD_DFLAGS += -version=luad_unittest_main
endif

lib/libluad.a: $(LUAD_SOURCES)
	if ! test -d lib; then mkdir lib; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);

lib/libluad-d.a: $(LUAD_SOURCES)
	if ! test -d lib; then mkdir lib; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);

lib/libluad.so lib/libluad-d.so: lib/$(LUAD_NAME).so.0
	ln -sf $(LUAD_NAME).so.0 $@

lib/libluad.so.0 lib/libluad-d.so.0: lib/$(LUAD_NAME).so.0.0.0
	ln -sf $(LUAD_NAME).so.0.0.0 $@

lib/libluad.so.0.0.0 lib/libluad-d.so.0.0.0: $(LUAD_SOURCES)
	if ! test -d lib; then mkdir lib; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);

test/luad_unittest: $(LUAD_SOURCES)
	if ! test -d test; then mkdir test; fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);
	gdb --command=luad.gdb test/luad_unittest;

LUAD_SOURCES = \
	luad/all.d \
	luad/base.d \
	luad/dynamic.d \
	luad/error.d \
	luad/lfunction.d \
	luad/lmodule.d \
	luad/stack.d \
	luad/state.d \
	luad/table.d \
	luad/testing.d \
	luad/c/all.d \
	luad/c/lauxlib.d \
	luad/c/lua.d \
	luad/c/luaconf.d \
	luad/c/lualib.d \
	luad/c/tostring.d \
	luad/conversions/arrays.d \
	luad/conversions/assocarrays.d \
	luad/conversions/classes.d \
	luad/conversions/functions.d \
	luad/conversions/structs.d \
	luad/conversions/variant.d
