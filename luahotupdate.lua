local HU = {}

function HU.AddFileFromHUList()
	package.loaded[HU.UpdateListFile] = nil
	local FileList = require (HU.UpdateListFile)
	HU.HUMap = {}
	for _, file in pairs(FileList) do
		for _, path in pairs(HU.FileMap[file]) do
			HU.HUMap[path.LuaPath] = path.SysPath  	
		end
	end
end

-- 根据新的文件生成函数的代码
function HU.BuildNewCode(FilePath, LuaPath)
	io.input(FilePath)
	local NewCode = io.read("*all")
	if HU.OldCode[FilePath] == NewCode then
		io.input():close()
		return
	end
	HU.OldCode[FilePath] = NewCode
	io.input(FilePath)  
	local chunk = "--[["..LuaPath.."]]"
	local LocalVar = {}
	local GlobalVar = {}
	local FunctionDeepth = 0
	local needend = 0
	local ReturnExist = false
	local IsInComment = false
	local FunctionType = {}  -- 0:global 1:local 2:table,3. anonymous
	local IsFirstLine = true
	for line in io.lines() do
		local OriginalLine = line
		line = string.gsub(line, "\\.", "")
		line = string.gsub(line, "\".-\"", "")
		if IsFirstLine then
			IsFirstLine = false		  		
		else 
			chunk = chunk.."\n"
		end
		if ReturnExist then chunk = chunk..line end
		line = string.gsub(line, "%-%-[^%[%]].*", "")
		if string.find(line, "--%[%[") then
			IsInComment = true
		end
		if IsInComment and string.find(line, "%]%]") then
			IsInComment = false
			line = string.gsub(line, "%-%-.*", "")
			line = string.gsub(line, ".*%]%]", "")
			OriginalLine = line
		end
		if not IsInComment then 
			if string.find(line, "^function$") or string.find(line, "[^%w]+function$") or string.find(line, "^function[^%w]+") or string.find(line,"[^%w]+function[^%w]+") then 
		  		local funtype = -1
		  		if string.find(line, "^local%s+.*=[^%w]*function") or string.find(line, "%s+local%s+.*=[^%w]*function") then 
		   			funtype = 3
		  		elseif string.find(line, "local%s+function") then 
		    		funtype = 1
		  		end
			  	FunctionDeepth = FunctionDeepth + 1 
			 	needend = needend + 1
			  	if funtype ~= 1 and funtype ~= 3 then
			    	local head, body, point, tail = string.match(OriginalLine, "(.*function%s+)([%w_]+)([:.])([%w_]+%(.*)")
			    	if point ~= nil and point ~= "" then
			      		local varnametemp = string.match(body,"[%w_]+")
				      	if LocalVar[varnametemp] then
				        	funtype = 2
				      	elseif GlobalVar[varnametemp] == true then
				        	LocalVar[varnametemp] = true
				        	chunk = chunk.."local "..varnametemp.." = {}"
				        	funtype = 2
				      	else
				       		funtype = 0
				      	end
			    	elseif FunctionDeepth == 1 then
			       		funtype = 0
			    	else
			       		funtype = 1
			    	end
			  	end
			  	table.insert(FunctionType, funtype)
			end
			if string.find(line, "^if$") or string.find(line, "[^%w_]+if$") or string.find(line, "^if[^%w_]+") or string.find(line,"[^%w_]+if[^%w_]+") then
			 	needend = needend + 1
			end     
			if string.find(line, "^do$") or string.find(line, "[^%w_]+do$") or string.find(line, "^do[^%w_]+") or string.find(line,"[^%w_]+do[^%w_]+") then
			  	needend = needend + 1
			end
			if FunctionDeepth == 0 and (string.find(line, "^return%s+") or string.find(line, "%s+return%s+")) then
			  	chunk = chunk..OriginalLine
			  	ReturnExist = true
			end

			if FunctionDeepth == 0 then
			  	local varnames = string.match(line, "^local%s+([^=]+)=?") or string.match(line, "%s+local%s+([^=]+)=?") 
			  	if varnames ~= nil  then
			    	varnames = string.gmatch(varnames, "[_%w]+")
			    	if varnames ~= nil then
				      	for name in varnames do
				        	OriginalLine = "local "..name.." = {}"
				        	LocalVar[name] = true
				        	chunk = chunk..OriginalLine
				      	end
			    	end
			 	else
			  		varnames = string.match(line, "^([%w_]+)%s*=") or string.match(line, "%s+([%w_]+)%s*=")
			  		if varnames ~= nil then
			  			GlobalVar[varnames] = true
			  		end
			  	end
			end

			if FunctionDeepth > 0 and ( FunctionType[1] == 2 or FunctionType[1] == 1 or FunctionType[1] == 3 ) then
			    chunk = chunk..OriginalLine
			end
			if string.find(line, "^end$") or string.find(line, "[^_%w]+end$") or string.find(line, "^end[^_%w]+") or string.find(line,"[^_%w]+end[^_%w]+") then
			  	needend = needend - 1
			  	if needend < FunctionDeepth then
			    	FunctionDeepth = FunctionDeepth - 1
			    	FunctionType[#FunctionType] = nil
			  	end
			end
		end
	end
	io.input():close()
	local NewFunction = loadstring(chunk)
	if type(NewFunction) == "function" then 
	  	return loadstring(chunk)()
	elseif HU.FailNotify then
	  	HU.FailNotify(FilePath.."有语法错误")  	
	  	HU.OldCode[FilePath] = ""
	end
end
-- 更新某文件里的所有的函数
function HU.UpdateAllFunction(FilePath, NewObject)
	local OldObject = package.loaded[FilePath]
	for ElementName, Element in pairs(NewObject) do
		if type(Element) == "function" then
			HU.UpdateTargetFunction(FilePath, NewObject, ElementName)
		end
	end 
	for ElementName, Element in pairs(OldObject) do
		if NewObject[ElementName] == nil then
			NewObject[ElementName] = Element
		end
	end
end
-- 更新目标函数
function HU.UpdateTargetFunction(FilePath, NewObject, FunctionName)
	local OldObject = package.loaded[FilePath]
	local OldFunction = OldObject[FunctionName]
	if OldFunction == nil then 
		OldObject[FunctionName] = NewObject[FunctionName] 
	else
		local OldFunc, NewFunc = HU.BuildNewFunc(OldObject, NewObject, FunctionName)
		HU.ChangedFuncList[#HU.ChangedFuncList + 1] = {OldFunc, NewFunc, FunctionName, OldObject}
	end
end
-- 设置新函数的环境变量与旧函数一致
function HU.CopyFunctionEnv(OldFunction, NewFunction)
	setfenv(NewFunction, getfenv(OldFunction))
end

function HU.UpdateRegistry(OldFunction, NewFunction)
	local registryTable = debug.getregistry()
	for k, v in pairs(registryTable) do
		if v == OldFunction then
			registryTable[k] = NewFunction
		end
	end
end

function HU.BuildNewFunc(OldObject, NewObject, FunctionName)
	local OldFunction, NewFunction = OldObject[FunctionName], NewObject[FunctionName]
	HU.UpdateUpvalue(OldFunction, NewFunction) 
	HU.CopyFunctionEnv(OldFunction, NewFunction)
	return OldFunction, NewFunction
end

-- 替换upvalue
function HU.UpdateUpvalue(OldFunction, NewFunction)
	local Visited = {}
	function fun(OldFunction, NewFunction)
		if Visited[NewFunction] ~= nil then return end
		Visited[NewFunction] = true
		local OldUpvalueMap = {}
		for i = 1, math.huge do
			local name, value = debug.getupvalue(OldFunction, i)
			if not name then break end
			OldUpvalueMap[name] = value
		end
		for i = 1, math.huge do
			local name, value = debug.getupvalue(NewFunction, i)
			if not name then break end
			if OldUpvalueMap[name] ~= nil then 
				if type(OldUpvalueMap[name]) ~= "function" or type(value) ~= "function"  then 
					debug.setupvalue(NewFunction, i, OldUpvalueMap[name])
				else
					fun(OldUpvalueMap[name], value)
					HU.ChangedFuncList[#HU.ChangedFuncList+1] = {OldUpvalueMap[name], value}
				end
			elseif _G[name] ~= nil then
				debug.setupvalue(NewFunction, i, _G[name])
			end
		end
	end
	fun(OldFunction, NewFunction)
end

function HU.UpdateOneFunction(FilePath, NewObject)
	local OldObject = package.loaded[FilePath]
	HU.UpdateUpvalue(OldObject, NewObject) 
	HU.CopyFunctionEnv(OldObject, NewObject)
	HU.ChangedFuncList[#HU.ChangedFuncList + 1] = {OldObject, NewObject}
end

-- 更新逻辑的主函数
function HU.HotUpdateCode()
	for LuaPath, SysPath in pairs(HU.HUMap) do
		local OldObject = package.loaded[LuaPath]
		if OldObject ~= nil then
			if type(OldObject) == "table" then
				local NewObject = HU.BuildNewCode(SysPath, LuaPath)
				if NewObject ~= nil and type(NewObject) == "table" then
					HU.UpdateAllFunction(LuaPath, NewObject) 
				end
			elseif type(OldObject) == "function" then
				local NewObject = HU.BuildNewCode(SysPath, LuaPath)
				if NewObject ~= nil and type(NewObject) == "function" then
					HU.UpdateOneFunction(LuaPath, NewObject)
				end
			else
				if HU.FailNotify then
					HU.FailNotify(LuaPath.."热更失败，返回的既不是函数也不是表")
				end
			end
		end
	end
	if #HU.ChangedFuncList > 0 then
		HU.Travel_G()
		HU.ChangedFuncList = {}
	end
	collectgarbage("collect")
end 

function HU.Travel_G()
	local visited = {}
	visited[HU.ChangedFuncList] = true
	local function f(t)
		if not t or visited[t] then return end
		visited[t] = true
		if type(t) == "function" then
		  	for i = 1, math.huge do
				local name, value = debug.getupvalue(t, i)
				if not name then break end
				f(value)
			end
		elseif type(t) == "table" then
			for k,v in pairs(t) do
				f(k)
				f(v)
				if type(v) == "function" or type(k) == "function" then
					for _, vv in ipairs(HU.ChangedFuncList) do
						if v == vv[1] then
							t[k] = vv[2]
						end
						if k == vv[1] then
							t[vv[2]] = t[k]
							t[k] = nil
						end
						if vv[3] == "HUDebug" then
							vv[3] = nil
							vv[4].HUDebug()
						end
					end
				end
			end
		end
	end
	f(_G)
	for _, v in ipairs(HU.ChangedFuncList) do
		HU.UpdateRegistry(v[1], v[2])
	end
end
-- 初始化文件的路径映射表
function HU.InitFileMap(RootPath)
	for _, rootpath in pairs(RootPath) do
		local file = io.popen("dir /S/B /A:A "..rootpath)
		io.input(file)
		for line in io.lines() do
	   		local FileName = string.match(line,".*\\(.*)%.lua")
	  	    if FileName ~= nil then
	            if HU.FileMap[FileName] == nil then
	            	HU.FileMap[FileName] = {}
	        	end
	        	local luapath = string.sub(line, #rootpath+2, #line-4)
				luapath = string.gsub(luapath, "\\", ".")
	        	table.insert(HU.FileMap[FileName], {SysPath = line, LuaPath = luapath})
	    	end
	    end
	    file:close()
	end
end
-- 初始化
function HU.Init(RootPath, UpdateListFile, FailNotify)
	HU.UpdateListFile = UpdateListFile
	HU.HUMap = {}
	HU.FileMap = {}
	HU.FailNotify = FailNotify
	HU.OldCode = {}
	HU.ChangedFuncList = {}
	HU.InitFileMap(RootPath)
end

function HU.Update()
	HU.AddFileFromHUList()
	HU.HotUpdateCode()
end

local function FindRootPath()
	local file = io.popen("echo %cd%")
	local str = file:read("*l")
	local basedir 
	if string.find(str,"Build\\Windows\\GameSrc\\Shell\\.*$") then
		basedir = string.gsub(str,"Build\\Windows\\GameSrc\\Shell\\.*$", "")
	else
		basedir = string.gsub(str,"[^\\]+$","")
		HU.FailNotify = nil
	end
	file:close()
	return {basedir.."resource\\artres\\media\\video"}
end

HU.Init(FindRootPath(), "debugger.hotupdatelist", STRING_UTIL.AddMessageTipByMsg)

HU.LastTime = os.clock()
function HU.Ticker()
	local nowtime = os.clock() 
	if os.clock() - HU.LastTime > 3 then
		HU.LastTime = nowtime
		HU.Update()
	end
end

return HU