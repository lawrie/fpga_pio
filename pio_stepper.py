import time
import rp2
from machine import Pin

@rp2.asm_pio(out_init=(rp2.PIO.OUT_LOW,rp2.PIO.OUT_LOW,rp2.PIO.OUT_LOW,rp2.PIO.OUT_LOW))
def stepper():
    pull()
    mov(isr, osr)
    pull()
    mov(y, isr)
    label("outer")
    mov(osr, isr)
    set(x, 6)
    label("inner")
    out(pins, 4) [1]
    jmp(x_dec, "inner")
    out(pins, 4)
    jmp(y_dec, "outer")
    wrap_target()
    out(pins, 4)
    wrap()

# Instantiate a state machine with the stepper program, at 2000Hz.
forward = 0b10001100010001100010001100011001

sm = rp2.StateMachine(0, stepper, freq=2000, out_base=Pin(16))

# Run the state machine
sm.active(1)
# Set the direction to forwards
sm.put(forward)
# Set the count of half steps to 1 million
sm.put(1000000)
