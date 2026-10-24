#!/usr/bin/env python3
"""Calcula l'entropia de Shannon (bits/byte, de 0 a 8) de cada fitxer passat com a argument."""
import math
import sys
from collections import Counter

for path in sys.argv[1:]:
    data = open(path, "rb").read()
    if not data:
        print(f"{0:.6f}  {path}")
        continue
    n = len(data)
    h = -sum(c / n * math.log2(c / n) for c in Counter(data).values())
    print(f"{h:.6f}  {path}")
