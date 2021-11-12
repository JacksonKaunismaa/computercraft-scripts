# Computercraft Scripts

These were developed for the Tekkit Legends pack, for ComputerCraft 1.65.

### Pixel Art

The clr-profile.py and placer.lua files are used to automatically compute and create pixel art given an image.
The texturepack used therefore has an effect on this module. The avgs.pkl, names.pkl, and stds.pkl were computed based
on the Sphax PureBDCraft version 1.7.2 32x pack, as well as the default texture pack provided in that pack. However, if you 
want to do it with a different texture pack, you can just recompute those (by setting recompute = True).

### Image Display

The image_to_ptg.py and feh.lua define a file format and way to take .png images and make an approximation of them displayable 
on a computercraft screen. First, you turn a .png file into a .ptg file by running image_to_ptg.py on it. Then, you use download.lua
to put the .ptg file and feh.lua onto a computercraft device, in game. Then you can simply run feh <filename.ptg> to display the image.

### Network Protocol

A very primitive network protocol loosely based off of TLS, but with no encryption is implemented on the files control4.lua and child4.lua.
They use the helper libraries binary.lua and logging.lua. Also, send_file.lua is very useful to transfer files from the control computer to
all the other computers in the network. You can run commands on many computers simultaneously, and monitor network statistics, all from the
central control computer. 

### Improved editing pipeline

By usage of download.lua and upload.lua, along with the servers in comms-mc.py and time-server.sh, you can edit files using a proper IDE on 
your computer, and then transfer them to the computers directly. This greatly improves the editing process as the in-game IDE is very 
lackluster. While you could technically just go into the save files and copy your desired file into there, this approach technically works
on remote servers as well, though I would strongly recommend against it, as there are very likely huge security flaws in the approach I have
taken.
