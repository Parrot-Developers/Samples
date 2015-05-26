EXEC_NAME=JumpingSumoPiloting #output filename

SDK_DIR=../../../ARSDKBuildUtils
IDIR=./
CC=gcc
CFLAGS=-I$(IDIR) -I $(SDK_DIR)/Targets/Unix/Install/include

OBJDIR=obj
LDIR = $(SDK_DIR)/Targets/Unix/Install/lib

EXTERNAL_LIB=-lncurses

LIBS=-L$(SDK_DIR)/Targets/Unix/Install/lib -larsal -larcontroller -lardiscovery $(EXTERNAL_LIB)
LIBS_DBG=-L$(SDK_DIR)/Targets/Unix/Install/lib -larsal_dbg -larcontroller_dbg -lardiscovery_dbg $(EXTERNAL_LIB)

_DEPS = JumpingSumoPiloting.h ihm.h
DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = JumpingSumoPiloting.o ihm.o
OBJ = $(patsubst %,$(OBJDIR)/%,$(_OBJ))

FIFO = video_fifo.mjpg

all: $(EXEC_NAME)
	@[ -p $(FIFO) ] || mkfifo $(FIFO)

$(OBJDIR)/%.o: %.c $(DEPS)
	@ [ -d $(OBJDIR) ] || mkdir $(OBJDIR)
	@ $(CC) -c -o $@ $< $(CFLAGS)

$(EXEC_NAME): $(OBJ)
	gcc -o $@ $^ $(CFLAGS) $(LIBS)

.PHONY: clean

clean:
	@ rm -f $(OBJDIR)/*.o *~ core $(INCDIR)/*~
	@ rm -rf $(OBJDIR)
	@ rm -r $(EXEC_NAME)
	@ rm -f $(FIFO)

run:
	LD_LIBRARY_PATH=$(LDIR) ./$(EXEC_NAME)

valgrind:
	LD_LIBRARY_PATH=$(LDIR) valgrind ./$(EXEC_NAME)
