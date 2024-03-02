
PROGRAM=micro68k
SOURCE= \
  src/$(PROGRAM).v \
  src/eeprom.v \
  src/mandelbrot.v \
  src/memory_bus.v \
  src/peripherals.v \
  src/ram.v \
  src/rom.v \
  src/spi.v

default:
	yosys -q -p "synth_ice40 -top $(PROGRAM) -json $(PROGRAM).json" $(SOURCE)
	nextpnr-ice40 -r --hx8k --json $(PROGRAM).json --package cb132 --asc $(PROGRAM).asc --opt-timing --pcf icefun.pcf
	icepack $(PROGRAM).asc $(PROGRAM).bin

program:
	iceFUNprog $(PROGRAM).bin

blink:
	naken_asm -l -type bin -o rom.bin test/blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

self_test:
	naken_asm -l -type bin -o rom.bin test/self_test.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

immediate:
	naken_asm -l -type bin -o rom.bin test/immediate.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

memory_read:
	naken_asm -l -type bin -o rom.bin test/memory_read.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

memory_write:
	naken_asm -l -type bin -o rom.bin test/memory_write.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

lea:
	naken_asm -l -type bin -o rom.bin test/lea.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

shift:
	naken_asm -l -type bin -o rom.bin test/shift.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

branch:
	naken_asm -l -type bin -o rom.bin test/branch.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

jump:
	naken_asm -l -type bin -o rom.bin test/jump.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

quick:
	naken_asm -l -type bin -o rom.bin test/quick.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

bitset:
	naken_asm -l -type bin -o rom.bin test/bitset.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

flags:
	naken_asm -l -type bin -o rom.bin test/flags.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

clean:
	@rm -f $(PROGRAM).bin $(PROGRAM).json $(PROGRAM).asc *.lst
	@rm -f blink.bin load_byte.bin store_byte.bin test_subroutine.bin
	@rm -f button.bin
	@echo "Clean!"

