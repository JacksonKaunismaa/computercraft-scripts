args={...}

SIZE = 256
PIXELS = 256

BLK_START = 1
BLK_MAX = 16

UP = 0
RIGHT = 1
DOWN = 2
LEFT = 3
facing = UP 

y_coord = tonumber(string.sub(args[1], 1, 1))
x_coord = tonumber(string.sub(args[1], 2, 2))

FNAME = args[2]

shell.run("download " .. FNAME .. ".txt")

read = fs.open(FNAME..".txt", "r").readAll()
start = 1+x_coord*(SIZE*SIZE)+y_coord*(SIZE*SIZE*(PIXELS/SIZE))
end_ = 1+(x_coord+1)*(SIZE*SIZE)+y_coord*(SIZE*SIZE*(PIXELS/SIZE))
guide = string.sub(read, start, end_)
guide = string.sub(guide, end_/2, end_)

f = fs.open("test.res", "w")
for i=0,SIZE-1,1 do
	f.write(string.sub(guide, 1+i*SIZE, 1+(i+1)*SIZE) .. "\n")
end
f.flush()
f.close()

function safe_down()
  local success = turtle.down()
  local failures = 0
  while (not success) do
    failures = failures + 1
    if (failures > 20) then
      return 0
    end
    success = turtle.down()
  end
  return -1
end

function safe_up()
  local success = turtle.up()
  local failures = 0
  while (not success) do
    failures = failures + 1
    if (failures > 20) then
      return 0
    end
    success = turtle.up()
  end
  return 1
end

function safe_forward()
  local fails = 0
  local height = 0
  local worked = turtle.forward()
  while (not worked) do 
    fails = fails + 1
    os.sleep(1.5)
    if (fails > 8) then
      for _dummy_=1,facing,1 do 
        height=height+safe_up() 
        worked = turtle.forward()
        if (worked) then break end
      end
      if (worked) then break end
      worked = turtle.forward()
      if (worked) then break end
      for _dummy_=1,facing,1 do 
        height=height+safe_down() 
        worked = turtle.forward()
        if (worked) then break end
      end
    else
      worked = turtle.forward()
    end
  end
  while (height ~= 0) do
    height = height + safe_down()
  end
end


for i=1,((PIXELS/SIZE)-x_coord)*SIZE,1 do
  safe_forward()
end
turtle.turnRight()
facing = (facing+1)%4
for i=1,y_coord*SIZE,1 do
  safe_forward()
end

function safe_place_down(slot)
  turtle.select(slot)
  var=turtle.placeDown()
  while (not var)
  do
    turtle.digDown()
    var=turtle.placeDown()
  end
end

function empty_chest()
  local suc = turtle.suckUp()
  while (suc) do
    suc = turtle.suckUp()
  end
end

function cycle_blocks(current,max)
  while (turtle.getItemCount(current)==1) do
    current=current+1
    if (current>max) then
      error("Out of blocks") -- probably should turn this into a sleep or something
    end
  end
  return current
end

for i=0,SIZE-1,1 do
	for j=1,SIZE,1 do
		loc = i*SIZE+j
		chr = string.sub(guide, loc, loc)
		if (chr == "1") then
			safe_place_down(cycle_blocks(BLK_START, BLK_MAX))
		end
    if (not (i == (SIZE-1) and j==SIZE)) then
      safe_forward()
      --empty_chest()
    end
	end
  if (i ~= (SIZE-1)) then
    if (i%2 == 0) then
  		turtle.turnRight()
      facing = (facing+1)%4
     	safe_forward()
  		turtle.turnRight()
      facing = (facing+1)%4
    else
    	turtle.turnLeft()
      facing = (facing-1)%4
    	safe_forward()
    	turtle.turnLeft()
      facing = (facing-1)%4
    end
    safe_forward()
  end
end
print("COMPLETED")
turtle.up()
