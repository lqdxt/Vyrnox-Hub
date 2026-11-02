local UNC = {}

UNC.Functions = {
 getgenv = {"getgenv"},
 getrenv = {"getrenv"},
 getgc = {"getgc"},
 getnilinstances = {"getnilinstances"},
 getrawmetatable = {"getrawmetatable"},
 setreadonly = {"setreadonly"},
 getnamecallmethod = {"getnamecallmethod"},
 newcclosure = {"newcclosure"},
 hookfunction = {"hookfunction", "replaceclosure"},
 loadstring = {"loadstring"},
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
  "getgenv",
  "loadstring",
  "getrawmetatable",
  "getnamecallmethod",
 },
 ["Monochrome"] = {
  "getgenv",
  "loadstring",
 },
 ["The Rake REMASTERED"] = {
  "getgenv",
  "loadstring",
  "getgc",
  "getrenv",
  "getnilinstances",
  "getrawmetatable",
  "setreadonly",
  "newcclosure",
  "hookfunction",
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
