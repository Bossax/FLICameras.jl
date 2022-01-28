#
# Makefile --
#
# Rules to build Julia deps.jl file.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

# The following macros should be overwritten.
ifeq ($(TAO_INCDIR),)
$(info *** TAO_INCDIR should be set with directory storing TAO header files)
TAO_INCDIR = /usr/local/include
endif
ifeq ($(TAO_LIBDIR),)
$(info *** TAO_LIBDIR should be set with directory storing TAO libraries)
TAO_LIBDIR = /usr/local/lib
endif

# This one is probably correct.
TAO_DLL = $(TAO_LIBDIR)/libtao.so

all: deps.jl

clean:
	rm -f *~ gendeps

distclean: clean
	rm -f deps.jl

deps.jl: gendeps
	rm -f "$@"
	./gendeps >"$@"
	chmod a-w "$@"

gendeps: gendeps.c $(TAO_INCDIR)/tao.h
	$(CC) -Wall -Werror -I$(TAO_INCDIR) -DTAO_DLL=\"$(TAO_DLL)\" $< -o $@
