CC      = gcc
CFLAGS  = -Wall -Winline -O3 -std=gnu99 --param inline-unit-growth=1000 --param max-inline-insns-single=1200
LDFLAGS = 
LIBS    = 
INCLUDE = -I ./src
SRC_DIR = ./src
OBJ_DIR = ./build
TARGET  = inpla
OBJS    = $(OBJ_DIR)/inpla.tab.c $(OBJ_DIR)/ast.o $(OBJ_DIR)/id_table.o $(OBJ_DIR)/name_table.o $(OBJ_DIR)/linenoise.o
DEPS	= $(SRC_DIR)/config.h

#MYOPTION = -DHAND_FIB -DHAND_FIB_INT  -DHAND_I_CONS -DHAND_IS_CONS -DHAND_Apnd_CONS -DHAND_Part_CONS -DHAND_Split_CONS -DHAND_MergeCC_CONS -DHAND_B_CONS -DHAND_DUP_S -DHAND_ADD_S -DHAND_ACK_S
#MYOPTION = -DHAND_Split_CONS -DHAND_MergeCC_CONS
#MYOPTION = -DHAND_Part_CONS

.PHONY: all

all: $(OBJ_DIR) $(TARGET) 

$(TARGET): $(OBJS) $(LIBS) $(DEPS)
	$(CC) $(CFLAGS) $(INCLUDE) $(MYOPTION) -o $@ $(OBJS) $(LDFLAGS) 

$(OBJ_DIR)/linenoise.o: $(SRC_DIR)/linenoise/linenoise.c
	@if [ ! -f $(SRC_DIR)/linenoise/linenoise.c.orig ]; then \
		patch --backup --version-control=simple --suffix=.orig $(SRC_DIR)/linenoise/linenoise.c $(SRC_DIR)/linenoise/linenoise-multiline.patch; \
	fi
	$(CC) $(CFLAGS) $(INCLUDE) -o $@ -c $< 


$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c 
	$(CC) $(CFLAGS) $(INCLUDE) -o $@ -c $< 

$(OBJ_DIR)/inpla.tab.c : $(SRC_DIR)/inpla.y $(OBJ_DIR)/lex.yy.c
	bison -o $@ $<

$(OBJ_DIR)/lex.yy.c : $(SRC_DIR)/lex.l
	flex -o $@ $^

$(OBJ_DIR):
	@if [ ! -d $(OBJ_DIR) ]; then \
		echo ";; mkdir $(OBJ_DIR)"; mkdir $(OBJ_DIR); \
	fi

clean:
	rm -f $(TARGET)* $(OBJ_DIR)/* *stackdump* *core*
	@if [ -f $(SRC_DIR)/linenoise/linenoise.c.orig ]; then \
		echo "mv -f $(SRC_DIR)/linenoise/linenoise.c.orig $(SRC_DIR)/linenoise/linenoise.c"; \
		mv -f $(SRC_DIR)/linenoise/linenoise.c.orig $(SRC_DIR)/linenoise/linenoise.c; \
	fi


thread: $(OBJS) $(LIBS)
	$(CC) $(CFLAGS) $(INCLUDE) $(MYOPTION) -DTHREAD -o $(TARGET) $(OBJS) $(LDFLAGS) -lpthread
