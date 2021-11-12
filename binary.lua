-------------------------------------------------------QUEUE STRUCTURE DEFINITIONS---------------------------------


function queue_new()
	return {left=1, right=0}
end

function push_left(q, val)
	local left=q.left-1
	q.left = left
	q[left] = val
end

function push_right(q, val)
	local right=q.right+1
	q.right = right
	q[right] = val
end

function pop_left(q)
	if ((q.right-q.left) < 0 ) then return nil end
	local ret = q[q.left]
	q[q.left] = nil
	local left = q.left
	while ((not q[left]) and left~=q.right) do
		left = left + 1
	end
	if (not q[left]) then
		left = left + 1
	end
	q.left = left
	return ret
end

function pop_right(q)
	if ((q.right-q.left) < 0 ) then return nil end
	local ret = q[q.right]
	q[q.right] = nil
	local right = q.right
	while ((not q[right]) and right~=q.left) do
		right = right - 1
	end
	q.right = right
	return ret
end

function queue_insert(q, idx, val)
	if (idx > q.right) then
		q.right = idx
	elseif (idx < q.left) then
		q.left = idx
	elseif (not q[idx]) then  -- do nothing
	elseif ((q.right-idx) > (idx-q.left)) then  -- its easier to add it to the left
		for i=q.left,idx,1 do
			if (q[i]) then
				q[i-1] = q[i]
			end
		end
		q.left = q.left - 1
	else 
		for i=q.right,idx,-1 do
			q[i+1] = q[i]
		end
		q.right = q.right + 1
	end
	q[idx] = val
end

function qsize(q)
	return q.right-q.left+1
end

----------------------------------------------------QUEUE BINARY OPERATIONS----------------------------------------------------------

function qstring(q)
	str = "{"
	for i=q.left,q.right,1 do
		if (q[i]) then
			-- if (i<q.right) then str = str .. i .. "=" .. q[i] .. ", "
			-- else str = str .. i .. "=" .. q[i] end
			if (i<q.right) then str = str .. q[i] .. ", "
			else str = str .. q[i] end
		end
	end
	if (string.len(str) ~= 1) then
		str = str .. ", left="..q.left
		str = str .. ", right="..q.right
	else
		str = str .. "left="..q.left
		str = str .. ", right="..q.right
	end
	str = str .. "}"
	return str
end

function qrint(q)
	print(qstring(q))
end

function _qindex(tbl, val, lo, hi, old_mid)  -- with indices that potentially dont exist
	local mid=math.floor((lo+hi)/2)
	local left=mid
	local right=mid
	while (not tbl[left] and left>tbl.left) do left = left-1 end  -- get nearest idxs
	while (not tbl[right] and right<tbl.right) do right = right+1 end
	if (old_mid and mid == old_mid) then
		if (val >= tbl[hi]) then
			return mid+2
		elseif (val > tbl[lo]) then
			return mid+1
		else
			return mid-1
		end
	end
	if (val < tbl[left]) then
		return _qindex(tbl, val, lo, left, left)
	elseif (val > tbl[right]) then
		return _qindex(tbl, val, right, hi, right)
	else
		return right
	end
end

function qindex(tbl, val)
	if (qsize(tbl)==0) then return tbl.right end
	return _qindex(tbl, val, tbl.left, tbl.right, nil)
end

function qinsert(tbl, val)
	if (type(tbl) ~= "table") then tbl={} end
	idx = qindex(tbl, val)
	queue_insert(tbl, idx, val)
end

