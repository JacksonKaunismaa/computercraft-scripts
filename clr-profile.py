import os
import cv2
import numpy as np
from PIL import Image
import pickle
import pygame as pg
import re
import string
import json
from collections import Counter

important = re.compile("assets\/(.+)\.png")
idx_to_name = []
names = ["avgs.pkl", "stds.pkl", "names.pkl"]
recompute = False
k = 5
std_weight = 1e-4
banned = ["engineBlock", "item", "lamp", "Panel", "wire", "computer", "Laser", "liquid",
          "bee", "pack.png", "oil_", "anvil_", "quartz_block_lines.png", "bedrock.png",
          "bottom.png", "side.png", "Bottom.png", "sensor.png", "fPipe16.png", "blockSilver.png",
          "bark.", "drone_station", "concrete.png", "infernal.png", "engine.steam.high.png",
          "tile16.png", ".corner", ".default", ".connector", "requesttable", "light/on", "casing.vertical",
          "casing.northsouth", "pump_tube.png", "pump_top.png", "/pumpBlock", "ePipe", "eng_toolbox/textures/blocks/tile23"
         ]
IMG_FOR = "./turkmenistan.png"
SIZE = (256, 256)  # make really large to get good accuracy
SCREEN_SIZE = (512, 512)    # anything in 500-1500 is good
PART_SIZE = 256
MIN_SHARED = 90     # adjust this parameter to change how many block types are needed
PRUNE_ITERS = 15    # if you increase it, the colours will be less accurate but require fewer block types

assert (not (SCREEN_SIZE[0] % SIZE[0]) or not (SIZE[0] % SCREEN_SIZE[0]))
assert (not (SCREEN_SIZE[1] % SIZE[1]) or not (SIZE[1] % SCREEN_SIZE[1]))
assert (SIZE[0] % PART_SIZE == 0 and SIZE[1] % PART_SIZE == 0)

def close(clr):
    diffs = ((clrs-clr)**2).sum(axis=-1)*scaled_stds
    order = np.argsort(diffs)
    closest = diffs[order]
    return closest[:k], order[:k]

def legal(r_path):
    for ban in banned:
        if ban in r_path:
            return False
    return True

for n in names:
    if not os.path.exists(n):
        recompute = True

def show(np_img):
    p_img = Image.fromarray(np_img.astype(np.uint8))
    p_img.show()

def get_clrs(im_path):
    im_good = get_img(im_path)
    if im_good.shape[0] in [32, 64] and im_good.shape[1] in [32, 64]:
        avg_clr = im_good.mean(axis=0).mean(axis=0)
        var = im_good.std(axis=0).std(axis=0).sum()
        return avg_clr, var
    return np.array([0.0, 0.0, 0.0, 0.0]) , 999999.0

def get_img(im_path, rescale=None):
    im = cv2.imread(im_path, cv2.IMREAD_UNCHANGED)
    if im.shape[-1] != 4:
        im = cv2.cvtColor(im, cv2.COLOR_BGR2RGBA)
    else:
        im = cv2.cvtColor(im, cv2.COLOR_BGRA2RGBA)

    if rescale:
        im = cv2.resize(im, rescale, cv2.INTER_LINEAR)
    return im

if recompute:
    all_idx_to_name = []
    for root,dirs,files in os.walk("$HOME/.technic/modpacks/tekkit-legends/resourcepacks"):
        if legal(root):
            full_paths = [f"{root}/{x}" for x in files if x[-4:] ==".png" and legal(f"{root}/{x}")]
            abbr_paths = [re.search(important, x).group(1) for x in full_paths]
            idx_to_name += abbr_paths
            all_idx_to_name += full_paths

    clrs = np.zeros((len(all_idx_to_name), 4))
    stds = np.zeros((len(all_idx_to_name)))

    for i,img_path in enumerate(all_idx_to_name):
        clrs[i], stds[i] = get_clrs(img_path)

    with open(names[0], "wb") as p:
        pickle.dump(clrs, p)

    with open(names[1], "wb") as p2:
        pickle.dump(stds, p2)

    with open(names[2], "wb") as p3:
        pickle.dump(idx_to_name, p3)
