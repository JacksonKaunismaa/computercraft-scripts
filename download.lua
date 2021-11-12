args={...}
name = args[1]
headers={["User-Agent"]="Minecraft",
         ["Req-Type"]="download",
         ["Name"]=name}
file=http.post("http://127.0.0.1:5001", "", headers).readAll()
 
if (file=="0") then
  print("File "..name.." does not exist on server")
else
  if fs.exists(name) then
    --print("File already exists on your system, are you sure you want to download (y/n)?")
    --resp=io.read()
    resp="y"
    if (resp=="y") then
      f = fs.open(name, "w")
      f.write(file)
      f.close()
      print("File " .. name .. " succesfully downloaded")
    else print("Download rejected by user")
    end
  else
    f = fs.open(name, "w")
    f.write(file)
    f.close()
    print("File " .. name .. " succesfully downloaded")
  end
end