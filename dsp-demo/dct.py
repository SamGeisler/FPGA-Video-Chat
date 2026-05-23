import numpy as np
from math import cos, sin, pi, sqrt
from random import uniform

np.set_printoptions(precision = 3, linewidth = np.inf)

def clean(arr):
    result = arr
    for i in range(arr.shape[0]):
        for j in range(arr.shape[1]):
            if abs(arr[i,j]) < 1e-10:
                result[i,j] = 0
    
    return result

def dct_mat_raw_unscaled():
    dct_mat = np.zeros((8,8))

    for k in range(8): # row index
        for n in range(8): # col index
            dct_mat[k,n] = cos(pi/8 * (n + 1/2) * k)
    
    return dct_mat


def dct_mat_raw_scaled():
    r0 = sqrt(1/8) * dct_mat_raw_unscaled()[0]
    rrest = sqrt(2/8) * dct_mat_raw_unscaled()[1:]
    return np.vstack([r0, rrest])


def fast_dct8(x):
    s1 = [x[0] + x[7], x[1] + x[6], x[2] + x[5], x[3] + x[4],
          x[3] - x[4], x[2] - x[5], x[1] - x[6], x[0] - x[7]]

    s2 = [s1[0] + s1[3], s1[1] + s1[2], s1[1] - s1[2], s1[0] - s1[3],
          s1[4] * cos(3*pi/16) + s1[7] * sin(3*pi/16),
          s1[5] * cos(1*pi/16) + s1[6] * sin(1*pi/16),
         -s1[5] * sin(1*pi/16) + s1[6] * cos(1*pi/16),
         -s1[4] * sin(3*pi/16) + s1[7] * cos(3*pi/16)]

    s3 = [s2[0] + s2[1], s2[0] - s2[1], 
          s2[2] * sqrt(2) * cos(3*pi/8) + s2[3] * sqrt(2) * sin(3*pi/8),
         -s2[2] * sqrt(2) * sin(3*pi/8) + s2[3] * sqrt(2) * cos(3*pi/8),
          s2[4] + s2[6], s2[7] - s2[5], s2[4] - s2[6], s2[5] + s2[7]]

    s4 = [s3[0], s3[1], s3[2], s3[3],
          -s3[4] + s3[7], sqrt(2) * s3[5], sqrt(2) * s3[6], s3[4] + s3[7]]

    final = np.array([s4[0], s4[7], s4[2], s4[5], s4[1], s4[6], s4[3], s4[4]])

    return final

def dct_mat_fast_unscaled():
    result = np.zeros((8,8))

    for i in range(8):
        e = np.zeros(8)
        e[i] = 1
        result[:,i] = fast_dct8(e)
    
    return result

def dct_mat_fast_scaled():
    M = dct_mat_fast_unscaled() @ dct_mat_raw_scaled().T
    return np.linalg.inv(M) @ dct_mat_fast_unscaled()

def dct8x8(x, mode = "fast", scaled = True):
    result = np.zeros((8,8))
    if scaled:
        if mode == "fast":
            result = dct_mat_fast_scaled() @ x @ dct_mat_fast_scaled().T
        elif mode == "raw":
            result = dct_mat_raw_scaled() @ x @ dct_mat_raw_scaled().T
    else:
        if mode == "fast":
            result = dct_mat_fast_unscaled() @ x @ dct_mat_fast_unscaled().T
        elif mode == "raw":
            result = dct_mat_raw_unscaled() @ x @ dct_mat_raw_unscaled().T

    return result

def inv_dct8x8(x, mode = "fast"):
    result = np.zeros((8,8))
    if mode == "fast":
        result = dct_mat_fast_scaled().T @ x @ dct_mat_fast_scaled()
    elif mode == "raw":
        result = dct_mat_raw_scaled().T @ x @ dct_mat_raw_scaled()

    return result

def dct_scaling_coeff():
    M = dct_mat_fast_unscaled() @ dct_mat_raw_scaled().T
    return M[0,0]