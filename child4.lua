os.loadAPI("binary")
os.loadAPI("logging")

logging.set_log_level(logging.DEBUG)
logging.init("child4")
-- CONSTANTS -------------------------------------------------------------------------------------------------------------
NO_WAIT=0
WAIT_FILENAME=1
WAIT_FILECONT=2
CHILD_VERSION=4

WAIT_ACK=1
WAIT_RES=2

NOT_CONNECTED = 99999999999

DELAY=0.2
TIMEOUT = 30   -- 30 second timeout to respond to message
CHECK = 180 -- + ( math.randomseed(os.time) && math.random() )
SELF_ID=os.getComputerID()
-- CONSTANTS -------------------------------------------------------------------------------------------------------------
--- UTILS ----------------------------------------------------------------------------------------------------------------
function get_rtime()
	local time = http.get("http://127.0.0.1:5000").readAll()
	return time
end

function get_time()
	return os.clock()
end

function get_rand()
	local rand = math.floor(100000*(math.random()+0.0001)) % 20
	return rand
end

function contains(tbl, val)
	i = #tbl   -- backwards iterate because faster
	while (i ~= 0) do
	 if (val == tbl[i]) then return true end
	 i=i-1
	end
	return false
end

function register()
	rednet.open("right")
	time_name = tostring(get_rtime())
	rednet.host("child", time_name)
	print("registered as " .. time_name)
	print("child version is " .. CHILD_VERSION)
	return time_name
end

function build_type_msg(mtype, mid)
	local msg={}
	msg.sType = mtype
	msg.sID = mid
	msg.content = ""
	return msg
end

function send_msg(the_msg, recv_id)
	rednet.send(recv_id, the_msg, "child")
	logging.debug("sent msg to " .. recv_id)
	logging.debug("msg was "..binary.itstring(the_msg))
end  
--- UTILS ----------------------------------------------------------------------------------------------------------------
-- CHECK -----------------------------------------------------------------------------------------------------------------

function reset_check()
	last_checked = get_time()
	check_interval = CHECK + get_rand()   -- set it way beyond last_checked so that "time()-last_checked > large_CHECK" gets triggered before "time()-checked_time > small_TIMEOUT"
	checked_time = last_checked + 5*check_interval 
end

-- CHECK -----------------------------------------------------------------------------------------------------------------
-- CONNECT ---------------------------------------------------------------------------------------------------------------
function send_connects()
	print("Searching for connections...")
	logging.debug("searching for connections...")
	local machines={rednet.lookup("child")}
	local msg = build_type_msg("connect", tostring(get_rtime()))
	table.sort(machines)
	binary.gemove(machines, SELF_ID)
	for i, ID in ipairs(machines) do
		send_msg(msg, ID)
	end
	return machines
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

function proc_offer(quality, msg_sender)
	binary.gemove(ids_asked, msg_sender)
	qualities[msg_sender] = quality
end

function maybe_accept()
	if (level == NOT_CONNECTED and (binary.gsize(ids_asked) == 0 or (binary.gsize(msg_q) == 0 and (get_time() - connect_time) > TIMEOUT))) then
		local closest = NOT_CONNECTED
		local smallest = NOT_CONNECTED
		local host = NOT_CONNECTED
		for machine, quality in pairs(qualities) do
			if (quality.level < closest) then
				closest = quality.level
				smallest = quality.size
				host = machine
			elseif (quality.level == closest and quality.size < smallest) then
				closest = quality.level
				smallest = quality.size
				host = machine
			end
		end
		if (closest ~= NOT_CONNECTED and host ~= NOT_CONNECTED) then
			level = closest + 1
			connector = host
			qualities = {}
			send_msg(build_type_msg("accept", 0), connector)
			logging.debug("accepted connection with " .. connector.. ", level is " .. level)
			print("Accepted connection with " .. connector.. ", level is " .. level)
			reset_check()
			connecting = false
		else
			last_connect = get_time()
			print("No good connections found...")
			qualities = {}
			connecting = false
		end
	end
end

function disconnect()
	for i, ID in ipairs(clients) do
		send_msg(build_type_msg("disconnect", 0), ID)
	end
	print("Connection with " .. connector .. " lost!")
	connector = NOT_CONNECTED
	level = NOT_CONNECTED
	clients = {}
	last_checked = -1
end
-- CONNECT ---------------------------------------------------------------------------------------------------------------
-- FORWARD ---------------------------------------------------------------------------------------------------------------
function send_ack(originator, msg_id)
	logging.debug("sending ack of "..resp.." to " .. originator)
	logging.debug("type of originator is " .. type(originator))
	logging.debug("to_number of originator is ".. tonumber(originator))
	send_msg(build_type_msg("ack", msg_id), tonumber(originator))
end

function build_fwd_res(msg_id)
	local fwd_res = {}
	fwd_res.content = {}
	fwd_res.content.me = SELF_ID
	fwd_res.content.parent = connector
	fwd_res.sID = msg_id
	fwd_res.sType = "res"
	return fwd_res
end

