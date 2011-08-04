dofile("dfusion/offsets_misc.lua")
STD_STRING=0
DWORD=1
WORD=2
BYTE=3

function GetTextRegion()
	local ranges=Process.getMemRanges()
	for k,v in pairs(ranges) do
		--for k2,v2 in pairs(v) do
		--	print(string.format("%d %s->%s",k,tostring(k2),tostring(v2)))
		--end
		--local num
		--num=0
		--if(v["read"])then num=num+1 end
		--if(v["write"])then	num=num+10 end
		--if(v["execute"]) then num=num+100 end
		--print(string.format("%d %x->%x %s %d",k,v["start"],v["end"],v.name,num))
		local pos=string.find(v.name,".text")
		if(pos~=nil) then
			return v;
		end
	end
	return nil
end
function GetRegionIn(pos)
	local ranges=Process.getMemRanges()
	for k,v in pairs(ranges) do
		--for k2,v2 in pairs(v) do
		--	print(string.format("%d %s->%s",k,tostring(k2),tostring(v2)))
		--end
		--local num
		--num=0
		--if(v["read"])then num=num+1 end
		--if(v["write"])then	num=num+10 end
		--if(v["execute"]) then num=num+100 end
		--print(string.format("%d %x->%x %s %d",k,v["start"],v["end"],v.name,num))
		if pos>=v.start and pos<=v["end"] then
			return v
		end
	end
	return nil
end
function unlockDF()
	local reg=GetTextRegion()
	reg["write"]=true
	Process.setPermisions(reg,reg)
end
function lockDF()
	local reg=GetTextRegion()
	reg["write"]=false
	Process.setPermisions(reg,reg)
end
-- engine bindings
engine=engine or {}
engine.peekd=Process.readDWord
engine.poked=Process.writeDWord
engine.peekb=Process.readByte
engine.pokeb=Process.writeByte
engine.peekw=Process.readWord
engine.pokew=Process.writeWord
engine.peekstr=Process.readCString
--engine.pokestr=Process.readCString
engine.peekarb=Process.read
engine.pokearb=Process.write


function engine.peek(offset,rtype)
	if type(rtype)=="table" then
		if rtype.off ==nil then
			return engine.peekpattern(offset,rtype)
		else
			return engine.peek(rtype.off+offset,rtype.rtype)
		end
	end
	if rtype==STD_STRING then
		return engine.peekstr(offset)
	elseif rtype==DWORD then
		return engine.peekd(offset)
	elseif rtype==WORD then
		return engine.peekw(offset)
	elseif rtype==BYTE then
		return engine.peekb(offset)
	else
		error("Invalid peek type")
		return 
	end
end
function engine.poke(offset,rtype,val)
	if type(rtype)=="table" then
		if rtype.off ==nil then
			return engine.pokepattern(offset,rtype,val)
		else
			return engine.poke(rtype.off+offset,rtype.rtype,val)
		end
	end
	if rtype==STD_STRING then
		return engine.pokestr(offset,val)
	elseif rtype==DWORD then
		return engine.poked(offset,val)
	elseif rtype==WORD then
		return engine.pokew(offset,val)
	elseif rtype==BYTE then
		return engine.pokeb(offset,val)
	else
		error("Invalid poke type:"..tostring(rtype))
		return 
	end
end
function engine.sizeof(rtype)
	if rtype==STD_STRING then
		error("String has no constant size")
		return
	elseif rtype==DWORD then
		return 4;
	elseif rtype==WORD then
		return 2;
	elseif rtype==BYTE then
		return 1;
	else
		error("Invalid sizeof type")
		return 
	end
end
function engine.peekpattern(offset,pattern)
	local ret={}
	for k,v in pairs(pattern) do
		--print("k:"..k.." v:"..type(v))
		if type(v)=="table" then
			ret[k]=engine.peek(offset+v.off,v.rtype)
			--print(k.." peeked:"..offset+v.off)
		else 
			ret[k]=v
		end
	end
	ret.__offset=offset
	return ret
