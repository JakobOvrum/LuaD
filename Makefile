SETTINGS ?= settings.ddoc
MODULES ?= modules.ddoc
ROOT ?= ..
OUTPUT ?= .
BOOTDOC ?= bootDoc

SOURCES = \
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

all:
	dmd -c -op -o- -Dd$(OUTPUT) -I$(ROOT) $(SOURCES) $(BOOTDOC)/bootdoc.ddoc $(SETTINGS) $(MODULES)

