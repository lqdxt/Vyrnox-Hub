local UNC = {}

UNC.Functions = {
 getgenv = {"getgenv"},
 getrenv = {"getrenv"},
 getreg = {"getreg"},
 getgc = {"getgc"},
 getnilinstances = {"getnilinstances"},
 getinstances = {"getinstances"},
 getloadedmodules = {"getloadedmodules"},
 getscripts = {"getscripts"},
 getscriptbytecode = {"getscriptbytecode", "dumpstring"},
 getscripthash = {"getscripthash"},
 getscriptclosure = {"getscriptclosure"},
 identifyexecutor = {"identifyexecutor", "getexecutorname"},
 loadstring = {"loadstring"},
 cloneref = {"cloneref"},
 compareinstances = {"compareinstances"},
 checkcaller = {"checkcaller"},
 islclosure = {"islclosure", "is_l_closure"},
 newcclosure = {"newcclosure"},
 setthreadidentity = {"setthreadidentity", "setidentity", "set_thread_identity"},
 getthreadidentity = {"getthreadidentity", "getidentity", "get_thread_identity"},
 setfpscap = {"setfpscap"},
 getrawmetatable = {"getrawmetatable"},
 setreadonly = {"setreadonly"},
 isreadonly = {"isreadonly"},
 hookmetamethod = {"hookmetamethod"},
 getnamecallmethod = {"getnamecallmethod"},
 setnamecallmethod = {"setnamecallmethod"},
 hookfunction = {"hookfunction", "replaceclosure"},
 getupvalue = {"getupvalue"},
 setupvalue = {"setupvalue"},
 getupvalues = {"getupvalues"},
 setupvalues = {"setupvalues"},
 getconstants = {"getconstants"},
 debug_info = {"debug.info"},
 getconnections = {"getconnections"},
 getcallbackvalue = {"getcallbackvalue"},
 request = {"request", "http_request", "syn.request", "http.request", "fluxus.request"},
 writefile = {"writefile"},
 readfile = {"readfile"},
 appendfile = {"appendfile"},
 isfile = {"isfile"},
 delfile = {"delfile"},
 listfiles = {"listfiles"},
 makefolder = {"makefolder"},
 delfolder = {"delfolder"},
 isfolder = {"isfolder"},
 fireclickdetector = {"fireclickdetector"},
 fireproximityprompt = {"fireproximityprompt"},
 sethiddenproperty = {"sethiddenproperty"},
 gethiddenproperty = {"gethiddenproperty"},
 replicatesignal = {"replicatesignal"},
 isnetworkowner = {"isnetworkowner"},
 gethui = {"gethui"},
 setclipboard = {"setclipboard", "toclipboard", "writeclipboard", "set_clipboard"},
 Drawing = {"Drawing"},
 queue_on_teleport = {"queue_on_teleport", "queueonteleport", "queueteleport"},
}

local function get_env()
 if type(getgenv) == "function" then
  local ok, env = pcall(getgenv)
  if ok and type(env) == "table" then return env end
 end
 if type(getfenv) == "function" then
  local ok, env = pcall(getfenv)
  if ok and type(env) == "table" then return env end
 end
 return _G
end

local function resolve(name)
 local env = get_env()
 local alts = UNC.Functions[name]
 if not alts then
  local ok, val = pcall(function() return env[name] end)
  if ok and val ~= nil then return val, name end
  return nil, nil
 end
 for _, alt in ipairs(alts) do
  if alt:find("%.") then
   local ok, val = pcall(function()
    local cur = env
    for part in alt:gmatch("[^%.]+") do
     if type(cur) ~= "table" and type(cur) ~= "userdata" then return nil end
     cur = cur[part]
    end
    return cur
   end)
   if ok and val ~= nil then return val, alt end
  else
   local ok, val = pcall(function() return env[alt] end)
   if ok and val ~= nil then return val, alt end
  end
 end
 return nil, nil
end

UNC.Resolve = resolve

function UNC.Check(list)
 if type(list) == "string" then list = {list} end
 local out = {supported = {}, resolved = {}, missing = {}}
 for _, name in ipairs(list) do
  local fn, resolvedName = resolve(name)
  if fn ~= nil then
   out.supported[name] = fn
   out.resolved[name] = resolvedName
  else
   table.insert(out.missing, name)
  end
 end
 return out
end

UNC.Requirements = {
 ["3008"] = {
  "getgenv", "getrawmetatable", "setreadonly", "isreadonly", "hookfunction",
  "newcclosure", "request",
  "makefolder", "isfolder", "readfile", "writefile", "listfiles", "delfile",
  "identifyexecutor", "setclipboard", "debug_info", "Drawing",
  "fireclickdetector", "fireproximityprompt",
  "replicatesignal", "getupvalue", "setupvalue",
 },
 ["Monochrome"] = {
  "getgenv", "getrawmetatable", "setreadonly", "isreadonly",
  "newcclosure", "request", "getgc", "getupvalues",
  "makefolder", "isfolder", "readfile", "writefile", "listfiles", "delfile",
  "identifyexecutor", "setclipboard", "debug_info", "Drawing", "gethui",
 },
 ["The Rake REMASTERED"] = {
  "getgenv", "getrawmetatable", "setreadonly", "isreadonly",
  "hookfunction", "hookmetamethod", "newcclosure",
  "getgc", "getupvalues", "setupvalue", "getconstants",
  "getrenv", "getnilinstances", "request",
  "setthreadidentity", "getthreadidentity",
  "makefolder", "isfolder", "readfile", "writefile", "listfiles", "delfile",
  "identifyexecutor", "setclipboard", "debug_info", "Drawing", "gethui",
  "fireclickdetector", "fireproximityprompt",
  "sethiddenproperty", "replicatesignal", "isnetworkowner",
 },
}

function UNC.Require(scriptName)
 local list = UNC.Requirements[scriptName]
 if not list then
  return {supported = {}, resolved = {}, missing = {}}
 end
 return UNC.Check(list)
end

return UNC