function qemove(tbl, val)
	local idx = qindex(tbl, val)
	if (idx > tbl.right) then idx=tbl.right end

	local left = idx-1
	local right = idx
	while (not tbl[left] and left>tbl.left) do left = left-1 end  -- get nearest idxs
	while (not tbl[right] and right<tbl.right) do right = right+1 end
	if (tbl[left] and tbl[left] == val) then
		tbl[left] = nil
		idx = left
	elseif (tbl[right] and tbl[right] == val) then
		tbl[right] = nil
		idx = right
	end

	while (not tbl[tbl.left] and tbl.left~=tbl.right) do
		tbl.left = tbl.left + 1
	end
	while (not tbl[tbl.right] and tbl.right~=tbl.left) do
		tbl.right = tbl.right - 1
	end
end

function qinsert_all(tbl, new_vals)
	if (type(tbl) ~= "table") then tbl={} end
	for k, val in pairs(new_vals) do
		if (type(k) == "number") then
			where = qindex(tbl, val)
			local left = idx-1
			local right = idx
			while (not tbl[left] and left>tbl.left) do left = left-1 end  -- get nearest idxs
			while (not tbl[right] and right<tbl.right) do right = right+1 end
			if (tbl[left] and tbl[left] == val) then
			elseif (tbl[right] and tbl[right] == val) then 
			else queue_insert(tbl, where, val) end
		end
	end
end

------------------------------------------------BINARY NORMAL LISTS---------------------------------------------------------------

function _bindex(tbl, val, lo, hi, old_mid)  -- with indices that potentially dont exist
	mid=math.floor((lo+hi)/2)
	if (old_mid and mid == old_mid) then
		if (val >= tbl[hi]) then
			return mid+2
		elseif (val > tbl[lo]) then
			return mid+1
		else
			return mid
		end
	end
	if (val < tbl[mid]) then
		return _bindex(tbl, val, lo, mid, mid)
	elseif (val > tbl[mid]) then
		return _bindex(tbl, val, mid, hi, mid)
	else
		return mid
	end
end

