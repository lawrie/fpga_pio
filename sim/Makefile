VERILOG_FILES = ../src/pio.v ../src/machine.v ../src/decoder.v ../src/divider.v ../src/pc.v \
                ../src/scratch.v ../src/fifo.v ../src/isr.v ../src/osr.v
TB ?= tb

${TB}: *.v
	iverilog -o tb ${TB}.v ${VERILOG_FILES}

sim: ${TB}
	./tb

clean:
	rm tb

