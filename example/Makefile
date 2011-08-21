MODEL ?= 64
BUILD ?= debug

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

DFLAGS = -w -wi -ignore -m$(MODEL) -I../ -L-L../lib -L-lluad -L-llua5.1

ifeq ($(BUILD), release)
	DFLAGS += -release -O -inline -noboundscheck
else
	DFLAGS += -debug -gc
endif

all: bin/hello bin/phonebook

clean:
	rm -f bin/hello bin/hello.o
	rm -f bin/phonebook bin/phonebook.o

bin/hello: hello/hello.d
	dmd $(DFLAGS) -of$@ hello/hello.d

bin/phonebook: phonebook/phonebook.d
	dmd $(DFLAGS) -of$@ phonebook/phonebook.d 