end
function engine.pokepattern(offset,pattern,val)
	for k,v in pairs(pattern) do
		--print("k:"..k.." v:"..type(v))
		if type(v)=="table" then
			engine.poke(offset+v.off,v.rtype,val[k]) 
		end
	end
end


it_menu={}
it_menu.__index=it_menu
function it_menu:add(name,func)
	table.insert(self.items,{func,name})
end
function it_menu:display()
	print("Select choice (q exits):")
	for p,c in pairs(self.items) do
		print(p..")."..c[2])
	end
	local ans
	repeat
		local r
		r=io.stdin:read()
		if r=='q' then return end
		ans=tonumber(r)
		
		if ans==nil or not(ans<=table.maxn(self.items) and ans>0) then
			print("incorrect choice")
		end
		
	until ans~=nil and (ans<=table.maxn(self.items) and ans>0)
	self.items[ans][1]()
end
function MakeMenu()
	local ret={}
	ret.items={}
	setmetatable(ret,it_menu)
	return ret
end

function PrintPattern(loadedpattern)
	for k,v in pairs(loadedpattern) do
		if type(v)== "string" then
			print(k.." "..v)
		else
			print(string.format("%s %d inhex:%x",k,v,v))
		end
	end
end

function printPattern(pattern)
	local i=0;
	local names={}
	names[STD_STRING]="std_string (STD_STRING)"
	names[DWORD]=     "Double word     (DWORD)"
	names[WORD]=	  "Word             (WORD)"
	names[STD_STRING]="Byte             (BYTE)"
	ret={}
	for k,v in pairs(pattern) do
		if type(v)=="table" and v.off~=nil then
		
			if names[v.rtype]~=nil then
				lname=names[v.rtype]
			else
				if type(v.rtype)=="table" then
					lname="Table (prob subpattern)"
				else
					lname="Other"
				end
			end
			print(string.format("%d. %s is %s with offset %x",i,k,lname,v.off))
			table.insert(ret,k)
		else
			print(string.format("%d. %s",i,k))
		end
		i=i+1
	end
	return ret;
end
function editPattern(offset,pattern,name)
	if type(pattern[name].rtype)=="table" then
		if pattern[name].rtype.setval~=nil then
			print(string.format("%x",offset+pattern[name].off))
			local t=engine.peek(offset+pattern[name].off,pattern[name].rtype)
			print("Value is now:"..t:getval())
			print("Enter new value:")
			val=io.stdin:read()
			t:setval(val)
		else
			ModPattern(offset+pattern[name].off,pattern[name].rtype)
		end
		return
	end
	val=engine.peek(offset,pattern[name])
	print("Value is now:"..val)
	print("Enter new value:")
	if pattern[name].rtype==STD_STRING then
		val=io.stdin:read()
	else 
		val=tonumber(io.stdin:read())
	end
	engine.poke(offset,pattern[name],val)
end
function ModPattern(itemoffset,pattern)
	print("Select what to edit:")
	nm=printPattern(pattern)
	q=tonumber(io.stdin:read())
	if q~=nil and q<#nm then
		editPattern(itemoffset,pattern,nm[q+1])
	end
end

function findVectors()
	local text=GetTextRegion()
	local h=hexsearch(text.start,text["end"],0x8b,ANYBYTE,ANYDWORD,0x8b,ANYBYTE,ANYDWORD,0x2b,ANYBYTE)
	local pos=h:findall()
	local T={}
	for k,v in pairs(pos) do
		local loc1,loc2
		loc1=engine.peekd(v+2)
		loc2=engine.peekd(v+8)
		--print(string.format("%x - %x=%x",loc1,loc2,loc1-loc2))
		if(loc1-loc2==4) then
			if T[loc1-4]~=nil then
				T[loc1-4]=T[loc1-4]+1
			else
				T[loc1-4]=1
			end
		end
	end
	return T
end

function GetRaceToken(p) --actually gets token...
	local vec=engine.peek(offsets.getEx('CreatureGloss'),ptr_vector)
	local off=vec:getval(p)
	local crgloss=engine.peek(off,ptr_CrGloss)
	return crgloss.token:getval()
