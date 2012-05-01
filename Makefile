SETTINGS ?= settings.ddoc
MODULES ?= modules.ddoc
ROOT ?= .
OUTPUT ?= docs
BOOTDOC ?= .

SOURCES = \
	example/example.d

all:
	dmd -c -op -o- -Dd$(OUTPUT) -I$(ROOT) $(SOURCES) $(BOOTDOC)/bootdoc.ddoc $(SETTINGS) $(MODULES)

