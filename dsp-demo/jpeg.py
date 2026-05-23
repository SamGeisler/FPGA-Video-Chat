from PIL import Image
import numpy as np
from dct import *
from encoding import *
from bitstring import BitStream

try:
    img = Image.open("img.png").convert("RGB")
except:
    img = Image.open("dsp-demo/img.png").convert("RGB")
pixels = np.array(img)

h = pixels.shape[0]
w = pixels.shape[1]
print(h,w)

# Color space transformation & 4:2:0 Downsampling
color_transform_mat = np.array([[0.299, 0.587, 0.114],
                                [-0.168736, -0.331264, 0.5],
                                [0.5, -0.418688,-0.081312]])

Y = np.zeros((h,w))
Cb = np.zeros((h//2, w//2))
Cr = np.zeros((h//2, w//2))

for row in range(h):
    for col in range(w):
        t = color_transform_mat @ pixels[row,col]
        Y[row,col] = t[0] - 128
        Cb[row//2,col//2] += t[1]/4 # Average adjacent values
        Cr[row//2,col//2] += t[2]/4 # Average adjacent values

# DCT - On hardware this will be implemented with the Loeffler butterfly process. 
#       This is equivalent to fast_dct8 being applied to every row and then every column 
#       (or vice versa) of the 8x8 MCU to be transformed.

GY = np.zeros((h,w))
GCb = np.zeros((h//2, w//2))
GCr = np.zeros((h//2, w//2))

for cell_row in range(0,h,8):
    for cell_col in range(0,w,8):
        src = Y[cell_row:cell_row+8, cell_col:cell_col+8] 
        GY[cell_row:cell_row+8, cell_col:cell_col+8] = dct8x8(src, mode = "fast", scaled = False)[:,:]

        if cell_row < h/2 and cell_col < w/2:
            src = Cb[cell_row:cell_row+8, cell_col:cell_col+8] 
            GCb[cell_row:cell_row+8, cell_col:cell_col+8] = dct8x8(src, mode = "fast", scaled = False)[:,:]
            
            src = Cr[cell_row:cell_row+8, cell_col:cell_col+8] 
            GCr[cell_row:cell_row+8, cell_col:cell_col+8] = dct8x8(src, mode = "fast", scaled = False)[:,:]


# Quantization - Combined with final scaling stage of the DCT
# 50% quality per the original JPEG standard
Q_Y = np.array([[16, 11, 10, 16 ,24, 40, 51, 61],
                [12, 12, 14, 19, 26, 58, 90, 55],
                [14, 13, 16, 24, 40, 57, 69, 56],
                [14, 17, 22, 29, 51, 87, 80, 62],
                [18, 22, 37, 56, 68,109,103, 77],
                [24, 35, 55, 64, 81,103,113, 92],
                [49, 64, 78, 87,103,121,120,101],
                [72, 92, 95, 98,112,100,103, 99]])

Q_C = np.array([[17, 18, 24, 47, 99, 99, 99, 99],
                [18, 21, 26, 66, 99, 99, 99, 99],
                [24, 26, 56, 99, 99, 99, 99, 99],
                [47, 66, 99, 99, 99, 99, 99, 99],
                [99, 99, 99, 99, 99, 99, 99, 99],
                [99, 99, 99, 99, 99, 99, 99, 99],
                [99, 99, 99, 99, 99, 99, 99, 99],
                [99, 99, 99, 99, 99, 99, 99, 99]])

s = dct_scaling_coeff()**2

BY = np.zeros((h,w))
BCb = np.zeros((h//2, w//2))
BCr = np.zeros((h//2, w//2))

for cell_row in range(0,h,8):
    for cell_col in range(0,w,8):
        for r in range(8):
            for c in range(8):
                BY[cell_row + r, cell_col + c] = np.round(GY[cell_row + r, cell_col + c] /(Q_Y[r,c] * s))
for cell_row in range(0, h//2, 8):
    for cell_col in range(0, w//2, 8):
        src = Cb[cell_row:cell_row+8, cell_col:cell_col+8] 
        GCb[cell_row:cell_row+8, cell_col:cell_col+8] = np.round(dct8x8(src, mode="fast", scaled=False)/(Q_C[r,c]*s))
        src = Cr[cell_row:cell_row+8, cell_col:cell_col+8] 
        GCr[cell_row:cell_row+8, cell_col:cell_col+8] = np.round(dct8x8(src, mode="fast", scaled=False)/(Q_C[r,c]*s))

# Bytestream
Ystream = BitStream()
Cbstream = BitStream()
Crstream = BitStream()
last_DC_Y = 0
last_DC_Cb = 0
last_DC_Cr = 0
for cell_row in range(0,h,8):
    for cell_col in range(0,w,8):
        Ystream.append(entropy_encode(BY[cell_row:cell_row+8, cell_col:cell_col+8],
                                  last_DC_Y, "luminance"))
        last_DC_Y = BY[cell_row,cell_col]

for cell_row in range(0, h//2, 8):
    for cell_col in range(0, w//2, 8):
        Cbstream.append(entropy_encode(BCb[cell_row:cell_row+8, cell_col:cell_col+8],
                            last_DC_Cb, "chrominance"))
        Crstream.append(entropy_encode(BCr[cell_row:cell_row+8, cell_col:cell_col+8],
                            last_DC_Cr, "chrominance"))
        last_DC_Cb = BCb[cell_row,cell_col]
        last_DC_Cr = BCr[cell_row,cell_col]

print(30*'-' + "Y STREAM" + 30*'-')
print(Ystream.bin)
print(30*'-' + "Cb STREAM" + 30*'-')
print(Cbstream.bin)
print(30*'-' + "Cr STREAM" + 30*'-')
print(Crstream.bin)