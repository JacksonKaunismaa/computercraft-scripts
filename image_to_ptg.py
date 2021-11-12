#!/usr/bin/env python3
import os
import cv2
import numpy as np
from PIL import Image
import pickle
import pygame as pg
import string
from collections import Counter
import re
import sys

clr_to_let = {"white":     "a",
              "orange":    "b",
              "magenta":   "c",
              "lightBlue": "d",
              "yellow":    "e",
              "lime":      "f",
              "pink":      "g",
              "gray":      "h",
              "lightGray": "i",
              "cyan":      "j",
              "purple":    "k",
              "blue":      "l",
              "brown":     "m",
              "green":     "n",
              "red":       "o",
              "black":     "p"}

def hex_to_rgb(hex_code):
    if len(hex_code) > 7:
        raise ValueError(f"hex code '{hex_code}' looks bad")
    elif len(hex_code) == 7:
        hex_code = hex_code[1:]
    split_codes = [int(hex_code[i*2:(i+1)*2], 16) for i in range(3)]
    split_codes.append(255)
    return np.array(split_codes).astype(np.float32)

codes_in_order = ["F0F0F0","F2B233","E57FD8","99B2F2","DEDE6C","7FCC19","F2B2CC","4C4C4C","999999","4C99B2","B266E5","3366CC","7F664C","57A64E","CC4C4C","191919"]
clr_arr = np.array([hex_to_rgb(x) for x in codes_in_order])
let_to_idx = {x:idx for idx,x in enumerate(clr_to_let.values())}

IMG_FOR = sys.argv[1:]
#RESOLUTION = [81,164]  # make really large to get good accuracy
RESOLUTION = [67,164]  # make really large to get good accuracy
weights = np.array([1.0, 1.2, 1.5, 1.0])

def close(clr, clrs):
    diffs = (((clrs-clr)**2)*weights).sum(axis=-1)
    closest = np.argmin(diffs)
    return clr_to_let[list(clr_to_let.keys())[closest]]

def show(np_img):
    p_img = Image.fromarray(np_img.astype(np.uint8))
    p_img.show()

def get_img(im_path, rescale=None):
    im = cv2.imread(im_path, cv2.IMREAD_UNCHANGED)
    if im.shape[-1] != 4:
        im = cv2.cvtColor(im, cv2.COLOR_BGR2RGBA)
    else:
        im = cv2.cvtColor(im, cv2.COLOR_BGRA2RGBA)

    if rescale:
        im = cv2.resize(im, rescale, cv2.INTER_LINEAR)
        im = cv2.cvtColor(cv2.cvtColor(im, cv2.COLOR_RGBA2RGB), cv2.COLOR_RGB2HLS).astype(np.int64)
        im[:,:,1] += int(40)
        im[:,:,1] = np.clip(im[:,:,1], 0, 255)
        im = cv2.cvtColor(cv2.cvtColor(im.astype(np.uint8), cv2.COLOR_HLS2RGB), cv2.COLOR_RGB2RGBA)
    return im

def proc_img(img_name):
    load_this = get_img(img_name, rescale=tuple(RESOLUTION[::-1]))
    #show(load_this)
    cnters = {}
    res_grid = np.chararray(RESOLUTION)

    pct = 0.0
    pct_incr = 0.05
    tot = RESOLUTION[0]*RESOLUTION[1]
    print("Starting computation...")
    for y, row in enumerate(load_this):
        for x, pixel in enumerate(row):
            pixel_letter = close(pixel, clr_arr)
            res_grid[y,x] = pixel_letter
            if float(y*len(row)+x)/tot > pct:
                print("\b"*6 + "# - %02d%%" % (100.0*pct), end="", flush=True)
                pct += pct_incr
    print("\b"*6 + "# - 100%")
    ptg_str = ""
    #clrs_used = str(int("".join(["1" if bytes(x, "ascii") in res_grid else "0" for x in clr_to_let.values()]), 2))
    #ptg_str += clrs_used + "|"

    content_str = ""
    curr = res_grid[0][0]
    cnt = 0
    for row in res_grid:
        for let in row:
            if let != curr:
                content_str += curr.decode("ascii") + str(cnt)
                curr = let
                cnt = 1
            else:
                cnt += 1

    content_str += curr.decode("ascii") + str(cnt)   # do last colour
    #ptg_str += str(len(content_str)) + "|" + content_str
    ptg_str = content_str
    with open("../" + img_name + ".ptg", "w") as f:
        f.write(ptg_str)
    return ptg_str
for i,img_for in enumerate(IMG_FOR):
    result = proc_img(img_for)
    #if i>20:
    #    break
def loc_add(curr, amount):
    x = curr[1] + amount
    y = curr[0] + (x//RESOLUTION[1])
    if y == RESOLUTION[0]:
        y = RESOLUTION[0]-1
        x = RESOLUTION[1]
        return y,x
    x = x % RESOLUTION[1]
    return y,x


block_finder = re.compile("(.)(\d+)")
rebuild = np.zeros(list(RESOLUTION)+[4])
loc = (0,0)
for block in re.finditer(block_finder, result):
    current_color = clr_arr[let_to_idx[block.group(1)]]
    old_loc = loc
    loc = loc_add(loc, int(block.group(2)))
    #print("clr", current_color, "loc", loc, "cnt", block.group(2), "let", block.group(1))
    if loc[0] == old_loc[0]:
        rebuild[loc[0], old_loc[1]:loc[1]] = current_color
    else:
        rebuild[old_loc[0], old_loc[1]:RESOLUTION[1]] = current_color
        rebuild[old_loc[0]+1:loc[0], :] = current_color
        rebuild[loc[0], 0:loc[1]] = current_color
show(rebuild)

