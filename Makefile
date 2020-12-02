CFLAGS += -std=c99 -g -Wall
MAGIC_INCLUDE_DIR = $(MAGIC_DEP_DIR)/src
MAGIC_LIBDIR = $(MAGIC_DEP_DIR)/src/.libs
MAGIC_HEADER = $(MAGIC_INCLUDE_DIR)/magic.h
MAGIC_LIB = $(MAGIC_LIBDIR)/libmagic.so
CPPFLAGS += -I$(ERL_EI_INCLUDE_DIR) -I$(MAGIC_INCLUDE_DIR)
LDFLAGS += -L$(ERL_EI_LIBDIR) -L$(MAGIC_LIBDIR)
LDLIBS = -lpthread -lei -lm -lmagic
PRIV = priv/
RM = rm -Rf

ifeq ($(EI_INCOMPLETE),YES)
  LDLIBS += -lerl_interface
  CFLAGS += -DEI_INCOMPLETE
endif

all: priv/libmagic_port

priv/libmagic_port: src/libmagic_port.c $(MAGIC_HEADER) $(MAGIC_LIB)
	mkdir -p priv
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $< $(LDLIBS) -o $@

clean:
	$(RM) $(PRIV)

$(MAGIC_HEADER):
  $(NOECHO) $(NOOP)

$(MAGIC_LIB):
	$(NOECHO) $(NOOP)

.PHONY: clean
