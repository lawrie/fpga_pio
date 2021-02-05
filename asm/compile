#!/usr/bin/python3

from adafruit_pioasm import assemble
import sys

args=sys.argv

if len(args) < 3:
  print("Usage: " + args[0] + " <text program file> <hex program file>")
  sys.exit(1)

f=open(args[1],"r");
text = f.read();
f.close()

bin=assemble(text)

f=open(args[2],"w")

for i in bin:
  h = format(i,"04x")
  f.write(h + "\n")

f.close()





