os.loadAPI("binary")
os.loadAPI("logging")

logging.set_log_level(logging.DEBUG)
logging.init("control4")

CONTROL_VERSION = 4

-- CONSTANTS -------------------------------------------------------------------------------------------------------------
NO_WAIT=0
WAIT_FILENAME=1
WAIT_FILECONT=2

WAIT_ACK=1
WAIT_RES=2

NOT_CONNECTED = 99999999999
ROOT = 0

DELAY=2.0
TIMEOUT = 30   -- 30 second timeout to respond to message
CHECK = 180 -- + ( math.randomseed(os.time) && math.random() )
SELF_ID=os.getComputerID()
SELF_NAME = "root"
-- CONSTANTS -------------------------------------------------------------------------------------------------------------

function send_file(fname)
	local f = fs.open(fname, "r")
	if (not f) then logging.error("File '" .. fname .. "' does not exist") return 0 end
	local file_content = f.readAll()
	f.close()
	local file_msg={}
	file_msg.data = file_content
	file_msg.name = fname
	send_msgs(file_msg, "child", true, "fs")
end

function contains(tbl, val)
	for i, el in ipairs(tbl) do
		if (el == val) then
			return true
		end
	end
	return false
end


function get_rtime()
	local time = http.get("http://127.0.0.1:5000").readAll()
	return time
end

function get_time()
	return os.clock()
end

function send_msg(the_msg, recv_id)
	rednet.send(recv_id, the_msg, "child")
	logging.debug("sent msg to " .. recv_id)
	logging.debug("msg content was: " .. binary.itstring(the_msg.content))
	logging.debug("msg type was " .. the_msg.sType)
	logging.debug("msg id was " .. the_msg.sID)
end  

function help()
	print("Welcome to the Control Center!")
	print("This machine sends messages to any computer with the 'child' program running")
	print("It uses the child protocol to do this")
	print(" ")
	print("To send a file to every child computer, type 'send_file <filename>'")
	print(" ")
	print("To run a command on every child computer, just type the name of the command and it will be sent to every child to be executed")
	print("For most programs, you will need to add an extra number to indicate the time(or something else) you want the children to run")
	print("that command. In order to repeatedly send a message, turn on the redstone switch on 'top' and the message will be resent")
	print(" ")
	print("To get info on the children currently available, type 'status'")
	print(" ")
	print("Type help to display this message")
end   
	
function parse_cmd(cmd_str)
	local t={}
	for str in string.gmatch(cmd_str, "[^%s]+") do
		table.insert(t, str)
	end
	return t
end

function show_status(protocol)
	send_msgs("status", "child", true, "find")
end

function build_type_msg(mtype, mid)
	local msg={}
	msg.sType = mtype
	msg.sID = mid
	msg.content = ""
	return msg
end

function send_msgs(msg_content, protocol, do_ack, msg_type)
	local msg = {}
	msg.sType = msg_type
	msg.content = msg_content
	msg.sID = tostring(get_rtime())
	for i, ID in ipairs(clients) do
		send_msg(msg, ID)
	end
	if (binary.gsize(clients) == 0) then
		print("No children online...")
		return
	end
	if (do_ack == true) then
		if (not msg_content) then msg_content="nothing" end
		cmds_sent[msg.sID]=msg_content   -- dont do it otherwise since its unnecessary
		awaiting_acks[msg.sID] = {}
		awaiting_resps[msg.sID]= {}
		binary.ginsert_all(awaiting_acks[msg.sID], clients)
		binary.ginsert_all(awaiting_resps[msg.sID], clients)
		logging.debug("requested an ack on msg: " .. binary.itstring(msg))
		logging.debug("cmds_sent_state: " .. binary.itstring(cmds_sent))
	end
end

function offer_connection(msg_id, msg_sender)
	local msg={}
	msg.sType = "offer"
	msg.sID = msg_id
	msg.content = {}
	msg.content.level = level
	msg.content.size = binary.gsize(clients)
	send_msg(msg, msg_sender)
end

function read_msgs()
	while (keep) do
		cmd=io.read()
		parsed=parse_cmd(cmd)
		logging.debug("parsed: " .. binary.gstring(parsed))
		if (cmd == "break") then
			send_msgs("break", "child", false, "send")
			keep=false
		elseif (parsed[1] == "send_file") then
			logging.debug("registed a send_file command")
			send_file(parsed[2])
			logging.debug("sent fs message")
		elseif (cmd == "status") then
			show_status("child")
		elseif (cmd == "help") then
			help()
		end
		-- elseif (cmd == "download") then
		-- 	send_msgs(cmd, "child", false, "send")
		-- else 
		-- 	-- for the case of starting programs on children
		-- 	-- the first argument must always be the amount of time you want it to run for
		-- 	send_msgs(cmd, "child", false, "send")
		-- 	os.sleep(tonumber(parsed[2]))
		-- 	while (wait_for_input(2)) do --basically resend the message if the
		-- 		send_msgs(cmd, "child", false, "send")    --redstone on "top" is on
		-- 		os.sleep(tonumber(parsed[2]))
		-- 	end 
		-- end
	end
end


