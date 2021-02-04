VERILOG_FILES = pio.v machine.v decoder.v divider.v pc.v scratch.v fifo.v isr.v osr.v

tb: *.v
	iverilog -o tb tb.v ${VERILOG_FILES}

sim: tb
	./tb
