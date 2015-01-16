EXEC_NAME=JumpingSumoChangePosture #output filename

SDK_DIR=../../../ARSDKBuildUtils
IDIR=./
CC=gcc
CFLAGS=-I$(IDIR) -I $(SDK_DIR)/Targets/Unix/Install/include

OBJDIR=obj
LDIR = $(SDK_DIR)/Targets/Unix/Install/lib

LIBS=-L$(SDK_DIR)/Targets/Unix/Install/lib -larsal -larcommands -larnetwork -larnetworkal -lardiscovery
LIBS_DBG=-L$(SDK_DIR)/Targets/Unix/Install/lib -larsal_dbg -larcommands_dbg -larnetwork_dbg -larnetworkal_dbg -lardiscovery_dbg

_DEPS = JumpingSumoChangePosture.h
DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = JumpingSumoChangePosture.o
OBJ = $(patsubst %,$(OBJDIR)/%,$(_OBJ))

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

run:
	LD_LIBRARY_PATH=$(LDIR) ./$(EXEC_NAME)
