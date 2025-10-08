

#./tests/complexity/mk/

.PHONY: all
all: build

X := base
Y := $(X)-layer
Z := $(Y)-deep



build: prep
	@echo $(Z)

prep:
	@true