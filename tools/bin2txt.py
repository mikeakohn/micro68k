#!/usr/bin/env python3

import sys

fp = open(sys.argv[1], "rb")

while True:
  b = fp.read(2)
  if not b: break
  print("%02x%02x" % (b[0], b[1]))

fp.close()

