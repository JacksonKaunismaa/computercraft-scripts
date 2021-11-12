args={...}
load_file = fs.open(args[1], "r")
if (not load_file) then error("File does not exist") end
data = load_file.readAll()
function strip(str)
	good = string.match(str, "/?([^/]+)$")
	return good
end

function encode(str)
	encoded = string.gsub(str, "+", "__PLUS__")
	return encoded
end
headers = {["User-Agent"]="Minecraft",
           ["Req-Type"]="upload",
           ["Name"]=strip(args[1])}

result=http.post("http://127.0.0.1:5001", encode(data), headers)
print(result.readAll())