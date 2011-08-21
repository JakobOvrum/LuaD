MODEL ?= 64
BUILD ?= debug

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

DFLAGS = -v -w -wi -ignore -X -m$(MODEL)

ifeq ($(BUILD), release)
	DFLAGS += -release -O -inline -noboundscheck -profile
else
	DFLAGS += -debug -gc

	ifeq ($(BUILD), test)
		DFLAGS += -unittest -cov
	endif
endif

all: lib/libluad.a

clean:
	-rm -f lib/libluad.o
	-rm -f lib/libluad.a
	-rm -f lib/libluad.deps
	-rm -f lib/libluad.json
	-rm -f lib/luad.*.lst

LUAD_DFLAGS = $(DFLAGS)
LUAD_DFLAGS += -Xf"lib/libluad.json" -deps="lib/libluad.deps" -L-llua

ifneq ($(BUILD), test)
	LUAD_DFLAGS += -lib
else
	LUAD_DFLAGS += -version=luad_unittest_main
endif

lib/libluad.a: $(LUAD_SOURCES)
	if [ ! -d lib ]; then \
		mkdir lib; \
	fi
	dmd $(LUAD_DFLAGS) -of$@ $(LUAD_SOURCES);
	if [ ${BUILD} = "test" ]; then \
		gdb --command=luad.gdb lib/libluad.a; \
	fi

LUAD_SOURCES = \
	luad/all.d \
	luad/base.d \
	luad/dynamic.d \
	luad/error.d \
	luad/lfunction.d \
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
