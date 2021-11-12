args={...}


clr_map = {["a"]=colors.white,
					 ["b"]=colors.orange,
					 ["c"]=colors.magenta,
					 ["d"]=colors.lightBlue,
					 ["e"]=colors.yellow,
					 ["f"]=colors.lime,
					 ["g"]=colors.pink,
					 ["h"]=colors.gray,
					 ["i"]=colors.lightGray,
					 ["j"]=colors.cyan,
					 ["k"]=colors.purple,
					 ["l"]=colors.blue,
					 ["m"]=colors.brown,
					 ["n"]=colors.green,
					 ["o"]=colors.red,
					 ["p"]=colors.black}

function loc_add(curr, amount)
	local x = curr.x + amount
	local y = curr.y + math.floor(x/WIDTH)
	if (y>=HEIGHT) then return vector.new(WIDTH,HEIGHT-1,0) end
	x = x % WIDTH
	return vector.new(x, y, 0)
end

function get_line(mon)
	cursor_x, cursor_y = mon.getCursorPos()
	return cursor_y
end

function next_line(mon)
	mon.setCursorPos(1, get_line(mon)+1)   -- newline
end

function disp_img(img_name, side)
	local monitor  = peripheral.wrap(side)
	monitor.setTextScale(0.5)
	monitor.setCursorPos(1,1)
	WIDTH, HEIGHT = monitor.getSize()
	if (not fs.exists(img_name)) then
		shell.run("download", img_name)
	end
	local img_str = fs.open(img_name, "r").readAll()
	local loc = vector.new(0,0,0)
	for clr, num in string.gmatch(img_str, "(%l)(%d+)") do
		monitor.setBackgroundColor(clr_map[clr])
		old_loc = loc
		loc = loc_add(loc, tonumber(num))
		if (loc.y == old_loc.y) then
			str_write = ""
			for _=old_loc.x,loc.x-1,1 do str_write = str_write.." " end
			monitor.write(str_write)
		else
			str_write = ""
			for _=old_loc.x,WIDTH-1,1 do str_write = str_write.." " end
			monitor.write(str_write)
			for _=old_loc.y+1,loc.y-1,1 do
				next_line(monitor)
				str_write = ""
				for __=0,WIDTH-1,1 do str_write = str_write.." " end
				monitor.write(str_write)
			end
			next_line(monitor)
			str_write = ""
			for _=0,loc.x-1,1 do str_write = str_write.." " end
			monitor.write(str_write)
		end 
	end
end

name = args[1]..".ptg"
disp_img(name, "left")

if (args[2]) then
	name2 = args[2]..".ptg"
	disp_img(name2, "right")
end