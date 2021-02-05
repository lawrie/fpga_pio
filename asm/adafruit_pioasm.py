# SPDX-FileCopyrightText: Copyright (c) 2021 Scott Shawcroft for Adafruit Industries LLC
#
# SPDX-License-Identifier: MIT
"""
`adafruit_pioasm`
================================================================================

Simple assembler to convert pioasm to bytes


* Author(s): Scott Shawcroft
"""

import array

__version__ = "0.0.0-auto.0"
__repo__ = "https://github.com/adafruit/Adafruit_CircuitPython_PIOASM.git"

CONDITIONS = ["", "!x", "x--", "!y", "y--", "x!=y", "pin", "!osre"]
IN_SOURCES = ["pins", "x", "y", "null", None, None, "isr", "osr"]
OUT_DESTINATIONS = ["pins", "x", "y", "null", "pindirs", "pc", "isr", "exec"]
WAIT_SOURCES = ["gpio", "pin", "irq", None]
MOV_DESTINATIONS = ["pins", "x", "y", None, "exec", "pc", "isr", "osr"]
MOV_SOURCES = ["pins", "x", "y", "null", None, "status", "isr", "osr"]
MOV_OPS = [None, "~", "::", None]
SET_DESTINATIONS = ["pins", "x", "y", None, "pindirs", None, None, None]

def assemble(text_program):
    """Converts pioasm text to encoded instruction bytes"""
    assembled = []
    program_name = None
    labels = {}
    instructions = []
    sideset_count = 0
    for line in text_program.split("\n"):
        line = line.strip()
        if not line:
            continue
        if ";" in line:
            line = line.split(";")[0].strip()
        if line.startswith(".program"):
            if program_name:
                raise RuntimeError("Multiple programs not supported")
            program_name = line.split()[1]
        elif line.startswith(".wrap_target"):
            if len(instructions) > 0:
                raise RuntimeError("wrap_target not supported")
        elif line.startswith(".wrap"):
            pass
        elif line.startswith(".side_set"):
            sideset_count = int(line.split()[1])
        elif line.endswith(":"):
            labels[line[:-1]] = len(instructions)
        else:
            instructions.append(line)

    max_delay = 2 ** (5 - sideset_count) - 1
    assembled = []
    for instruction in instructions:
        print(instruction)
        instruction = instruction.split()
        delay = 0
        if instruction[-1].endswith("]"): # Delay
            delay = int(instruction[-1].strip("[]"))
            if delay > max_delay:
                raise RuntimeError("Delay too long:", delay)
            instruction.pop()
        if len(instruction) > 1 and instruction[-2] == "side":
            sideset_value = int(instruction[-1])
            if sideset_value > 2 ** sideset_count:
                raise RuntimeError("Sideset value too large")
            delay |= sideset_value << (5 - sideset_count)
            instruction.pop()
            instruction.pop()

        if instruction[0] == "nop":
            #                  mov delay   y op   y
            assembled.append(0b101_00000_010_00_010)
        elif instruction[0] == "jmp":
            #                instr delay cnd addr
            assembled.append(0b000_00000_000_00000)
            if instruction[-1] in labels:
                assembled[-1] |= labels[instruction[-1]]
            else:
                assembled[-1] |= int(instruction[-1])

            if len(instruction) > 2:
                assembled[-1] |= CONDITIONS.index(instruction[1]) << 5

        elif instruction[0] == "wait":
            #                instr delay p sr index
            assembled.append(0b001_00000_0_00_00000)
            polarity = int(instruction[1])
            if not 0 <= polarity <= 1:
                raise RuntimeError("Invalid polarity")
            assembled[-1] |= polarity << 7
            assembled[-1] |= WAIT_SOURCES.index(instruction[2]) << 4
            num = int(instruction[3])
            if not 0 <= num <= 31:
                raise RuntimeError("Wait num out of range")
            assembled[-1] |= num
            if instruction[-1] == "rel":
                assembled[-1] |= 0x10 # Set the high bit of the irq value
        elif instruction[0] == "in":
            #                instr delay src count
            assembled.append(0b010_00000_000_00000)
            assembled[-1] |= IN_SOURCES.index(instruction[1]) << 5
            count = int(instruction[-1])
            if not 1 <= count <=32:
                raise RuntimeError("Count out of range")
            assembled[-1] |= (count & 0x1f) # 32 is 00000 so we mask the top
        elif instruction[0] == "out":
            #                instr delay dst count
            assembled.append(0b011_00000_000_00000)
            assembled[-1] |= OUT_DESTINATIONS.index(instruction[1]) << 5
            count = int(instruction[-1])
            if not 1 <= count <=32:
                raise RuntimeError("Count out of range")
            assembled[-1] |= (count & 0x1f) # 32 is 00000 so we mask the top
        elif instruction[0] == "push" or instruction[0] == "pull":
            #                instr delay d i b zero
            assembled.append(0b100_00000_0_0_0_00000)
            if instruction[0] == "pull":
                assembled[-1] |= 0x80
            if instruction[-1] == "block" or not instruction[-1].endswith("block"):
                assembled[-1] |= 0x20
            if instruction[1] in ("ifempty", "iffull"):
                assembled[-1] |= 0x40
        elif instruction[0] == "mov":
            #                instr delay dst op src
            assembled.append(0b101_00000_000_00_000)
            assembled[-1] |= MOV_DESTINATIONS.index(instruction[1]) << 5
            assembled[-1] |= MOV_SOURCES.index(instruction[-1])
            if len(instruction) > 3:
                assembled[-1] |= MOV_OPS.index(instruction[-2])
        elif instruction[0] == "irq":
            #                instr delay z c w index
            assembled.append(0b110_00000_0_0_0_00000)
            if instruction[-1] == "rel":
                assembled[-1] |= 0x10 # Set the high bit of the irq value
                instruction.pop()
            num = int(instruction[-1])
            if not 0 <= num <= 7:
                raise RuntimeError("Interrupt index out of range")
            assembled[-1] |= num
            if len(instruction) == 3: # after rel has been removed
                if instruction[1] == "wait":
                    assembled[-1] |= 0x20
                elif instruction[1] == "clear":
                    assembled[-1] |= 0x40
                # All other values are the default of set without waiting
        elif instruction[0] == "set":
            #                instr delay dst data
            assembled.append(0b111_00000_000_00000)
            assembled[-1] |= SET_DESTINATIONS.index(instruction[1]) << 5
            value = int(instruction[-1])
            if not 0 <= value <=31:
                raise RuntimeError("Set value out of range")
            assembled[-1] |= value
        else:
            raise RuntimeError("Unknown instruction:" + instruction)
        assembled[-1] |= delay << 8
        print(hex(assembled[-1]))

    return array.array("H", assembled)
