AS = nasm
ASFLAGS = -f macho64
LN = ld
LNFLAGS = -lSystem -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib

PROJECT = n2b

SRCDIR = .
TARGETDIR = build
OBJDIR = $(TARGETDIR)/obj
BINDIR = $(TARGETDIR)/bin

SRCFILES = $(wildcard $(SRCDIR)/*.asm)

OBJFILES = $(SRCFILES:$(SRCDIR)/%.asm=$(OBJDIR)/%.o)

EXEC = $(BINDIR)/$(PROJECT)

$(EXEC): $(OBJFILES)
	@mkdir -p $(BINDIR)
	$(LN) $(OBJFILES) $(LNFLAGS) -o $(EXEC)

$(OBJDIR)/%.o: $(SRCDIR)/%.asm
	@mkdir -p $(OBJDIR)
	$(AS) $< $(ASFLAGS) -o $@

build: $(EXEC)

run: $(EXEC)
	@./$(EXEC)

clean:
	rm -rf $(TARGETDIR)

.PHONY: build clean

all: $(EXEC)
