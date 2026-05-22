# TODO: The current bytestream encoding scheme is incorrect. Check Gemini for a description of what i need to do instaead. Then work on decomp

from PIL import Image
import numpy as np
from dct import *
from encoding import *

img = Image.open("img.png").convert("RGB")
pixels = np.array(img)

h = pixels.shape[0]
w = pixels.shape[1]

# Color space transformation & 4:2:0 Downsampling
color_transform_mat = np.array([[0.299, 0.587, 0.114],
                                [-0.168736, -0.331264, 0.5],
                                [0.5, -0.418688,-0.081312]])

Y = np.zeros((w,h))
Cb = np.zeros((w/2, h/2))
Cr = np.zeros((w/2, h/2))

for row in range(h):
    for col in range(w):
        t = color_transform_mat @ pixels[row,col]
        Y[row,col] = t[0]
        Cb[row/2,col/2] += t[1]
        Cr[row/2,col/2] += t[2]

# DCT - On hardware this will be implemented with the Loeffler butterfly process. 
#       This is equivalent to fast_dct8 being applied to every row and then every column 
#       (or vice versa) of the 8x8 matrix to be transformed.

GY = np.zeros((w,h))
GCb = np.zeros((w/2, h/2))
GCr = np.zeros((w/2, h/2))

for cell_row in range(0,h,8):
    for cell_col in range(0,w,8):
        src = Y[cell_row:cell_row+8, cell_col:cell_col+8] 
        dest = GY[cell_row:cell_row+8, cell_col:cell_col+8] 
        dest = dct8x8(src, str = "fast", scaled = False)[:,:]

        if cell_row < h/2 and cell_col < w/2:
            src = Cb[cell_row:cell_row+8, cell_col:cell_col+8] 
            dest = GCb[cell_row:cell_row+8, cell_col:cell_col+8] 
            dest = dct8x8(src, str = "fast", scaled = False)[:,:]
            
            src = Cr[cell_row:cell_row+8, cell_col:cell_col+8] 
            dest = GCr[cell_row:cell_row+8, cell_col:cell_col+8] 
            dest = dct8x8(src, str = "fast", scaled = False)[:,:]


# Quantization - Combined with final scaling stage of the DCT
# 50% quality per the original JPEG standard
Q = np.array([16, 11, 10, 16 ,24, 40, 51, 61],
             [12, 12, 14, 19, 26, 58, 90, 55],
             [14, 13, 16, 24, 40, 57, 69, 56],
             [14, 17, 22, 29, 51, 87, 80, 62],
             [18, 22, 37, 56, 68,109,103, 77],
             [49, 64, 78, 87,103,121,120,101],
             [72, 92, 95, 98,112,100,103, 99])

s = dct_scaling_coeff()**2

BY = np.zeros((w,h))
BCb = np.zeros((w/2, h/2))
BCr = np.zeros((w/2, h/2))

for cell_row in range(0,h,8):
    for cell_col in range(0,w,8):
        for r in range(8):
            for c in range(8):
                BY[cell_row + r, cell_col + c] = GY[cell_row + r, cell_col + c] /(Q[r,c] * s)

        if cell_row < h/2 and cell_col < w/2:
            for r in range(8):
                for c in range(8):
                    BCb[cell_row + r, cell_col + c] = GCb[cell_row + r, cell_col + c] /(Q[r,c] * s)
                
            
            for r in range(8):
                for c in range(8):
                    BCr[cell_row + r, cell_col + c] = GCr[cell_row + r, cell_col + c] /(Q[r,c] * s)

# Bytestream
Ystream = []
Cbstream = []
Crstream = []
for cell_row in range(0,h,8):
    for cell_col in range(0,w,8):
        Ystream += entropy_encode(BY[cell_row:cell_row+8, cell_col:cell_col+8])

        if cell_row < h/2 and cell_col < w/2:
            Cbstream += entropy_encode(BCb[cell_row:cell_row+8, cell_col:cell_col+8])
            Crstream += entropy_encode(BCr[cell_row:cell_row+8, cell_col:cell_col+8])




new_img = Image.fromarray(Y)
new_img.show()