end
function BuildNameTable()
	local rtbl={}
	local vec=engine.peek(offsets.getEx('CreatureGloss'),ptr_vector)
	--print(string.format("Vector start:%x",vec.st))
	--print(string.format("Vector end:%x",vec.en))
	--local i=0
	for p=0,vec:size()-1 do
		local off=vec:getval(p)
		--print("First member:"..off)
		local name=engine.peek(off,ptt_dfstring)
		--print("Loading:"..p.."="..name:getval())
		rtbl[name:getval()]=p
		--i=i+1
		--if i>100 then
		--	io.stdin:read()
		--	i=0
		--end
	end
	return rtbl;
end
function BuildMaterialTable()
	local rtbl={}
	local vec=engine.peek(offsets.getEx('Materials'),ptr_vector)
	--print(string.format("Vector start:%x",vec.st))
	--print(string.format("Vector end:%x",vec.en))
	--local i=0
	for p=0,vec:size()-1 do
		local off=vec:getval(p)
		--print("First member:"..off)
		local name=engine.peek(off,ptt_dfstring)
		--print("Loading:"..p.."="..name:getval())
		rtbl[name:getval()]=p
		--i=i+1
		--if i>100 then
		--	io.stdin:read()
		--	i=0
		--end
	end
	return rtbl;
end
function BuildWordTables()
	local names={}
	local rnames={}
	local vector=engine.peek(offsets.getEx('WordVec'),ptr_vector)
for i =0,vector:size()-1 do
	local off=vector:getval(i)
	local n=engine.peekstr(off)
	names[i]=n
	rnames[n]=i
end
	return names,rnames
end
function ParseScript(file)
	
	io.input(file)
	f=""
	first=0
	nobraces=0
	function updFunction()
	if f~="" then
			first=0
			if nobraces==0 then
				f=f.."}"
			end
			nobraces=0
			print("Doing:"..f)
			assert(loadstring(f))()

			f=""
		end
	end
	while true do

      local line = io.read("*line")
      if line == nil then break end
	  if string.sub(line,1,2)==">>" then
		updFunction()
		if string.find(line,"%b()") then
		f=string.sub(line,3)
		nobraces=1
		else
		f=string.sub(line,3).."{"
		end
		--print(string.sub(line,3)..)
	  else
		if first~=0 then
			f=f..","
		else
			first=1
		end
		f=f..string.format('%q',line)
		
	  end
	
    end
	updFunction()
end
function ParseNames(path)
	local ret={}
	local ff=io.open(path)
	for n in ff:lines() do
		table.insert(ret,n)
	end
	return ret
end

function getxyz() -- this will return pointers x,y and z coordinates.
	local off=offsets.getEx("Xpointer") -- lets find where in memory its being held
	-- now lets read them (they are double words (or unsigned longs or 4 bits each) and go in sucesion
	local x=engine.peekd(off)
	local y=engine.peekd(off+4) --next is 4 from start
	local z=engine.peekd(off+8) --next is 8 from start
	--print("Pointer @:"..x..","..y..","..z)
	return x,y,z -- return the coords
end
function GetCreatureAtPos(x,y,z) -- gets the creature index @ x,y,z coord
	--local x,y,z=getxyz() --get 'X' coords
	local vector=engine.peek(offsets.getEx("AdvCreatureVec"),ptr_vector) -- load all creatures
	for i = 0, vector:size() do -- look into all creatures offsets
		local curoff=vector:getval(i) -- get i-th creatures offset
		local cx=engine.peek(curoff,ptr_Creature.x) --get its coordinates
		local cy=engine.peek(curoff,ptr_Creature.y) 
		local cz=engine.peek(curoff,ptr_Creature.z)
		if cx==x and cy==y and cz==z then --compare them
			return i --return index
		end
	end
	print("Creature not found!")
	return -1
	
end

dofile("dfusion/patterns.lua")
dofile("dfusion/patterns2.lua")
dofile("dfusion/itempatterns.lua")