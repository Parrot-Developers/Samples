EXEC_NAME=JumpingSumoPiloting #output filename

SDK_DIR=../../../../out/Unix-base/
IDIR=./
CFLAGS=-I$(IDIR) -I$(SDK_DIR)/staging/usr/include

OBJDIR=obj
LDIR = $(SDK_DIR)/final/usr/lib

EXTERNAL_LIB=-lncurses

LIBS=-L$(LDIR) -larsal -larcontroller -lardiscovery $(EXTERNAL_LIB) -Wl,-rpath=$(LDIR)
LIBS_DBG=-L$(LDIR) -larsal_dbg -larcontroller_dbg -lardiscovery_dbg $(EXTERNAL_LIB) -Wl,-rpath=$(LDIR)

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
	$(CC) -o $@ $^ $(CFLAGS) $(LIBS)

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
