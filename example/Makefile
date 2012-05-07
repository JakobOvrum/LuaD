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
		$(error Unknown build mode: $(BUILD))
	endif
endif

ifeq ($(LUA), )
	$(error No Lua library set)
endif

DFLAGS = -w -wi -ignore -m$(MODEL) -I../ -L-L../lib -L-lluad -L-l$(LUA)

ifeq ($(BUILD), release)
	DFLAGS += -release -O -inline -noboundscheck
else
	DFLAGS += -debug -gc
endif

all: bin/hello bin/phonebook bin/precompiled

clean:
	rm -f bin/hello bin/hello.o
	rm -f bin/phonebook bin/phonebook.o
	rm -f bin/precompiled bin/precompiled.o

bin/hello: hello/hello.d
	dmd $(DFLAGS) -of$@ hello/hello.d

bin/phonebook: phonebook/phonebook.d
	dmd $(DFLAGS) -of$@ phonebook/phonebook.d 

bin/precompiled: precompiled/precompiled.d
	dmd $(DFLAGS) -of$@ precompiled/precompiled.d

