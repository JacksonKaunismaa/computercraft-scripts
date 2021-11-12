DEBUG = 3
WARN = 2
ERROR = 1
NONE = 0

local LEVEL = NONE
local fname = ""
local log_f = nil
local iter=0

function get_name()
	local time = http.get("http://127.0.0.1:5000").readAll()
	return tostring(time)
end

function init(script_name)
	local t = get_name()
	fname = script_name .. "-" .. t
	remove_old(script_name)
end

function log(msg)
	if (type(log_f) ~= "table") then
		log_f = fs.open(fname, "w")
	end
	if (iter == 0) then log_f.write("ID: " .. os.getComputerID() .. "\n\n\n") end
	--log_f.write(iter.."("..get_name()..")" .. ": " .. msg .. "\n\n\n")  --leads to issues with the server not being able to respond to get requests fast enough for the time
	log_f.write(iter.. ": " .. msg .. "\n\n\n")  --leads to issues with the server not being able to respond to get requests fast enough for the time
	log_f.flush()
	iter = iter+1
end

function remove_old(script_name)
	local files = fs.list(".")
	files = table.concat(files, "~")
	local pattern = "(" .. script_name .. "[^~]-)~"
	str_matcher = string.gmatch(files, pattern)
	for str in str_matcher do
		if (str ~= script_name) then
			fs.delete(str)
		end
	end
end

function set_log_level(num)
	LEVEL = num
end

function debug(msg)
	if (LEVEL >= DEBUG) then
		print(msg)
		log(msg)
	end
end

function warn()
	if (LEVEL >= WARN) then
		print(msg)
		log(msg)
	end
end

function error()
	if (LEVEL >= ERROR) then
		log(msg)
		error(msg)
	end
end

function close()
	if (log_f) then
		log_f.close()
		log_f = nil
	end
end