else:
    with open(names[0], "rb") as p:
        clrs = pickle.load(p)

    with open(names[1], "rb") as p2:
        stds = pickle.load(p2)

    with open(names[2], "rb") as p3:
        idx_to_name = pickle.load(p3)
scaled_stds = std_weight*np.exp(stds) + 1
scaled_stds = np.where(scaled_stds<1.0, 1.0, scaled_stds)
scaled_stds = np.where(scaled_stds>1e6, 1e6, scaled_stds)



load_this = get_img(IMG_FOR, rescale=SIZE)
cnters = [{} for _ in range(k)]
res_grid = np.zeros(list(SIZE)+[k]).astype(np.int64)
tier_list = np.zeros(list(SIZE)).astype(np.uint8)

pct = 0.0
pct_incr = 0.05
tot = SIZE[0]*SIZE[1]
print("Starting computation...")
for y, row in enumerate(load_this):
    for x, pixel in enumerate(row):
        _, names = close(pixel)
        res_grid[y][x] = names
        if float(y*len(row)+x)/tot > pct:
            print("\b"*6+"# - %02d%%" % (100.0*pct), end="", flush=True)
            pct += pct_incr
print("\b"*6 + "# - 100%")
for iter_num in range(PRUNE_ITERS):
    all_cnts = Counter(res_grid.flat)
    all_s_cnts = np.zeros((len(idx_to_name))).astype(np.int64)
    for idx in range(len(idx_to_name)):
        try:
            all_s_cnts[idx] = all_cnts[idx]
        except KeyError:
            all_s_cnts[idx] = 0
    print(f"{iter_num} iter: Pruning outliers (current unique types = {len(np.unique(res_grid[:,:,0]))})...")
    for k,v in all_cnts.items():
        if v < MIN_SHARED:
            x_idxs, y_idxs, _ = np.where(res_grid == k)
            #print(k,v, "found low coutn")
            #print(x_idxs, y_idxs, "locations")
            all_possible = np.unique(res_grid[x_idxs, y_idxs].flat)
            #print("alternatives", all_possible)
            #print("knwon idxs", all_s_cnts.shape)
            #print("alternatives' counts:", all_s_cnts[all_possible])
            try:
                best = all_possible[np.argmax(all_s_cnts[all_possible])]
            except ValueError:
                continue
            #print("best alternative", best)
            res_grid[x_idxs, y_idxs, 0] = best
all_cnts = Counter(res_grid.flat)
print(f"FINAL: Pruning outliers (current unique types = {len(np.unique(res_grid[:,:,0]))})...")


with open(f"{IMG_FOR}.pix", "wb") as p20:
    pickle.dump(res_grid, p20)

#for i, cnt in enumerate(cnts):
#    print(f"Counts for tier {i}: ")
#    s_cnt = {x:y for x,y in sorted(cnt.items(), key=lambda it: it[1], reverse=True)}
#    for k,v in s_cnt.items():
#        print("\tn:", idx_to_name[k], "i:", k, "c:", v)

def raster_str(arr, start, end, the_id):
    select = arr[start[0]:end[0], start[1]:end[1], 0]
    rastered = [list(x[::(1-2*(i&1))]) for i, x in enumerate(select)]
    unfolded = [x for row in rastered for x in row]
    res_str = ""
    for el in unfolded:
        if el == the_id:      # idx of white_wool
            res_str += "1"
        else:
            res_str += "0"
    return res_str

flats = [el[0] for row in res_grid for el in row]
cnts = Counter(flats)
s_cnts = {x:y for x,y in sorted(cnts.items(), key=lambda it: it[1], reverse=True)}

