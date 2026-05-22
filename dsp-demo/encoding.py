import numpy as np

def entropy_encode(cell):
    stream = []
    r = 0
    c = 1
    zz_dir = "down"
    last_val = cell[0,0]
    curr_count = 1
    while 1:
        if cell[r, c] == last_val:
            curr_count += 1
        else:
            stream.append(curr_count)
            stream.append(last_val)
            curr_count = 0
            last_val = cell[r,c]

        if r == 7 and c == 7:
            break
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
    
    stream.append(curr_count)
    stream.append(last_val)

    return stream