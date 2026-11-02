#!/usr/bin/env python3
"""Reproduce the ASCII advance tables in LeftoversPillFit.swift.

Uses the system FreeType shared library, no Python packages. Run from repo root.
FT_LOAD_NO_SCALE returns unhinted font units; variable wght is set in design units.
The shipped Figtree has one axis (wght) and 1000 units per em.
"""
import ctypes as c
import hashlib
from pathlib import Path

path = Path('Karta/Resources/Fonts/Figtree.ttf')
print('SHA256:', hashlib.sha256(path.read_bytes()).hexdigest())
ft = c.CDLL('libfreetype.so.6')
library, face = c.c_void_p(), c.c_void_p()
assert ft.FT_Init_FreeType(c.byref(library)) == 0
assert ft.FT_New_Face(library, str(path).encode(), 0, c.byref(face)) == 0
ft.FT_Get_Char_Index.argtypes = [c.c_void_p, c.c_ulong]
ft.FT_Get_Advance.argtypes = [c.c_void_p, c.c_uint, c.c_int32, c.POINTER(c.c_long)]
for weight in (700, 800):
    assert ft.FT_Set_Var_Design_Coordinates(face, 1, (c.c_long * 1)(weight * 65536)) == 0
    widths = []
    for code in range(32, 127):
        advance = c.c_long()
        glyph = ft.FT_Get_Char_Index(face, code)
        assert ft.FT_Get_Advance(face, glyph, 1, c.byref(advance)) == 0
        widths.append(advance.value)
    print(weight, widths)
ft.FT_Done_Face(face)
ft.FT_Done_FreeType(library)