function bindex(tbl, val)
	if (#tbl == 0) then return 1 end
	return _bindex(tbl, val, 1, #tbl, nil)
end

function binsert(tbl, val)
	if (type(tbl) ~= "table") then tbl={} end
	idx = bindex(tbl, val)
	if (idx > #tbl and #tbl ~= 0) then idx = #tbl+1 end
	table.insert(tbl, idx, val)
end

function bemove(tbl, val)
	idx = bindex(tbl, val)
	if (idx > #tbl) then idx = #tbl end
	if (tbl[idx] == val) then
		table.remove(tbl, idx)
	end
end

function binsert_all(tbl, new_vals)
	if (type(tbl) ~= "table") then tbl={} end
	for i, val in ipairs(new_vals) do
		where = bindex(tbl, val)
		if (where > #tbl and #tbl ~= 0) then where = #tbl+1 end
		if (tbl[where] ~= val) then
			table.insert(tbl, where, val)
		end
	end
end

function bstring(tbl)
	str = "{"
	if (not tbl) then return "{}" end
	for i, el in ipairs(tbl) do
		if (i<#tbl) then str = str .. el .. ", "
		else str = str .. el end
	end
	str = str .. "}"
	return str
end

function brint(tbl)
	print(bstring(tbl))
end

----------------------------------------------GENERIC-----------------------------------------------------------------------------------

function hash_vals(tbl)
	local vals={}
	for k,v in pairs(tbl) do
		table.insert(vals, v)
	end
	return vals
end

function hash_str(tbl)
	return bstring(hash_vals(tbl))
end


function itstring(tbl)
	--hackerman
	local file = fs.open("xcasoi1p2393jd", "w")
	file.write(tbl)
	file.close()
	local file2 = fs.open("xcasoi1p2393jd", "r")
	info = file2.readAll()
	file2.close()
	return info
end

function ginsert(tbl, val)
	if (tbl.right) then
		qinsert(tbl, val)
	else
		binsert(tbl, val)
	end
end

function gemove(tbl, val)
	if (tbl.right) then
		qemove(tbl, val)
	else
		bemove(tbl, val)
	end
end

function ginsert_all(tbl, vals)
	if (tbl.right) then
		qinsert_all(tbl, vals)
	else
		binsert_all(tbl, vals)
	end
end

function gsize(tbl)
	if (tbl.right) then
		cnt=0
		for i=tbl.left,tbl.right,1 do
			if (tbl[i]) then cnt = cnt + 1 end
		end
		return cnt
		--return qsize(tbl)
	else
		return #tbl
	end
end

function gstring(tbl)
	if (tbl.right) then
		return qstring(tbl)
	else
		return bstring(tbl)
	end
end

function grint(tbl)
	print(gstring(tbl))
end

function remove_by_key(tbl, key)
	local el = tbl[key]
	tbl[key] = nil
end




-- test = queue_new()
-- qrint(test)
-- t = pop_left(test)
-- print(t)
-- qrint(test)
-- push_right(test, 5)
-- qrint(test)
-- push_right(test, 6)
-- qrint(test)
-- push_right(test, 7)
-- qrint(test)
-- push_right(test, 10)
-- qrint(test)
-- print("########################")
-- t = pop_left(test)
-- qrint(test)
-- print(t)
-- t = pop_left(test)
-- qrint(test)
-- print(t)
-- t = pop_left(test)
-- qrint(test)
-- print(t)
-- t = pop_left(test)
-- qrint(test)
-- print(t)
-- t = pop_left(test)
-- qrint(test)
-- print(t)
-- print("####################################")
-- push_right(test, 99)
-- qrint(test)
-- push_right(test, -23)
-- qrint(test)
-- push_right(test, 45)
-- qrint(test)
-- push_right(test, 692)
-- qrint(test)
-- print("########################")


-- test = {}
-- ginsert(test, 24)
-- grint(test)
-- ginsert(test, 49)
-- grint(test)
-- ginsert(test, 23)
-- grint(test)
-- ginsert(test, 55)
-- new_test = {}
-- ginsert_all(new_test, test)
-- grint(test)
-- grint(new_test)

-- test = {-10, 1, 5, 8, 10, 12}
-- qinsert(test,6)
-- qrint(test)
-- brint(test)
-- test = new()
-- insert(test,test.right,3)
-- push_right(test,9)
-- insert(test,5,11)
-- push_right(test, 12)
-- insert(test, -5, 2)
-- push_left(test, 2)
-- insert(test, 3, 10)
-- qrint(test)
-- qinsert(test, 8)
-- qrint(test)
-- qinsert(test, -5)
-- qrint(test)
-- qinsert(test, 2)
-- qrint(test)
-- qinsert(test, 11)
-- qrint(test)
-- qinsert(test, 50)
-- qrint(test)
-- qinsert(test, -5500)
-- qrint(test)
-- print("askjdklasdjlkasdjklajdskljsdlk")
-- qemove(test, -5500)
-- qrint(test)
-- qemove(test, -5)
-- qrint(test)
-- qemove(test, 2)
-- qrint(test)
-- qemove(test, 2)
-- qrint(test)
-- qemove(test, 3)
-- qrint(test)
-- qemove(test, 8)
-- qrint(test)
-- qemove(test, 9)
-- qrint(test)
-- qemove(test, 50)
-- qrint(test)
-- qemove(test, 50)
-- qrint(test)
-- qinsert_all(test, {5, 6, 1, 2, 3, 4})
-- qrint(test)



-- binsert(test, 5)
-- brint(test)
-- binsert_all(test, {3})
-- tval = 11
-- table.insert(test, bindex(test, tval), tval)
-- brint(test)
-- binsert(test, 5)
-- brint(test)
-- bemove(test, 11)
-- bemove(test,-10)
-- bemove(test,12)
-- bemove(test, 5)
-- bemove(test, 5)
-- bemove(test, 8)
-- bemove(test, 10)
-- bemove(test, 1)
-- brint(test)
-- binsert(test, 5)
-- binsert_all(test, {5})
-- brint(test)

