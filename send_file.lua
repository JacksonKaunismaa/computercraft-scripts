args={...}
function send_msg(msg_content, recv_id)
  msg = {}
  msg.sType="send"
  msg.content=msg_content
  rednet.send(recv_id, msg)
end

rednet.open("right")
machines={rednet.lookup("file_recv")}
f = fs.open(args[1], "r")
for i, ID in ipairs(machines) do
  print(i .. ": sending filename(" .. args[1] .. ") to " .. ID)
  send_msg(args[1], ID)
end
os.sleep(2)
file_content = f.readAll()
for i,ID in ipairs(machines) do
  print(i .. ": sending file contents to " .. ID)
  send_msg(file_content,ID)
end
--rednet.close("right")
f.close()