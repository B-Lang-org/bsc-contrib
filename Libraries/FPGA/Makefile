
BUILD_ORDER = \
	Misc \
	DDR2 \
	Altera \
	Xilinx \

.PHONY: all
all: install

.PHONY: install clean full_clean
install clean full_clean:
	$(foreach dir, $(BUILD_ORDER), $(MAKE) -C $(dir) $@ &&) true