for k,v in s_cnts.items():
    full_strs = []
    for i in range(SIZE[0]//PART_SIZE):
        for j in range(SIZE[1]//PART_SIZE):
            thing = raster_str(res_grid, (j*PART_SIZE,i*PART_SIZE), ((j+1)*PART_SIZE, (i+1)*PART_SIZE), k)
            full_strs.append(thing)
    with open(f"{k}.txt", "w") as f:
        full_str = "".join(full_strs)
        f.write(full_str)
    assert (full_str.count("1") == v)

def pos_to_coord(pos, any_flag=False):
    scaled_y, scaled_x = exact_pos_to_coord(pos)
    scaled_x = np.floor(scaled_x).astype(np.int64)
    scaled_y = np.floor(scaled_y).astype(np.int64)
    if (not any_flag) and scaled_x < 0:
        scaled_x = 0.5
    elif (not any_flag) and scaled_y < 0:
        scaled_y = 0.5
    return (scaled_y, scaled_x)

def exact_pos_to_coord(pos):
    scaled_x = float(float(pos[0])-exact_left)/(float(SCREEN_SIZE[0])/SIZE[0]*zoom)
    scaled_y = float(float(pos[1])- exact_top)/(float(SCREEN_SIZE[1])/SIZE[1]*zoom)
    return (scaled_y, scaled_x)

def coord_to_pos(coord):
    screen_x = int(float(coord[1])*zoom*(float(SCREEN_SIZE[0])/SIZE[0]) + exact_left)
    screen_y = int(float(coord[0])*zoom*(float(SCREEN_SIZE[1])/SIZE[1]) + exact_top)
    return (screen_x, screen_y)

def update_text(midx=None):
    global f_objs
    global text_locs
    f_objs = []
    text_locs = []
    if type(midx) == str:
        bottom_text = midx
    elif midx:
        bottom_text = f"{tier_list[midx]}: {idx_to_name[res_grid[midx][tier_list[midx]]]}"
    else:
        bottom_text = "We live in a society"
    bkp = bottom_text
    text_iter = len(bottom_text)
    full_len = text_iter
    line_iter = 0
    strs = []
    if disp_font.size(bottom_text)[0] <= SCREEN_SIZE[0]:
        f_objs.append(disp_font.render(bottom_text, True, f_clr))
        strs.append(bottom_text)
    else:
        while disp_font.size(bottom_text)[0] >= SCREEN_SIZE[0]:
            text_iter -= 1
            bottom_text = bkp[line_iter:text_iter]
            if disp_font.size(bottom_text)[0] <= SCREEN_SIZE[0]:
                f_objs.append(disp_font.render(bottom_text, True, f_clr))
                strs.append(bottom_text)
                line_iter += text_iter
                text_iter = full_len
                bottom_text = bkp[line_iter:text_iter]
        if line_iter != full_len:  # add residual
            bottom_text = bkp[line_iter:text_iter]
            f_objs.append(disp_font.render(bottom_text, True, f_clr))
            strs.append(bottom_text)
    max_i = len(strs)-1
    for i, (text_surf, the_text) in enumerate(zip(f_objs, strs)):
        #print("on it", i, "the_text is", the_text)
        text_locs.append(text_surf.get_rect(left=gd_rect.centerx-(disp_font.size(the_text)[0])//2, top=gd_rect.bottom-disp_font.size(the_text)[1]-(max_i-i)*disp_font.get_linesize()))


def update_zoom(amount):
    global zoom
    if zoom > 3.0:
        factor = min(2**(zoom-3.0), 15)
        zoom += factor*amount
        return factor*amount
    else:
        zoom += amount
        return amount

def proper_scale(im_name, factor_x, factor_y):
    factor_x = int(factor_x)
    factor_y = int(factor_y)
    loaded = get_img(im_name, SIZE)
    new_img = np.zeros((loaded.shape[0]*factor_x, loaded.shape[1]*factor_y, loaded.shape[2])).astype(np.uint8)
    for x, row in enumerate(loaded):
        for y, pixel in enumerate(row):
            new_img[x*factor_x:(x+1)*factor_x, y*factor_y:(y+1)*factor_y] = pixel
    idxs = np.random.choice(52, 50, replace=True)
    name = "/tmp/"
    for idx in idxs:
        name += string.ascii_letters[idx]
    name += ".png"
    pil_img = Image.fromarray(new_img)
    pil_img.save(name)
    return name

better_img_name = proper_scale(IMG_FOR, 2, 2)

pg.init()
pg.font.init()

gd = pg.display.set_mode(SCREEN_SIZE)
gd_rect = gd.get_rect()

keep = True
FPS = 15
clock = pg.time.Clock()
LEFT_CLICK = 1
MIDDLE_CLICK = 2
RIGHT_CLICK = 3
SCROLL_UP = 4
SCROLL_DOWN = 5
zoom = 1.0
zoom_incr = 0.05
exact_left = 0.0
exact_top = 0.0
exact_startx = 0.0
exact_starty = 0.0

mcmap = pg.image.load(better_img_name)
mc_copy = mcmap.copy()
mcmap = pg.transform.scale(mcmap, SCREEN_SIZE)
mcrect = mcmap.get_rect()
back_clr = pg.Color("orange")

disp_font = pg.font.SysFont("Comic Sans MS", 25)
disp_font2 = pg.font.SysFont("Comic Sans MS", 25)
f_clr = pg.Color("skyblue")
f_objs = []
text_locs = []
update_text()

#res_grid = np.random.random((SIZE[0], SIZE[1], k))
holding = False
grid_coord = 0.0
exact_grid_coord = 0.0
measuring = False
ctrl_mod = False
try:
    while keep:
        for evt in pg.event.get():
            if evt.type == pg.QUIT:
                keep = False
            elif evt.type == pg.MOUSEMOTION and not holding and not measuring and not ctrl_mod:
                mpos = pos_to_coord(evt.pos)
                try:
                    update_text(mpos)
                except IndexError:
                    update_text()
            elif evt.type == pg.MOUSEMOTION and holding:
                exact_left = float(evt.pos[0]) + exact_startx
                exact_top =  float(evt.pos[1]) + exact_starty
                mcrect.left = int(exact_left)
                mcrect.top =  int(exact_top)
            elif evt.type == pg.KEYDOWN and evt.key == pg.K_n and not measuring and not ctrl_mod:
                mpos = pos_to_coord(pg.mouse.get_pos())
                try:
                    tier_list[mpos] = min(tier_list[mpos]+1, k-1)
                    update_text(mpos)
                except IndexError:
                    update_text()
            elif evt.type == pg.KEYDOWN and evt.key == pg.K_b and not measuring and not ctrl_mod:
                mpos = pos_to_coord(pg.mouse.get_pos())
                try:
                    tier_list[mpos] = max(tier_list[mpos]-1, 0)
                    update_text(mpos)
                except IndexError:
                    update_text()
            elif evt.type == pg.KEYDOWN and evt.key == pg.K_v and not measuring and not ctrl_mod:
                m_coord = pos_to_coord(pg.mouse.get_pos())
                print("zoom_level:", zoom)
                print("mouse_coord:", pg.mouse.get_pos())
                print("img_coord:", m_coord)
                try:
                    print("block_type:", f"{tier_list[m_coord]}: {idx_to_name[res_grid[m_coord][tier_list[m_coord]]]}")
                except IndexError:
                    pass
            elif evt.type == pg.KEYDOWN and evt.key == pg.K_LCTRL:
                ctrl_mod = True
            elif evt.type == pg.KEYUP and evt.key == pg.K_LCTRL:
                ctrl_mod = False
            elif evt.type == pg.MOUSEBUTTONDOWN and evt.button == LEFT_CLICK and ctrl_mod and not measuring:
                grid_coord = pos_to_coord(evt.pos, any_flag=True)
                exact_grid_coord = exact_pos_to_coord(evt.pos)
                update_text(f"Set measure coord to {grid_coord}")
                measuring = True
            elif evt.type == pg.MOUSEBUTTONDOWN and evt.button == LEFT_CLICK and ctrl_mod and measuring:
                grid_coord2 = pos_to_coord(evt.pos, any_flag=True)
                d = np.sqrt((grid_coord[0]-grid_coord2[0])**2 + (grid_coord[1]-grid_coord2[1])**2)
                update_text(f"Start: {grid_coord} End: {grid_coord2} x-chng: {grid_coord2[1]-grid_coord[1]} y-chng: {grid_coord2[0]-grid_coord[0]} dist: {d}")
                measuring = False
            elif evt.type == pg.MOUSEMOTION and ctrl_mod and measuring:
                grid_coord2 = pos_to_coord(evt.pos)
                d = np.sqrt((grid_coord[0]-grid_coord2[0])**2 + (grid_coord[1]-grid_coord2[1])**2)
                update_text(f"Start: {grid_coord} End: {grid_coord2} x-chng: {grid_coord2[1]-grid_coord[1]} y-chng: {grid_coord2[0]-grid_coord[0]} dist: {d}")
            elif evt.type == pg.MOUSEBUTTONDOWN and evt.button == LEFT_CLICK:
                holding = True
                exact_startx = exact_left - float(evt.pos[0])
                exact_starty =  exact_top - float(evt.pos[1])
            elif evt.type == pg.MOUSEBUTTONUP and evt.button == LEFT_CLICK:
                holding = False
            elif evt.type == pg.MOUSEBUTTONDOWN and evt.button == SCROLL_UP:
                zoom_delta = update_zoom(zoom_incr)
                if zoom <= 12.0:
                    mcmap = pg.transform.scale(mc_copy, (int(SCREEN_SIZE[0]*zoom), int(SCREEN_SIZE[1]*zoom)))
                    exact_left = float(evt.pos[0]) - float(float(float(evt.pos[0]) - exact_left)*(SCREEN_SIZE[0]*zoom)/(SCREEN_SIZE[0]*(zoom-zoom_delta)))
                    exact_top =  float(evt.pos[1]) - float(float(float(evt.pos[1]) -  exact_top)*(SCREEN_SIZE[1]*zoom)/(SCREEN_SIZE[1]*(zoom-zoom_delta)))
                    mcrect.left = int(exact_left)
                    mcrect.top =  int(exact_top)
                else:
                    zoom -= zoom_delta
                if holding:
                    exact_startx = exact_left - float(evt.pos[0])
                    exact_starty =  exact_top - float(evt.pos[1])
                #print("in:", zoom)
            elif evt.type == pg.MOUSEBUTTONDOWN and evt.button == SCROLL_DOWN:
                zoom_delta = update_zoom(-zoom_incr)
                if zoom >= zoom_incr:
                    mcmap = pg.transform.scale(mc_copy, (int(SCREEN_SIZE[0]*zoom), int(SCREEN_SIZE[1]*zoom)))
                    exact_left = float(evt.pos[0]) - float(float(float(evt.pos[0]) - exact_left)*(SCREEN_SIZE[0]*zoom)/(SCREEN_SIZE[0]*(zoom-zoom_delta)))
                    exact_top =  float(evt.pos[1]) - float(float(float(evt.pos[1]) -  exact_top)*(SCREEN_SIZE[1]*zoom)/(SCREEN_SIZE[1]*(zoom-zoom_delta)))
                    mcrect.left = int(exact_left)
                    mcrect.top =  int(exact_top)
                else:
                    zoom -= zoom_delta
                if holding:
                    exact_startx = exact_left - float(evt.pos[0])
                    exact_starty =  exact_top - float(evt.pos[1])
                #print("out:", zoom)
        gd.fill(back_clr)
        gd.blit(mcmap, mcrect)
        if measuring:
            pg.draw.line(gd, pg.Color("black"), (coord_to_pos(exact_grid_coord)), pg.mouse.get_pos(), 5)
        for text_loc, f_obj in zip(text_locs, f_objs):
            gd.blit(f_obj, text_loc)
        pg.display.update()
        clock.tick(FPS)
finally:
    if os.path.exists(better_img_name):
        os.remove(better_img_name)
    print("goodbye")
    pg.quit()


