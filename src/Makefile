VERILOG_FILES = pio.v machine.v decoder.v divider.v pc.v scratch.v fifo.v isr.v osr.v
TB ?= tb

tb: *.v
	iverilog -o tb ${TB}.v ${VERILOG_FILES}

sim: tb
	./tb

clean:
	rm tb

