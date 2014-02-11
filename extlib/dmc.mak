DMC = dmc
CFLAGS = -p -c
LIBNAME = lua5.1.lib
LIB = lib

OBJECTS = lapi.o lcode.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o \
		lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o \
		ltable.o ltm.o lundump.o lvm.o lzio.o \
		lauxlib.o lbaselib.o ldblib.o liolib.o lmathlib.o loslib.o \
		ltablib.o lstrlib.o loadlib.o linit.o

%.o: src/%.c
	$(DMC) $(CFLAGS) -o$@ $<

$(LIBNAME): $(OBJECTS)
	$(LIB) -c $@ $(OBJECTS)

clean:
	rm $(OBJECTS)
	rm lua5.1.lib

.PHONY: clean
