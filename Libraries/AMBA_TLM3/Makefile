
BUILD_ORDER = \
	TLM3 \
	Ahb \
	Apb \
	Axi \
	Axi4 \

.PHONY: all
all: install

.PHONY: install clean full_clean
install clean full_clean:
	$(foreach dir, $(BUILD_ORDER), $(MAKE) -C $(dir) $@ &&) true

