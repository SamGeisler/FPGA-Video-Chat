import numpy as np
from bitstring import BitStream
from encodingtables import *
from random import randint

def append_code(s, num_zeros, val, huff_table):
    if val == 0:
        s.append('0b' + huff_table['0/0'])
        return
    
    while num_zeros > 15:
        s.append('0b' + huff_table['F/0'])
        num_zeros -= 16

    size = int(abs(val)).bit_length()
    amplitude = int(val) if val >= 0 else (int(abs(val)) ^ ((1 << size) - 1))

    s.append('0b' + huff_table[f"{num_zeros:1X}/{size:1X}"])
    s.append(f'uint:{size}={amplitude}')


def entropy_encode(cell, last_DC, channel):
    stream = BitStream()

    dc_table = LUMINANCE_DC_TABLE if channel == "luminance" else CHROMINANCE_DC_TABLE
    ac_table = LUMINANCE_AC_TABLE if channel == "luminance" else CHROMINANCE_AC_TABLE

    DC_val = int(cell[0,0]) - int(last_DC)
    DC_size = int(abs(DC_val)).bit_length() if DC_val != 0 else 0
    DC_amplitude = 0
    if DC_val > 0:
        DC_amplitude = DC_val
    elif DC_val == 0:
        DC_amplitude = 0
    else:
        DC_amplitude = (int(abs(DC_val)) ^ ((1 << DC_size) - 1))

    stream.append('0b' + dc_table[DC_size])
    if DC_size > 0: stream.append(f'uint:{DC_size}={DC_amplitude}')

    r = 0
    c = 1
    zz_dir = "down"
    num_zeros = 0
    while 1:
        if cell[r, c] == 0:
            num_zeros += 1
        else:
            append_code(stream, num_zeros, cell[r,c], ac_table)
            
            num_zeros = 0

        if r == 7 and c == 7:
            if cell[r,c] == 0:
                append_code(stream, None, 0, ac_table)
            break
        elif r == 7 and zz_dir == "down":
            c += 1
            zz_dir = "up"
        elif c == 7 and zz_dir == "up":
            r += 1
            zz_dir = "down"
        elif r == 0 and zz_dir == "up":
            c += 1
            zz_dir = "down"
        elif c == 0 and zz_dir == "down":
            r += 1
            zz_dir = "up"
        elif zz_dir == "up":
            r -= 1
            c += 1
        else:
            r += 1
            c -= 1

    return stream