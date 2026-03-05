# target `iacta` with command odin build src -debug -out:out/iacta

OUTPUT := ./out

SOURCES := $(wildcard src/*.odin)

all: $(OUTPUT)/iacta

clean:
	rm $(OUTPUT)/iacta

$(OUTPUT)/iacta: $(SOURCES)
	@mkdir -p $(OUTPUT)
	odin build src -debug -out:$(OUTPUT)/iacta

render: $(OUTPUT)/iacta
	$(OUTPUT)/iacta

.PHONY: all clean render
