
BUILD_ORDER = \
	Bus \
	AMBA_TLM2 \
	AMBA_TLM3 \
	FPGA \
	GenC \
	COBS \

.PHONY: all
all: install

.PHONY: install clean full_clean
install clean full_clean:
	$(foreach dir, $(BUILD_ORDER), $(MAKE) -C $(dir) $@ &&) true