function proc_msgs()
	while (keep) do
		--logging.debug("before msg_q: " .. binary.itstring(msg_q))
		local msg=binary.pop_left(msg_q)
		if (not msg) then 
			fails = fails+1
		end
		logging.debug("msg_q: " .. binary.itstring(msg_q))
		if (msg and msg.sID) then
			fails = 0
			logging.debug(binary.itstring(msg))
			if (msg.sType == "accept") then
				binary.ginsert(clients, msg.sSender)
				print("Connection wtih "..msg.sSender.." established!")
			elseif (msg.sType == "new") then
				print("Indirect connection with "..msg.sID.." established!")
			elseif (msg.sType == "ack") then		-- yup, this client got your message
				logging.debug("Got an ACK from " .. msg.sSender)
				logging.debug("awaiting_acks before: "..binary.itstring(awaiting_acks))
				binary.gemove(awaiting_acks[msg.sID], msg.sSender)
				logging.debug("awaiting_acks after: "..binary.itstring(awaiting_acks))
				if (binary.gsize(awaiting_acks[msg.sID]) == 0) then
					logging.debug("done waiting for acks")
					logging.debug("before awaiting_acks remove_key: " .. binary.itstring(awaiting_acks))
					binary.remove_by_key(awaiting_acks, msg.sID)   -- no longer waiting for acks from this message
					logging.debug("before awaiting_acks remove_key: " .. binary.itstring(awaiting_acks))
					binary.remove_by_key(timeouts, msg.sID)				-- erase TIMEOUT timer
				end
			elseif (msg.sType == "res") then
				logging.debug("Got a res from " .. msg.sSender)
				logging.debug("awaiting_resps before: " .. binary.itstring(awaiting_resps))
				binary.gemove(awaiting_resps[msg.sID], msg.content.me)   -- every resp has content={me=SELF_ID, parent=connector}
				logging.debug("awaiting_resps after: " .. binary.itstring(awaiting_resps))
				logging.debug("after msg_q: " .. binary.itstring(msg_q))
				if (not total_resps[msg.sID]) then total_resps[msg.sID] = {} end
				table.insert(total_resps[msg.sID], msg.content)
				if (binary.gsize(awaiting_resps[msg.sID]) == 0) then
					binary.remove_by_key(awaiting_resps, msg.sID)   -- no longer waiting for acks from this message
					logging.debug("all resps: "..binary.itstring(total_resps[msg.sID]))
					local topography = {}
					for i, RES in ipairs(total_resps[msg.sID]) do
						if (not topography[RES.parent]) then topography[RES.parent] = {} end
						binary.ginsert(topography[RES.parent], RES.me)
					end
					print("All responses received! Network looks like this: ")
					for PARENT, KIDS in pairs(topography) do
						print(PARENT..":\n\t"..binary.gstring(KIDS))
					end
					topography = nil
					total_resps[msg.sID] = nil
				end
			elseif (msg.sType == "check") then
				if (contains(clients, msg.sSender)) then
					send_msg(build_type_msg("affirm", 0), msg.sSender)
				else
					send_msg(build_type_msg("affirm", 0), msg.sSender)
					binary.ginsert(clients, msg.sSender) 	-- renew connection that I thought had expired
					print("Connection reestablished with " .. msg.sSender .. "!")
				end
			elseif (msg.sType == "connect") then 	-- send connection details
				offer_connection(msg.sID, msg.sSender)
			elseif (msg.sType == "check") then
				if (contains(clients, msg.sSender)) then
					send_msg(build_type_msg("affirm", 0), msg.sSender)
				else
					send_msg(build_type_msg("affirm", 0), msg.sSender)
					binary.ginsert(clients, msg.sSender) 	-- renew connection that I thought had expired
				end
			end
		end		

		if (binary.gsize(timeouts) ~= 0 and binary.gsize(msg_q) == 0) then   -- handle timeouts (if for some msg they take longer than 30s to ACK, consider them timed out and remove them from clients list)
			for m_id, m_time in pairs(timeouts) do 
				if ((get_time() - m_time) > TIMEOUT) then
					for i, ID in ipairs(awaiting_acks[m_id]) do
						binary.gemove(clients, ID)
						send_msg(build_type_msg("disconnect", 0), ID)   -- send disconnect just in case its actually still in range, to notify that it wont be getting serviced anymore
					end
				end
			end
		end

		if (fails > 5) then   -- if dont receive a message for awhile, then go into sleep mode
			--print("too many fails, entering sleep mode (fails = " .. fails .. ")")
			--print("msg looked like: " .. binary.itstring(msg))
			--print("msg q now is: " .. binary.itstring(msg_q))
			os.sleep(DELAY)
		end
		--logging.debug("after after msg_q: " .. binary.itstring(msg_q))

	end
end

function accumulate_msgs()
	while (keep) do
		local _id, _msg=rednet.receive()
		if (_msg) then
			_msg.sSender = _id    -- so every message is signed by the sender
			logging.debug("got an msg: " .. binary.itstring(_msg))
			binary.push_right(msg_q,_msg)
		end
	end
end

function start()
	parallel.waitForAll(accumulate_msgs, proc_msgs, read_msgs)
	return 0
end

function fallback(err)
	print(err)
	print("also")
	logging.close()
end

rednet.open("right")
rednet.host("child", SELF_NAME)

keep=true
fails=0

-- CONNECT -- 
level = ROOT
connector = ROOT
clients = {}
ids_asked = {}
qualities = {}
connect_time = -1

-- FORWARD -- 
awaiting_acks = {}
awaiting_resps = {}
total_resps = {}
timeouts = {}

msg_q=binary.queue_new()
--forwarding = {}
--forwarded_to={}
--forward_success={}
--forward_resps = {}
cmds_sent={}
xpcall(start, fallback)
print("goodbye")
rednet.unhost("child", SELF_NAME)
rednet.close("right")
logging.close()