function forward_msg(msg)
	logging.debug("forwarding message")
	logging.debug("msg stype is " .. msg.sType)
	logging.debug("msg id is " .. msg.sID)
	logging.debug("msg content is " .. binary.itstring(msg.content))
	for i, ID in ipairs(clients) do
		send_msg(msg, ID)
	end
end

function do_forwarding(msg)   -- change it to just instantly send back all 'res' requests, no matter the context
	logging.debug("starting a forward of a msg with id " .. msg.sID)    -- the only function of an ack is updating the clients list
	logging.debug("sending ack YE beacuse of " .. binary.itstring(msg))
	if (msg.sSender == connector) then
		reset_check()
	else
		logging.error("RECEIVED A MESSAGE FROM SOMEONE RANDOM (recv="..msg.sSender..", conn="..connector..", msg="..binary.itstring(msg))
	end
	send_ack(msg.sSender, msg.sID)    -- acknowleding msg having been received
	timeouts[msg.sID] = get_time()
	awaiting_acks[msg.sID] = {}
	awaiting_resps[msg.sID]= {}
	binary.ginsert_all(awaiting_acks[msg.sID], clients)
	binary.ginsert_all(awaiting_resps[msg.sID], clients)
	forward_msg(msg)
	--table.insert(recvd_msgs, msg.sID)
	if (binary.gsize(awaiting_acks[msg.sID]) == 0) then   -- no res's to pass along
		binary.remove_by_key(awaiting_acks, msg.sID)   -- no longer waiting for acks from this message
		binary.remove_by_key(awaiting_resps, msg.sID)
		binary.remove_by_key(timeouts, msg.sID)				-- erase TIMEOUT timer
		if (connector ~= NOT_CONNECTED) then
		send_msg(build_fwd_res(msg.sID), connector)
		end
	end
end

-- FORWARD ---------------------------------------------------------------------------------------------------------------


