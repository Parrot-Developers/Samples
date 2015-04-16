EXEC_NAME=BebopDroneDecodeStream #output filename

SDK_DIR=../../../ARSDKBuildUtils
IDIR=./
CC=gcc
CFLAGS=-I$(IDIR) -I $(SDK_DIR)/Targets/Unix/Install/include -g

OBJDIR=obj
LDIR = $(SDK_DIR)/Targets/Unix/Install/lib

EXTERNAL_LIB=-lncurses -lavcodec -lavformat -lswscale -lavutil

LIBS=-L$(SDK_DIR)/Targets/Unix/Install/lib -larsal -larcommands -larnetwork -larnetworkal -lardiscovery -larstream $(EXTERNAL_LIB)
LIBS_DBG=-L$(SDK_DIR)/Targets/Unix/Install/lib -larsal_dbg -larcommands_dbg -larnetwork_dbg -larnetworkal_dbg -lardiscovery_dbg -larstream_dbg $(EXTERNAL_LIB)

_DEPS = BebopDroneDecodeStream.h DecoderManager.h ihm.h
DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = BebopDroneDecodeStream.o DecoderManager.o ihm.o
OBJ = $(patsubst %,$(OBJDIR)/%,$(_OBJ))

FIFO = video_decoded_fifo

all: $(EXEC_NAME)
	@[ -p $(FIFO) ] || mkfifo $(FIFO)

$(OBJDIR)/%.o: %.c $(DEPS)
	@ [ -d $(OBJDIR) ] || mkdir $(OBJDIR)
	@ $(CC) -c -o $@ $< $(CFLAGS)

$(EXEC_NAME): $(OBJ)
	@ gcc -o $@ $^ $(CFLAGS) $(LIBS)

.PHONY: clean

clean:
	@ rm -f $(OBJDIR)/*.o *~ core $(INCDIR)/*~
	@ rm -rf $(OBJDIR)
	@ rm -f $(FIFO)
	@ rm -f $(EXEC_NAME)

run:
	LD_LIBRARY_PATH=$(LDIR) ./$(EXEC_NAME)