function proc_msgs()
	while (keep) do

		local msg=binary.pop_left(msg_q)
		if (not msg) then 
			fails = fails+1
		end
		logging.debug("msg_q: " .. binary.itstring(msg_q))
		if (msg and msg.sID) then   -- guarantee that the msg has an ID, ie. was part of our system
			fails = 0
			-- CONNECT SECTION -------------------------------------------------------------------------------------------
			if (msg.sType == "accept") then			-- add to clients
				binary.ginsert(clients, msg.sSender)
				if (connector ~= NOT_CONNECTED) then
					send_msg(build_type_msg("new", msg.sSender), connector)
				end
				print("Accepted new client " .. msg.sSender .. "!")
			elseif (msg.sType == "connect") then 	-- send connection details
				offer_connection(msg.sID, msg.sSender)
			elseif (msg.sType == "offer") then		-- is this the best possible connection?
				proc_offer(msg.content, msg.sSender)
			elseif (msg.sType == "new") then
				if (connector ~= NOT_CONNECTED) then
					send_msg(msg, connector)
				end
			-- CONNECT SECTION -------------------------------------------------------------------------------------------
			-- FORWARD SECTION -------------------------------------------------------------------------------------------
			elseif (msg.sType == "ack") then		-- yup, this client got your message
				logging.debug("Got an ACK from " .. msg.sSender)
				logging.debug("awaiting_acks before: "..binary.itstring(awaiting_acks))
				binary.gemove(awaiting_acks[msg.sID], msg.sSender)
				logging.debug("awaiting_acks after: "..binary.itstring(awaiting_acks))
				if (binary.gsize(awaiting_acks[msg.sID]) == 0	) then
					logging.debug("done waiting for acks")
					logging.debug("before awaiting_acks remove_key: " .. binary.itstring(awaiting_acks))
					binary.remove_by_key(awaiting_acks, msg.sID)   -- no longer waiting for acks from this message
					logging.debug("before awaiting_acks remove_key: " .. binary.itstring(awaiting_acks))
					binary.remove_by_key(timeouts, msg.sID)				-- erase TIMEOUT timer
				end
			elseif (msg.sType == "res") then		-- this is the result from my children, im just passing it along back to control (through my connector)
				logging.debug("Got a res from " .. msg.sSender)
				logging.debug("awaiting_resps before: " .. binary.itstring(awaiting_resps))
				binary.gemove(awaiting_resps[msg.sID], msg.content.me)   -- every resp has content={me=SELF_ID, parent=connector}
				if (connector ~= NOT_CONNECTED) then
					send_msg(msg, connector)
				end
				logging.debug("awaiting_resps after: " .. binary.itstring(awaiting_resps))
				if (binary.gsize(awaiting_resps[msg.sID]) == 0) then
					binary.remove_by_key(awaiting_resps, msg.sID)   -- no longer waiting for acks from this message
					send_msg(build_fwd_res(msg.sID), connector) 	-- now that we have heard from all clients, lets send our res back to connector
				end
			elseif (msg.sType == "disconnect") then
				disconnect()
			-- FORWARD SECTION -------------------------------------------------------------------------------------------
			-- CHECK SECTION ---------------------------------------------------------------------------------------------
			elseif (msg.sType == "check") then
				if (contains(clients, msg.sSender)) then
					send_msg(build_type_msg("affirm", 0), msg.sSender)
				else
					send_msg(build_type_msg("affirm", 0), msg.sSender)
					binary.ginsert(clients, msg.sSender) 	-- renew connection that I thought had expired
				end
			elseif (msg.sType == "affirm") then
				reset_check()
			-- CHECK SECTION ---------------------------------------------------------------------------------------------
			elseif (msg.sType == "fs") then
				fs_fname = msg.content.name
				print("received filename " .. fs_fname)
				print("received file content")
				fs_data = msg.content.data
				local f = fs.open(fs_fname, "w")
				f.write(fs_data)
				f.close()
				do_forwarding(msg)
			elseif (msg.content == "break") then
				keep=false
				do_forwarding(msg)
			elseif (msg.sType == "find") then
				do_forwarding(msg)
			else 
				shell.run(msg)
				do_forwarding(msg)
			end
		end
		-- logging.debug("Doing CONNECT checks")
		-- logging.debug("get_time()="..get_time())
		-- logging.debug("last_checked="..last_connect)
		-- logging.debug("diff="..(get_time()-last_connect))
		-- logging.debug("check_interval="..connect_interval)
		-- logging.debug("msg_q size="..binary.gsize(msg_q))
		-- logging.debug("ids_asked size="..binary.gsize(ids_asked))
		-- logging.debug("connecting="..tostring(connecting))
		-- logging.debug("level="..level)


		if (level == NOT_CONNECTED and binary.gsize(ids_asked) == 0 and (get_time()-last_connect) > connect_interval) then	-- ie. NOT CONNECTED
			ids_asked = send_connects()
			connect_time = get_time()
			connect_interval = 1 + get_rand()%10   -- [1,10] rand int
			connecting = true
		end

		if (connecting) then
			maybe_accept()
		end


		if (binary.gsize(timeouts) ~= 0 and binary.gsize(msg_q) == 0) then   -- handle timeouts (if for some msg they take longer than 30s to ACK, consider them timed out and remove them from clients list)
			local bad_ones = {}
			for m_id, m_time in pairs(timeouts) do 
				if ((get_time() - m_time) > TIMEOUT) then
					table.insert(bad_ones, m_id)
					for i, ID in ipairs(awaiting_acks[m_id]) do
						binary.gemove(clients, ID)
						send_msg(build_type_msg("disconnect", 0), ID)   -- send disconnect just in case its actually still in range, to notify that it wont be getting serviced anymore
					end
				end
			end
			for i, m_id in ipairs(bad_ones) do    -- no longer need to wait for requests that have timed out
				binary.remove_by_key(timeouts, m_id)
				binary.remove_by_key(awaiting_acks, m_id)
				send_msg(build_fwd_res(msg.sID), connector) 	-- now that we have heard from all clients, lets send our res back to connector
			end
		end
		-- logging.debug("Doing CHECK checks")
		-- logging.debug("connector="..connector)
		-- logging.debug("get_time()="..get_time())
		-- logging.debug("last_checked="..last_checked)
		-- logging.debug("diff="..(get_time()-last_checked))
		-- logging.debug("check_interval="..check_interval)
		-- logging.debug("msg_q size="..binary.gsize(msg_q))
		if (connector ~= NOT_CONNECTED and (get_time() - last_checked) > check_interval) then
			send_msg(build_type_msg("check", 0), connector)
			reset_check()
			checked_time = get_time()
		end

		if (connector ~= NOT_CONNECTED and (get_time() - checked_time) > TIMEOUT and binary.gsize(msg_q) == 0) then
			disconnect()
		end

		if (fails > 5) then   -- if dont receive a message for awhile, then go into sleep mode for 5 secondd
			os.sleep(DELAY)
		end

	end
end

function accumulate_msgs()
	while (keep) do
		local _id,_msg=rednet.receive()
		if (_msg) then
			_msg.sSender = _id    -- so every message is signed by the sender
			binary.push_right(msg_q,_msg)
		end
	end
end

function start()
	parallel.waitForAll(accumulate_msgs, proc_msgs)
end

function fallback(err)
	print(err)
	logging.close()
end


-- PATH IS:	CONTROL <-> CONNECTOR <-> SELF <-> CLIENTS

-- CONNECT -- 
level = NOT_CONNECTED
connector = NOT_CONNECTED
clients = {}
ids_asked = {}
qualities = {}
connect_time = -1
last_connect = -1
connect_interval = -1
connecting = false

-- FORWARD -- 
awaiting_acks = {}
awaiting_resps = {}
timeouts = {}

 --CHECK
last_checked = -1
checked_time = -1
check_interval = CHECK


msg_q=binary.queue_new()
fails=0
keep=true
name=register()
--recvd_msgs={}
--forwarding = {}
--fwd_addr = {}
--forwarded_to={}
--forward_success={}
--forward_resps = {}
math.randomseed(tonumber(get_rtime())*100000000000000)

xpcall(start, fallback)
print("goodbye")
rednet.unhost("child", name)
rednet.close("right")
logging.close()
