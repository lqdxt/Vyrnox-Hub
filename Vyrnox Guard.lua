--[[
 Vyrnox Guard
 ------------
 if your executor does not support hooking it's own functions, this will not work
 place the loadstring:
 loadstring(game:HttpGet("https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/main/Vyrnox%20Guard.lua"))()
 in your executor's autoexec/Autoexecution folder so it runs on every game
 do NOT paste this entire file as you will miss updates (many are important)
 should load before any other script has a chance to execute
 load order matters: Vyrnox Guard can only catch what happens after it's active
 that said, you still shouldn't execute untrusted + obfuscated scripts blindly
]]

game:GetService("StarterGui"):SetCore("SendNotification", {
 Title = "Warning",
 Text = "Vyrnox Guard moved. Please use the lastest one as this will get removed soon.",
 Duration = 20
})

pcall(function()
 if setclipboard then
  setclipboard("loadstring(game:HttpGet(\"https://raw.githubusercontent.com/lqdxt/Vyrnox-Guard/main/Loader.lua\"))()")
 end
end)

local env = (type(getgenv) == "function" and getgenv()) or (type(getfenv) == "function" and getfenv()) or _G
local cf = env.clonefunction or env.clone_function or env.clonefunc or clonefunction or clone_function
local clone_func = function(fn) if type(fn) ~= "function" then return fn end if cf then local s, r = pcall(cf, fn) if s and type(r) == "function" then return r end end return fn end
local request_func = clone_func(env.request or env.http_request or (type(env.syn) == "table" and (env.syn.request or env.syn.http_request)) or (type(env.http) == "table" and env.http.request) or (type(env.fluxus) == "table" and env.fluxus.request) or request or http_request)
local is_func_hooked = clone_func(env.isfunctionhooked or env.ishookedfunction or env.is_hooked or env.is_function_hooked or env.is_hooked_function or (type(env.syn) == "table" and (env.syn.is_function_hooked or env.syn.is_hooked_function)) or isfunctionhooked or ishookedfunction) or nil
local hook_func = clone_func(env.hookfunction or env.detour_function or env.replace_function or env.replaceclosure or hookfunction or hookfunc)
local get_nil = clone_func(env.get_nil_instances or env.getnilinstances or (type(env.syn) == "table" and env.syn.getnilinstances) or getnilinstances)
local cclosure = clone_func(env.newcclosure or env.makecclosure or (type(env.syn) == "table" and env.syn.newcclosure) or newcclosure) or function(f) return f end
local spawn_func = clone_func((task and task.spawn) or env.spawn or spawn)
local wait_func = clone_func((task and task.wait) or env.wait or wait)
local hf = clone_func((type(env.crypt) == "table" and (env.crypt.sha256 or env.crypt.hash)) or env.sha256 or (type(env.hash) == "table" and env.hash.sha256) or sha256)
local hash_func = clone_func(hf and function(data) if type(env.crypt) == "table" and hf == env.crypt.hash then return env.crypt.hash(data, "sha256") end return hf(data) end)
local restore_func = clone_func(env.restorefunction or env.restorefunc or env.restorehook or env.unhookfunction or restorefunction)
if env.VyrnoxGuardEnabled then
 local alive = nil
 local liveRequest = env.request or env.http_request or (type(env.syn) == "table" and env.syn.request)
 if type(liveRequest) == "function" then
  local okReq, res = pcall(liveRequest, { Url = "http://127.0.0.1:1/vyrnox-canary", Method = "POST", Body = "_|WARNING:-DO-NOT-SHARE-THIS" })
  alive = okReq and type(res) == "table" and res.StatusCode == 403 and res.Body == '{"success":false,"error":"Blocked by Vyrnox Guard","status":403}'
 end
 if alive ~= false then error("script already exists?", 1) end
 pcall(warn, "[Vyrnox Guard] VyrnoxGuardEnabled was already set but no working guard answered. Likely spoofed.")
end
env.VyrnoxGuardEnabled = true

local Safe = {
 pcall = pcall, typeof = typeof, select = select, unpack = table.unpack, lower = string.lower,
 getnamecallmethod = env.getnamecallmethod or getnamecallmethod,
 checkcaller = env.checkcaller or checkcaller,
 setreadonly = clone_func(env.setreadonly or setreadonly),
 getrawmetatable = clone_func(env.getrawmetatable or getrawmetatable),
 Canary = false,
 Hidden = setmetatable({}, { __mode = "k" }),
}

local OriginalFunctions = {}
local HookedLiveFunctions = {}
local ReportRestoreBlocked
local RestoreFunctionBlocked = 0
local AddConsoleLine
local TriggerFileScan
local IsFileScanRunning
local ShowThreatNotification
local MarkStatsDirty

if is_func_hooked == nil then
 local registry = setmetatable({}, { __mode = "k" })
 if hook_func then
  env.hookfunction = function(target, hook)
   if type(target) == "function" then
    registry[target] = true
   end
   if type(hook) == "function" then
    registry[hook] = true
   end
   return hook_func(target, hook)
  end
 end
 is_func_hooked = function(fn: (...any) -> ...any): boolean
  if type(fn) ~= "function" then
   return false
  end

  if registry[fn] then
   return true
  end

  local get_info = (debug and debug.getinfo) or env.getinfo
  local is_lclosure = env.islclosure or (env.iscclosure and function(f) return not env.iscclosure(f) end)

  if get_info and is_lclosure then
   local info = get_info(fn)
   if info and is_lclosure(fn) and (info.what == "C" or info.source == "=[C]") then
    return true
   end
  end

  local get_upvalues = env.getupvalues or (debug and debug.getupvalues)
  if get_upvalues then
   local ups = get_upvalues(fn)
   if type(ups) == "table" and (ups.__hooked or ups.__original) then
    return true
   end
  end

  return false
 end
end

local function Console(msg_type, msg)
 if Safe.Canary then return end
 if AddConsoleLine then
  AddConsoleLine(msg_type, msg)
  return
 end
 pcall(function()
  local f = (msg_type == "warn") and warn or print
  f("[Vyrnox Guard] " .. tostring(msg))
 end)
end

local checkfunctions = function()
 local h = is_func_hooked
 local check = function(func, msg)
  if h(func) then
   Console("warn", msg)
  end
  if restore_func then
   pcall(function()
    restore_func(func)
   end)
  end
 end
 check(restore_func, "restorefunction was already hooked")
 check(request_func, "request was already hooked")
 check(hook_func, "hookfunction was already hooked")
end
checkfunctions()

local function PickChar(chartype: string): string
 if chartype == "Number" then
  return string.char(math.random(0x30, 0x39))
 elseif chartype == "Unicode" then
  local roll = math.random()
  local codepoint: number

  if roll < 0.35 then
   codepoint = math.random(0x21, 0x7e)
  elseif roll < 0.9 then
   repeat
    codepoint = math.random(0x80, 0xffff)
   until not (codepoint >= 0xd800 and codepoint <= 0xdfff)
  else
   codepoint = math.random(0x10000, 0x10ffff)
  end

  local ok, result = pcall(utf8.char, codepoint)
  if ok then
   return result
  else
   return "�"
  end
 end
 return string.char(math.random(0x21, 0x7e))
end

local function RandomString(chartype: string?, min: number?, num: number?): string
 local resolvedType = chartype or "Normal"
 local length = math.random(min or 10, num or 25)
 local parts = {}
 for i = 1, length do
  table.insert(parts, PickChar(resolvedType))
 end
 return table.concat(parts)
end

local function GuardedRestore(oldRestore, target)
 if HookedLiveFunctions[target] then
  RestoreFunctionBlocked = RestoreFunctionBlocked + 1
  if ReportRestoreBlocked then
   ReportRestoreBlocked()
  else
   Console("warn", "Tampering blocked on one of Vyrnox Guard's own hooks")
  end
  return
 end
 return oldRestore(target)
end

do
 Safe.RestoreGuards = {}
 Safe.Hidden[Safe.RestoreGuards] = true
 Safe.RestoreCanaryTarget = function() end
 HookedLiveFunctions[Safe.RestoreCanaryTarget] = true
 local names = { "restorefunction", "restorefunc", "restorehook", "unhookfunction", "restore_function", "restoreclosure" }
 local seenRestore = {}
 local function InstallRestoreGuard(label, getCurrent, setCurrent)
  local okG, live = pcall(getCurrent)
  if not okG or type(live) ~= "function" or seenRestore[live] then return end
  seenRestore[live] = true
  local oldRestore
  local guard = cclosure(function(target)
   return GuardedRestore(oldRestore, target)
  end)
  local hooked = false
  if hook_func then
   hooked = pcall(function() oldRestore = hook_func(live, guard) end) and type(oldRestore) == "function"
  end
  if hooked then
   OriginalFunctions[oldRestore] = true
   HookedLiveFunctions[live] = true
  else
   oldRestore = live
   pcall(setCurrent, guard)
   HookedLiveFunctions[guard] = true
   OriginalFunctions[live] = true
  end
  local rec = { name = label, getCurrent = getCurrent, setCurrent = setCurrent, guard = guard, hooked = hooked }
  Safe.Hidden[rec] = true
  table.insert(Safe.RestoreGuards, rec)
 end
 for _, n in ipairs(names) do
  InstallRestoreGuard(n, function() return env[n] end, function(v) env[n] = v end)
 end
 if type(env.syn) == "table" then
  for _, n in ipairs(names) do
   InstallRestoreGuard("syn." .. n, function() local o = env.syn; return o and o[n] end, function(v) local o = env.syn; if o then o[n] = v end end)
  end
 end
end
local old_getupvalue = (debug and debug.getupvalue) or getupvalue
local old_getupvalues = (debug and debug.getupvalues) or getupvalues

if old_getupvalue then
 local function secure_getupvalue(func, index)
  local name, val = old_getupvalue(func, index)
  if OriginalFunctions[val] then
   return name, nil
  end
  return name, val
 end

 if debug and debug.getupvalue then
  HookedLiveFunctions[debug.getupvalue] = true
  hookfunction(debug.getupvalue, secure_getupvalue)
 end
 if getupvalue then
  HookedLiveFunctions[getupvalue] = true
  hookfunction(getupvalue, secure_getupvalue)
 end
end

if old_getupvalues then
 local function secure_getupvalues(func)
  local names, values = old_getupvalues(func)
  if type(values) == "table" then
   for i, v in pairs(values) do
    if OriginalFunctions[v] then values[i] = nil end
   end
  end
  return names, values
 end

 if debug and debug.getupvalues then
  HookedLiveFunctions[debug.getupvalues] = true
  hookfunction(debug.getupvalues, secure_getupvalues)
 end
 if getupvalues then
  HookedLiveFunctions[getupvalues] = true
  hookfunction(getupvalues, secure_getupvalues)
 end
end

local old_getconstants = (debug and debug.getconstants) or getconstants
if old_getconstants then
 local function secure_getconstants(func)
  local constants = old_getconstants(func)
  if type(constants) == "table" then
   for i, v in pairs(constants) do
    if OriginalFunctions[v] then constants[i] = nil end
   end
  end
  return constants
 end

 if debug and debug.getconstants then
  HookedLiveFunctions[debug.getconstants] = true
  hookfunction(debug.getconstants, secure_getconstants)
 end
 if getconstants then
  HookedLiveFunctions[getconstants] = true
  hookfunction(getconstants, secure_getconstants)
 end
end

local old_getproto = (debug and debug.getproto) or getproto
if old_getproto then
 local function secure_getproto(func, index, activated)
  local result = old_getproto(func, index, activated)
  if type(result) == "table" then
   for i, v in pairs(result) do
    if OriginalFunctions[v] then result[i] = nil end
   end
  elseif OriginalFunctions[result] then
   return nil
  end
  return result
 end

 if debug and debug.getproto then
  HookedLiveFunctions[debug.getproto] = true
  hookfunction(debug.getproto, secure_getproto)
 end
 if getproto then
  HookedLiveFunctions[getproto] = true
  hookfunction(getproto, secure_getproto)
 end
end

local old_getprotos = (debug and debug.getprotos) or getprotos
if old_getprotos then
 local function secure_getprotos(func)
  local protos = old_getprotos(func)
  if type(protos) == "table" then
   for i, v in pairs(protos) do
    if OriginalFunctions[v] then protos[i] = nil end
   end
  end
  return protos
 end

 if debug and debug.getprotos then
  HookedLiveFunctions[debug.getprotos] = true
  hookfunction(debug.getprotos, secure_getprotos)
 end
 if getprotos then
  HookedLiveFunctions[getprotos] = true
  hookfunction(getprotos, secure_getprotos)
 end
end

do
 Safe.Hidden[OriginalFunctions] = true
 Safe.Hidden[HookedLiveFunctions] = true
 local function IsHidden(v)
  local t = type(v)
  if t == "function" then return OriginalFunctions[v] == true end
  if t == "table" then return Safe.Hidden[v] == true end
  return false
 end
 local function Strip(t)
  if type(t) ~= "table" then return t end
  local out, n, len = {}, 0, #t
  for i = 1, len do
   local v = t[i]
   if not IsHidden(v) then n = n + 1; out[n] = v end
  end
  for k, v in pairs(t) do
   if not (type(k) == "number" and k >= 1 and k <= len and k % 1 == 0) and not IsHidden(v) then
    out[k] = v
   end
  end
  return out
 end
 local seen = {}
 local function HookScanner(fn, post)
  if type(fn) ~= "function" or seen[fn] or not hook_func then return end
  seen[fn] = true
  local old
  local ok = pcall(function()
   old = hook_func(fn, cclosure(function(...)
    local r = old(...)
    return post(r, ...)
   end))
  end)
  if ok and old then
   OriginalFunctions[old] = true
   HookedLiveFunctions[fn] = true
  end
 end
 local plain = function(r) return Strip(r) end
 HookScanner(env.getgc or getgc, plain)
 HookScanner(debug and debug.getgc, plain)
 HookScanner(env.getreg or getreg, plain)
 HookScanner(env.filtergc or filtergc, function(r, _, _, returnOne)
  if returnOne then
   if IsHidden(r) then return nil end
   return r
  end
  return Strip(r)
 end)
end

local BlockedDomains = {
 "api.ipify.org", "api4.ipify.org", "api64.ipify.org", "ipify.org", "api.ipify.org?format=json",
 "icanhazip.com", "ipv4.icanhazip.com", "ipv6.icanhazip.com", "ipv4.text.icanhazip.com", "ipv6.text.icanhazip.com", "icanhazip.net",
 "checkip.amazonaws.com", "checkip.dyndns.org", "checkip.synology.com", "checkip.dns.he.net",
 "ipinfo.io", "ifconfig.me", "ifconfig.co", "ifconfig.io", "ifconfig.cc",
 "myexternalip.com", "ip.sb", "ident.me", "v4.ident.me", "v6.ident.me", "api.ident.me",
 "api.my-ip.io", "my-ip.io", "bot.whatismyipaddress.com", "whatismyipaddress.com", "whatismyip.com", "whatsmyip.net",
 "extreme-ip-check.com", "getmyip.co", "getmyip.org", "api.db-ip.com", "db-ip.com",
 "ip-whois.io", "ipwho.is", "ipwhois.app", "whatismyip.akamai.com", "api.myip.com", "myip.com",
 "myip.dnsomatic.com", "tnx.nl", "ip.nux.ro", "curlmyip.com", "ipecho.net",
 "ipapi.co", "ip-api.com", "ipapi.com", "freegeoip.app", "freeipapi.com",
 "showmyip.com", "cmyip.com", "ip4.me", "l2.io", "ip.anysrc.net",
 "ip.chinaz.com", "ip.cn", "ip.tool.la", "ip.taobao.com", "geoiptool.com",
 "myip.opendns.com", "iplocation.net", "check-my-ip.net", "checkmyip.com",
 "api.ipdata.co", "ipdata.co", "api.ipgeolocation.io", "ipgeolocation.io",
 "seeip.org", "api.seeip.org", "ipv4.seeip.org", "ipv6.seeip.org",
 "eth0.me", "api.bigdatacloud.net", "ipqualityscore.com", "api.ipqualityscore.com",
 "ipregistry.co", "api.ipregistry.co", "ipfind.io", "ipstack.com", "api.ipstack.com",
 "abstractapi.com", "ipgeolocation.abstractapi.com", "ip2location.com", "api.ip2location.com",
 "ip2location-io.com", "api.ip2location-io.com", "ip.tyk.nu", "ip.me", "ip.pe.kr",
 "grabify.link", "grabify.co", "grabify.org", "grabify.world", "ipv6.grabify.link",
 "iplogger.org", "iplogger.co", "iplogger.com", "iplogger.info", "iplogger.ru",
 "iplogger.cn", "iplogger.net", "iplogger.me", "iplogger.biz", "iplogger.tv", "iplogger.store",
 "2no.co", "yip.su", "ezstat.ru", "iplis.ru", "ipgrabber.ru", "ipgraber.ru", "02ip.ru",
 "bathtub.pics", "bmwforum.co", "catsnthing.com", "catsnthings.fun", "cheapcinema.club",
 "dateing.club", "foot.wiki", "fortnight.space", "fortnitechat.site", "fortnite.club",
 "gamergirl.pro", "gamertag.shop", "gaming-at-my.best", "gamingfun.me", "headshot.monster",
 "imagehost.pics", "imghost.pics", "joinmy.site", "leancoding.co", "locations.quest",
 "lovebird.guru", "maper.info", "myprivate.pics", "noodshare.pics", "otherhalf.life",
 "partpicker.shop", "photovault.pics", "pichost.pics", "picshost.pics", "progaming.monster",
 "screenshare.pics", "screenshot.best", "shhh.lol", "shrekis.life", "sportshub.bar",
 "stopify.co", "thisdomainislong.lol", "toldyouso.lol", "toldyouso.pics", "trulove.guru",
 "yourmy.monster", "iplog.co", "location.cyou", "mymap.icu", "mymap.quest", "mapss.icu",
 "map-s.online", "crypto-o.click", "cryp-o.online", "customer.autos", "account.beauty",
 "photospace.life", "mymassive.pics", "photovault.store", "imagehub.fun", "picturestash.mom",
 "clickthis.photo", "sharevault.cloud", "picshare.mom", "picshare.hair", "imagestash.pics",
 "xtube.chat", "myprivate.yachts", "screensnaps.top", "customersupport.click", "mypicparade.pics",
 "imagevault.cloud", "iptrackeronline.com", "tracemyip.com", "tracemyip.org", "blasze.tk", "blasze.com",
 "screenshot.click", "shorter.me",
 "mymassive.yachts", "stonks.boats", "stonks.fun", "toes.beauty", "barefoot.pics",
 "shareit.pics", "gamer.tattoo", "shipment.website", "sugma.mom", "yum.mom",
 "plz.life", "massive.mom", "massive.boats", "mymassive.store", "mymassive.top",
 "gamer.hair", "grabb.site", "grabify.icu", "grabifyicu.com", "iplist.ru",
 "wl.gl", "ed.tc", "bc.ax", "ps3cfw.com", "gyazo.nl",
 "goo.by", "ikwyd.com", "ip-trap.com", "ythingy.com", "cob.soy"
}

local WhitelistedDomains = {
 "roblox.com", "rbxcdn.com"
}

local HighVolumeTrustedDomains = {
 "generativelanguage.googleapis.com",
 "api.openai.com",
 "api.anthropic.com",
 "api.mistral.ai",
 "api.cohere.ai",
 "api.groq.com",
 "api.cerebras.ai",
 "openrouter.ai",
 "generativelanguage.google.com",
 "freeinference.org",
 "api.together.xyz",
 "api.fireworks.ai",
 "api.x.ai",
 "api.perplexity.ai",
 "api.deepseek.com",
 "api.replicate.com",
 "api-inference.huggingface.co",
 "api.ai21.com",
 "api.aleph-alpha.com",
 "api.writer.com",
 "api.openpipe.ai",
 "api.stability.ai",
 "api.elevenlabs.io",
 "api.assemblyai.com",
 "api.deepl.com",
 "integrate.api.nvidia.com",
 "gateway.ai.cloudflare.com",
 "api.hyperbolic.xyz",
 "api.runpod.io",
 "api.deepinfra.com",
 "api.novita.ai",
 "api.octoai.cloud",
 "api.sambanova.ai",
 "api.modal.com",
 "api.lepton.run",
}

local cookies = "_|WARNING:-DO-NOT-SHARE-THIS"
local BLOCKED_JSON_BODY = '{"success":false,"error":"Blocked by Vyrnox Guard","status":403}'
local BlockWebhooks = false
local cookiesHex = cookies:gsub(".", function(c) return string.format("%02x", c:byte()) end):lower()

local function ContainsDiscordToken(str)
 for userSeg, tsSeg, hmacSeg in str:gmatch("([%w_%-]+)%.([%w_%-]+)%.([%w_%-]+)") do
  if #userSeg >= 20 and #userSeg <= 30 and #tsSeg >= 5 and #tsSeg <= 8 and #hmacSeg >= 25 and #hmacSeg <= 30 then
   return true
  end
 end
 local mfaMatch = str:match("mfa%.[%w_%-]+")
 if mfaMatch and #mfaMatch >= 24 then
  return true
 end
 return false
end

local function ContainsJwtToken(str)
 return str:find("eyJ[%w_%-]+%.[%w_%-]+%.[%w_%-]+") ~= nil
end

local ChangelogData = {
 {
  version = "1.3",
  date = "2026-11-07",
  changes = {
   "Significantly improved anti tampering.",
  },
 },
 {
  version = "1.2",
  date = "2026-11-03",
  changes = {
   "Other tiny changes. More animations.",
   "Added \"Protect Clipboard\": warns when a script copies a link that looks like a fake Roblox site (roblox.com.bz, robIox.com, roblox-support.net...). Has a \"Block\" sub toggle (off by default) to stop the copy instead of just warning, and a \"Rate Limit\" sub toggle (on by default) that stops clipboard spam (more than 5 copies in 2 seconds).",
   "Expandable toggles now have a caret next to the toggle pill. Click it to open or close the sub options. Right click and long press won't longer work.",
   "Added \"Protect Chat\": blocks executor-made chat sends so a script can't spam chat as you. Needs Protect Metatable.",
   "Protect Webhooks now covers far more than just discord: Telegram bots, Slack, Microsoft Teams/Power Automate, Google Chat, Guilded, etc.",
   "Added \"Block Big Files\" sub toggle under Protect Filesystem: blocks writefile/appendfile when the resulting file would go over the size limit (10MB by default).",
   "Added \"Whitelisted Links\": add any link or domain (like httpbin.org) with the + button and Vyrnox Guard removes all protections from it. Remove an entry with its x button.",
   "Removed the command bar because it was just useless. The log, events and hook status functions are now buttons under the console.",
  },
 },
 {
  version = "1.1",
  date = "2026-09-19",
  changes = {
   "Fixed some bugs.",
   "Fake IP: your real IP is swapped for a random IPv4/IPv6 address in outgoing request URLs, bodies, and headers.",
   "Added a \"Block\" sub toggle under Protect Webhooks (on by default). Turning it off still detects and logs webhook exfiltration attempts. You can also pair it with Fake IP if its off.",
   "Better startup against tampering.",
   "Added optional Cloud Reputation URL checking against a hosted lookup service (off by default).",
   "Can now catch IP logger responses by their JSON shape (lat/long, ISP, ASN...) and by suspicious IP forwarding headers, not just blocklisted content.",
   "Toggles can now have expandable sub options (long press or right click a toggle).",
   "Added a Changelog tab.",
  },
 },
 {
  version = "1.0",
  date = "2026-08-29",
  changes = {
   "Initial public release of Vyrnox Guard.",
  },
 },
}

local BlockLog = {}
local function LogBlock(reason, hookName, url)
 if Safe.Canary then return end
 table.insert(BlockLog, { time = os.time(), reason = reason, hook = hookName, url = url })
 if MarkStatsDirty then MarkStatsDirty() end
 if ShowThreatNotification then
  ShowThreatNotification(reason)
 end
end

local EventLog = {}
local function LogEvent(kind, detail, severity)
 severity = severity or "warn"
 table.insert(EventLog, { time = os.time(), kind = kind, detail = detail, severity = severity })
 if MarkStatsDirty then MarkStatsDirty() end
 if severity == "info" then
  Console("print", "[Event] " .. kind .. ": " .. tostring(detail))
 else
  Console("warn", "[Event] " .. kind .. ": " .. tostring(detail))
 end
end

ReportRestoreBlocked = function()
 LogBlock("Blocked restorefunction() call targeting a Vyrnox Guard hook", "restorefunction", "(local)")
end

local Stats = {
 SessionStart = os.time(),
 HttpRequestsSeen = 0,
}
local function CountHttpRequestSeen()
 if Safe.Canary then return end
 Stats.HttpRequestsSeen = Stats.HttpRequestsSeen + 1
 if MarkStatsDirty then MarkStatsDirty() end
end

local VyrnoxGuard = { Log = BlockLog, Events = EventLog, Stats = Stats }

function VyrnoxGuard.PrintLog()
 for i, entry in ipairs(BlockLog) do
  Console("print", string.format("[%d] %s | hook=%s | url=%s", i, entry.reason, tostring(entry.hook), tostring(entry.url)))
 end
end

function VyrnoxGuard.PrintEvents()
 for i, entry in ipairs(EventLog) do
  Console("print", string.format("[%d] (%s) %s | %s", i, entry.severity or "warn", entry.kind, tostring(entry.detail)))
 end
end

local ToggleChangeListeners = {}
function VyrnoxGuard.OnToggleChange(fn)
 if typeof(fn) == "function" then
  table.insert(ToggleChangeListeners, fn)
 end
end
local function NotifyToggleChange()
 for _, fn in ipairs(ToggleChangeListeners) do
  pcall(fn)
 end
end

function VyrnoxGuard.ToggleWebhooks(enabled)
 BlockWebhooks = (enabled == true)
 NotifyToggleChange()
 return BlockWebhooks
end

local BlockWebhooksHardBlock = true
function VyrnoxGuard.ToggleWebhookBlock(enabled)
 BlockWebhooksHardBlock = (enabled == true)
 NotifyToggleChange()
 return BlockWebhooksHardBlock
end

local ProtectCookies = true
local ProtectIP = true
local ProtectWebSocket = true
local ProtectDomains = true
local ProtectFilesystem = true
local BlockBigFiles = true
local MaxWriteFileSize = 10 * 1024 * 1024
local ProtectConsoleGui = true
local ProtectFingerprint = true
local ProtectTokens = true
local BlockForcedMessages = true
local ProtectCloudReputation = false
local CRE = ""
local FakeIPEnabled = false
local FakeIPAddress = nil

local function RandomIPv4()
 return string.format("%d.%d.%d.%d", math.random(1, 254), math.random(0, 255), math.random(0, 255), math.random(1, 254))
end

local function RandomIPv6()
 local groups = {}
 for i = 1, 8 do
  groups[i] = string.format("%04x", math.random(0, 0xffff))
 end
 return table.concat(groups, ":")
end

local function GetFakeIP()
 if not FakeIPAddress then
  FakeIPAddress = (math.random() < 0.5) and RandomIPv4() or RandomIPv6()
 end
 return FakeIPAddress
end

function VyrnoxGuard.ToggleFakeIP(enabled)
 FakeIPEnabled = (enabled == true)
 if FakeIPEnabled then
  FakeIPAddress = nil
  GetFakeIP()
 end
 NotifyToggleChange()
 return FakeIPEnabled
end

function VyrnoxGuard.ToggleCookies(enabled)
 ProtectCookies = (enabled == true)
 NotifyToggleChange()
 return ProtectCookies
end
function VyrnoxGuard.ToggleIP(enabled)
 ProtectIP = (enabled == true)
 NotifyToggleChange()
 return ProtectIP
end
function VyrnoxGuard.ToggleWebSocket(enabled)
 ProtectWebSocket = (enabled == true)
 NotifyToggleChange()
 return ProtectWebSocket
end
function VyrnoxGuard.ToggleDomains(enabled)
 ProtectDomains = (enabled == true)
 NotifyToggleChange()
 return ProtectDomains
end
function VyrnoxGuard.ToggleFilesystem(enabled)
 ProtectFilesystem = (enabled == true)
 NotifyToggleChange()
 return ProtectFilesystem
end
function VyrnoxGuard.ToggleConsoleGui(enabled)
 ProtectConsoleGui = (enabled == true)
 NotifyToggleChange()
 return ProtectConsoleGui
end
function VyrnoxGuard.ToggleFingerprint(enabled)
 ProtectFingerprint = (enabled == true)
 NotifyToggleChange()
 return ProtectFingerprint
end
function VyrnoxGuard.ToggleTokens(enabled)
 ProtectTokens = (enabled == true)
 NotifyToggleChange()
 return ProtectTokens
end
function VyrnoxGuard.ToggleForcedMessages(enabled)
 BlockForcedMessages = (enabled == true)
 NotifyToggleChange()
 return BlockForcedMessages
end
VyrnoxGuard.ProtectClipboard = true
VyrnoxGuard.BlockClipboard = false
VyrnoxGuard.RateLimitClipboard = true
function VyrnoxGuard.ToggleClipboardRateLimit(enabled)
 VyrnoxGuard.RateLimitClipboard = (enabled == true)
 NotifyToggleChange()
 return VyrnoxGuard.RateLimitClipboard
end
function VyrnoxGuard.ToggleClipboard(enabled)
 VyrnoxGuard.ProtectClipboard = (enabled == true)
 NotifyToggleChange()
 return VyrnoxGuard.ProtectClipboard
end
function VyrnoxGuard.ToggleClipboardBlock(enabled)
 VyrnoxGuard.BlockClipboard = (enabled == true)
 NotifyToggleChange()
 return VyrnoxGuard.BlockClipboard
end
function VyrnoxGuard.ToggleBigFiles(enabled)
 BlockBigFiles = (enabled == true)
 NotifyToggleChange()
 return BlockBigFiles
end
function VyrnoxGuard.SetMaxFileSizeMB(mb)
 mb = tonumber(mb)
 if not mb or mb <= 0 or mb > 1024 then
  Console("warn", "Max file size must be a number between 0 and 1024 (MB).")
  return false
 end
 MaxWriteFileSize = math.floor(mb * 1024 * 1024)
 NotifyToggleChange()
 return true
end
VyrnoxGuard.WhitelistedLinks = {}
function VyrnoxGuard.AddWhitelistedLink(raw)
 local entry = { raw = (typeof(raw) == "string") and raw:match("^%s*(.-)%s*$") or "" }
 table.insert(VyrnoxGuard.WhitelistedLinks, entry)
 NotifyToggleChange()
 return entry
end
function VyrnoxGuard.SetWhitelistedLink(entry, raw)
 if typeof(entry) ~= "table" then return false end
 entry.raw = (typeof(raw) == "string") and raw:match("^%s*(.-)%s*$") or ""
 NotifyToggleChange()
 return true
end
function VyrnoxGuard.RemoveWhitelistedLink(entry)
 for i, e in ipairs(VyrnoxGuard.WhitelistedLinks) do
  if e == entry then
   table.remove(VyrnoxGuard.WhitelistedLinks, i)
   break
  end
 end
 NotifyToggleChange()
end
function VyrnoxGuard.ToggleCloudReputation(enabled)
 ProtectCloudReputation = (enabled == true)
 NotifyToggleChange()
 return ProtectCloudReputation
end
function VyrnoxGuard.SetCloudReputationEndpoint(url, key)
 CRE = typeof(url) == "string" and url or ""
 NotifyToggleChange()
end

local function HasObfuscatedShapeName(name)
 if typeof(name) ~= "string" or name == "" then return false end
 local controlOrSpace = 0
 for i = 1, #name do
  local b = name:byte(i)
  if b < 32 or b == 32 or b == 127 then
   controlOrSpace = controlOrSpace + 1
  end
 end
 return controlOrSpace >= 4 and (controlOrSpace / #name) >= 0.5
end

local function AntiCheatPresent()
 local ok, result = pcall(function()
  local knownNames = {
   "adonis", "adonis_loader", "anti%-exploit", "anticheat", "anti_cheat",
   "acbypass", "hd admin", "kohl's admin", "hyra",
  }

  local function CheckInstanceName(name)
   if typeof(name) ~= "string" or name == "" then return false end
   if HasObfuscatedShapeName(name) then return true, "(obfuscated-name instance)" end
   local lname = name:lower()
   for _, marker in ipairs(knownNames) do
    if lname:find(marker) then return true, name end
   end
   return false
  end

  local containerNames = { "ReplicatedStorage", "StarterGui", "StarterPlayer", "Lighting", "ReplicatedFirst" }
  for _, cname in ipairs(containerNames) do
   local container = game:FindFirstChild(cname)
   if container then
    local okDesc, descendants = pcall(function() return container:GetDescendants() end)
    if okDesc then
     for _, inst in ipairs(descendants) do
      local bad, why = CheckInstanceName(inst.Name)
      if bad then return true, why end
     end
    end
   end
  end

  local NilInstanceScanCap = 2000
  if typeof(get_nil) == "function" then
   local okNil, nilInstances = pcall(get_nil)
   if okNil and typeof(nilInstances) == "table" then
    for i, inst in ipairs(nilInstances) do
     if i > NilInstanceScanCap then break end
     local okName, name = pcall(function() return inst.Name end)
     if okName then
      local bad, why = CheckInstanceName(name)
      if bad then return true, why end
     end
    end
   end
  end

  return false, nil
 end)
 if ok then return result end
 return true
end

local ProtectMetatable = not AntiCheatPresent()
local UserSetMetatableManually = false
function VyrnoxGuard.ToggleMetatable(enabled)
 ProtectMetatable = (enabled == true)
 UserSetMetatableManually = true
 NotifyToggleChange()
 return ProtectMetatable
end

local GuardFS = { Depth = 0, Folder = {"vyrnox", "guard"} }

function GuardFS.As(fn)
 return function(...)
  GuardFS.Depth = GuardFS.Depth + 1
  local r = table.pack(pcall(fn, ...))
  GuardFS.Depth = GuardFS.Depth - 1
  if not r[1] then error(r[2], 0) end
  return table.unpack(r, 2, r.n)
 end
end

function GuardFS.Resolve(path)
 local out = {}
 local normalized = string.lower((string.gsub(path, "\\", "/")))
 for seg in string.gmatch(normalized, "[^/]+") do
  seg = string.gsub(seg, "^%s+", "")
  seg = string.gsub(seg, "%s+$", "")
  if seg == "." then
  elseif seg == ".." then
   table.remove(out)
  else
   seg = string.match(seg, "^([^:]*)") or seg
   seg = string.gsub(seg, "[%. ]+$", "")
   if string.match(seg, "^vyrnox~%d+$") then seg = "vyrnox" end
   if string.match(seg, "^guard~%d+$") then seg = "guard" end
   if seg ~= "" then table.insert(out, seg) end
  end
 end
 return out
end

function GuardFS.IsInside(path)
 if typeof(path) ~= "string" then return false end
 local segs = GuardFS.Resolve(path)
 for i = 1, #segs - 1 do
  if segs[i] == GuardFS.Folder[1] and segs[i + 1] == GuardFS.Folder[2] then
   return true
  end
 end
 return false
end

function GuardFS.IsAncestor(path)
 if typeof(path) ~= "string" then return false end
 local segs = GuardFS.Resolve(path)
 local last = segs[#segs]
 return last == nil or last == "workspace" or last == GuardFS.Folder[1]
end

function GuardFS.Deny(fname, path)
 Console("warn", "Blocked unauthorized access to the Guard folder [Hook: " .. fname .. " -> " .. tostring(path) .. "]")
 LogBlock("Unauthorized access to Guard folder", fname, tostring(path))
end

local ConfigRoot = "Vyrnox"
local ConfigFolder = "Vyrnox/Guard"
local ConfigPath = "Vyrnox/Guard/config.json"

local function EnsureConfigFolders()
 if typeof(makefolder) ~= "function" or typeof(isfolder) ~= "function" then return end
 pcall(GuardFS.As(function()
  if not isfolder(ConfigRoot) then
   makefolder(ConfigRoot)
  end
  if not isfolder(ConfigFolder) then
   makefolder(ConfigFolder)
  end
 end))
end

EnsureConfigFolders()

local StatsStore = {
 Path = ConfigFolder .. "/stats.json",
 MaxReasons = 200,
 Dirty = false,
}

local function NewSavedStats()
 return { Blocked = 0, Events = 0, Http = 0, Since = os.time(), Reasons = {}, ReasonOrder = {} }
end
StatsStore.Saved = NewSavedStats()

function StatsStore.GetTotals()
 local saved = StatsStore.Saved
 local reasons, order = {}, {}
 for _, r in ipairs(saved.ReasonOrder) do
  reasons[r] = saved.Reasons[r]
  table.insert(order, r)
 end
 for _, entry in ipairs(BlockLog) do
  local r = entry.reason or "Unknown"
  if not reasons[r] then
   reasons[r] = 0
   table.insert(order, r)
  end
  reasons[r] = reasons[r] + 1
 end
 return {
  Blocked = saved.Blocked + #BlockLog,
  Events = saved.Events + #EventLog,
  Http = saved.Http + Stats.HttpRequestsSeen,
  Since = saved.Since,
  Reasons = reasons,
  ReasonOrder = order,
 }
end

function StatsStore.Persist()
 if typeof(writefile) ~= "function" then return false end
 local totals = StatsStore.GetTotals()
 local list, other = {}, 0
 for i, r in ipairs(totals.ReasonOrder) do
  if i <= StatsStore.MaxReasons then
   table.insert(list, { reason = r, count = totals.Reasons[r] })
  else
   other = other + totals.Reasons[r]
  end
 end
 if other > 0 then
  table.insert(list, { reason = "(other reasons)", count = other })
 end
 return (pcall(GuardFS.As(function()
  EnsureConfigFolders()
  writefile(StatsStore.Path, game:GetService("HttpService"):JSONEncode({
   Blocked = totals.Blocked,
   Events = totals.Events,
   Http = totals.Http,
   Since = totals.Since,
   Reasons = list,
  }))
 end)))
end

function StatsStore.Load()
 if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
 local ok, data = pcall(GuardFS.As(function()
  if not isfile(StatsStore.Path) then return nil end
  return game:GetService("HttpService"):JSONDecode(readfile(StatsStore.Path))
 end))
 if not ok or typeof(data) ~= "table" then return end

 local saved = NewSavedStats()
 saved.Blocked = math.max(0, math.floor(tonumber(data.Blocked) or 0))
 saved.Events = math.max(0, math.floor(tonumber(data.Events) or 0))
 saved.Http = math.max(0, math.floor(tonumber(data.Http) or 0))
 saved.Since = tonumber(data.Since) or saved.Since
 if typeof(data.Reasons) == "table" then
  for _, e in ipairs(data.Reasons) do
   if typeof(e) == "table" and typeof(e.reason) == "string" and tonumber(e.count) then
    if not saved.Reasons[e.reason] then
     saved.Reasons[e.reason] = 0
     table.insert(saved.ReasonOrder, e.reason)
    end
    saved.Reasons[e.reason] = saved.Reasons[e.reason] + math.floor(tonumber(e.count))
   end
  end
 end
 StatsStore.Saved = saved
end

function StatsStore.Reset()
 table.clear(BlockLog)
 table.clear(EventLog)
 Stats.HttpRequestsSeen = 0
 StatsStore.Saved = NewSavedStats()
 StatsStore.Dirty = false
 local ok = StatsStore.Persist()
 if typeof(writefile) ~= "function" or ok then
  Console("print", "Stats reset.")
  return true
 end
 Console("warn", "Stats were reset for this session but the saved stats file could not be updated.")
 return false
end

MarkStatsDirty = function()
 StatsStore.Dirty = true
end

StatsStore.Load()
if typeof(writefile) ~= "function" then
 Console("warn", "writefile is not supported in this environment, stats will not persist between sessions.")
end

spawn_func(function()
 while true do
  wait_func(5)
  if StatsStore.Dirty then
   StatsStore.Dirty = false
   StatsStore.Persist()
  end
 end
end)

VyrnoxGuard.SaveStats = StatsStore.Persist
VyrnoxGuard.ResetStats = StatsStore.Reset

local function SaveConfig()
 if typeof(writefile) ~= "function" then return end
 local ok = pcall(GuardFS.As(function()
  EnsureConfigFolders()
  local data = {
   ProtectCookies = ProtectCookies,
   ProtectIP = ProtectIP,
   ProtectWebSocket = ProtectWebSocket,
   ProtectDomains = ProtectDomains,
   ProtectFilesystem = ProtectFilesystem,
   BlockBigFiles = BlockBigFiles,
   MaxFileSizeMB = MaxWriteFileSize / (1024 * 1024),
   WhitelistedLinks = (function()
    local out = {}
    for _, e in ipairs(VyrnoxGuard.WhitelistedLinks) do
     if e.raw ~= "" then table.insert(out, e.raw) end
    end
    return out
   end)(),
   ProtectConsoleGui = ProtectConsoleGui,
   ProtectFingerprint = ProtectFingerprint,
   ProtectTokens = ProtectTokens,
   BlockForcedMessages = BlockForcedMessages,
   ProtectClipboard = VyrnoxGuard.ProtectClipboard,
   BlockClipboard = VyrnoxGuard.BlockClipboard,
   RateLimitClipboard = VyrnoxGuard.RateLimitClipboard,
   BlockWebhooks = BlockWebhooks,
   ProtectCloudReputation = ProtectCloudReputation,
   FakeIPEnabled = FakeIPEnabled,
   BlockWebhooksHardBlock = BlockWebhooksHardBlock,
   CRE = CRE,
  }
  writefile(ConfigPath, game:GetService("HttpService"):JSONEncode(data))
 end))
 if not ok then
  Console("warn", "Failed to save toggle configuration.")
 end
end

local function LoadConfig()
 EnsureConfigFolders()
 if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
 local ok, result = pcall(GuardFS.As(function()
  if not isfile(ConfigPath) then return nil end
  return game:GetService("HttpService"):JSONDecode(readfile(ConfigPath))
 end))
 if not ok or typeof(result) ~= "table" then return end

 if typeof(result.ProtectCookies) == "boolean" then VyrnoxGuard.ToggleCookies(result.ProtectCookies) end
 if typeof(result.ProtectIP) == "boolean" then VyrnoxGuard.ToggleIP(result.ProtectIP) end
 if typeof(result.ProtectWebSocket) == "boolean" then VyrnoxGuard.ToggleWebSocket(result.ProtectWebSocket) end
 if typeof(result.ProtectDomains) == "boolean" then VyrnoxGuard.ToggleDomains(result.ProtectDomains) end
 if typeof(result.ProtectFilesystem) == "boolean" then VyrnoxGuard.ToggleFilesystem(result.ProtectFilesystem) end
 if typeof(result.BlockBigFiles) == "boolean" then VyrnoxGuard.ToggleBigFiles(result.BlockBigFiles) end
 if typeof(result.MaxFileSizeMB) == "number" then VyrnoxGuard.SetMaxFileSizeMB(result.MaxFileSizeMB) end
 if typeof(result.WhitelistedLinks) == "table" then
  for _, raw in ipairs(result.WhitelistedLinks) do
   if typeof(raw) == "string" and raw ~= "" then
    table.insert(VyrnoxGuard.WhitelistedLinks, { raw = raw })
   end
  end
 end
 if typeof(result.ProtectConsoleGui) == "boolean" then VyrnoxGuard.ToggleConsoleGui(result.ProtectConsoleGui) end
 if typeof(result.ProtectFingerprint) == "boolean" then VyrnoxGuard.ToggleFingerprint(result.ProtectFingerprint) end
 if typeof(result.ProtectTokens) == "boolean" then VyrnoxGuard.ToggleTokens(result.ProtectTokens) end
 if typeof(result.BlockForcedMessages) == "boolean" then VyrnoxGuard.ToggleForcedMessages(result.BlockForcedMessages) end
 if typeof(result.ProtectClipboard) == "boolean" then VyrnoxGuard.ToggleClipboard(result.ProtectClipboard) end
 if typeof(result.BlockClipboard) == "boolean" then VyrnoxGuard.ToggleClipboardBlock(result.BlockClipboard) end
 if typeof(result.RateLimitClipboard) == "boolean" then VyrnoxGuard.ToggleClipboardRateLimit(result.RateLimitClipboard) end
 if typeof(result.BlockWebhooks) == "boolean" then VyrnoxGuard.ToggleWebhooks(result.BlockWebhooks) end
 if typeof(result.CRE) == "string" then VyrnoxGuard.SetCloudReputationEndpoint(result.CRE) end
 if typeof(result.ProtectCloudReputation) == "boolean" then VyrnoxGuard.ToggleCloudReputation(result.ProtectCloudReputation) end
 if typeof(result.FakeIPEnabled) == "boolean" then VyrnoxGuard.ToggleFakeIP(result.FakeIPEnabled) end
 if typeof(result.BlockWebhooksHardBlock) == "boolean" then VyrnoxGuard.ToggleWebhookBlock(result.BlockWebhooksHardBlock) end

 Console("print", "Loaded saved toggle configuration from " .. ConfigPath)
end

LoadConfig()
VyrnoxGuard.OnToggleChange(SaveConfig)

spawn_func(function()
 local ok_ui, ui_err = pcall(function()
  local TweenService = game:GetService("TweenService")
  local GuiService = game:GetService("GuiService")
  local Players = game:GetService("Players")
  local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
  local ExecutorGui = typeof(gethui) == "function" and gethui() or nil
  local CoreGui = game:GetService("CoreGui")
  local PlayerGui = player:WaitForChild("PlayerGui")

  local RED = Color3.fromRGB(214, 64, 64)
  local CALM = Color3.fromRGB(48, 196, 158)
  local BG_DARK = Color3.fromRGB(24, 24, 30)
  local PANEL_DARK = Color3.fromRGB(30, 30, 38)
  local TEXT_LIGHT = Color3.fromRGB(225, 225, 232)
  local TEXT_DIM = Color3.fromRGB(150, 150, 160)
  local KNOB_OFF = Color3.fromRGB(70, 70, 78)

  local function NewCorner(radius, parent)
   local c = Instance.new("UICorner")
   c.CornerRadius = UDim.new(0, radius)
   c.Parent = parent
   return c
  end

  local function NewStroke(parent, color, thickness, transparency)
   local s = Instance.new("UIStroke")
   s.Color = color or Color3.fromRGB(255, 255, 255)
   s.Thickness = thickness or 1
   s.Transparency = transparency or 0.85
   s.Parent = parent
   return s
  end

  local ScreenGui = Instance.new("ScreenGui")
  ScreenGui.Name = RandomString("Unicode")
  ScreenGui.DisplayOrder = 2147483647
  ScreenGui.ResetOnSpawn = false
  ScreenGui.IgnoreGuiInset = true
  ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

  local parented = false
  if ExecutorGui then
   parented = pcall(function()
    ScreenGui.Parent = ExecutorGui
   end)
  end
  if not parented then
   parented = pcall(function()
    ScreenGui.Parent = CoreGui
   end)
  end
  if not parented then
   ScreenGui.Parent = PlayerGui
  end

  local main = Instance.new("Frame")
  main.Name = "Main"
  main.AnchorPoint = Vector2.new(0.5, 0.5)
  main.Size = UDim2.new(0, 620, 0, 400)
  main.Position = UDim2.new(0.5, 0, 0.5, 0)
  main.BackgroundColor3 = BG_DARK
  main.BorderSizePixel = 0
  main.ClipsDescendants = true
  main.Visible = false
  main.Parent = ScreenGui
  NewCorner(14, main)
  NewStroke(main, Color3.fromRGB(255, 255, 255), 1, 0.9)

  local mainShadow = Instance.new("UIShadow")
  mainShadow.Color = Color3.fromRGB(0, 0, 0)
  mainShadow.Transparency = 0.45
  mainShadow.BlurRadius = UDim.new(0, 24)
  mainShadow.Offset = UDim2.new(0, 0, 0, 8)
  mainShadow.Spread = UDim2.new(0, 0, 0, 0)
  mainShadow.Parent = main

  local mainScale = Instance.new("UIScale")
  mainScale.Scale = 1
  mainScale.Parent = main

  do
   local BASE_W, BASE_H = 620, 400
   local MARGIN = 40
   local MIN_SCALE, MAX_SCALE = 0.55, 1

   local camera = workspace.CurrentCamera

   local function UpdateScale()
    local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
    local scaleX = (viewport.X - MARGIN) / BASE_W
    local scaleY = (viewport.Y - MARGIN) / BASE_H
    local scale = math.clamp(math.min(scaleX, scaleY, 1), MIN_SCALE, MAX_SCALE)

    TweenService:Create(mainScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     Scale = scale,
    }):Play()
   end

   UpdateScale()

   if camera then
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
   end
   workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
    if camera then
     camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
    end
    UpdateScale()
   end)
  end

  local function AddShine(parent)
   local frame = Instance.new("ImageLabel")
   frame.Image = "rbxassetid://8901067074"
   frame.ImageColor3 = Color3.fromRGB(36, 36, 36)
   frame.ScaleType = Enum.ScaleType.Slice
   frame.SliceCenter = Rect.new(7, 6, 11, 12)
   frame.BackgroundTransparency = 1
   frame.ClipsDescendants = true
   frame.Size = UDim2.new(1, 0, 1, 0)
   frame.ZIndex = 3
   frame.Parent = parent

   local shine = Instance.new("ImageLabel")
   shine.Image = "rbxassetid://8901006392"
   shine.ImageTransparency = 0.8
   shine.ScaleType = Enum.ScaleType.Crop
   shine.AnchorPoint = Vector2.new(0, 0.5)
   shine.BackgroundTransparency = 1
   shine.Position = UDim2.fromScale(-2.6, 0.5)
   shine.Size = UDim2.new(2.4, 0, 1, 0)
   shine.SizeConstraint = Enum.SizeConstraint.RelativeYY
   shine.Parent = frame

   TweenService:Create(
    shine,
    TweenInfo.new(1.75, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut, -1, false, 6),
    { Position = UDim2.fromScale(1, 0.5) }
   ):Play()
  end

  local titleBar = Instance.new("Frame")
  titleBar.Name = "TitleBar"
  titleBar.Size = UDim2.new(1, 0, 0, 46)
  titleBar.BackgroundTransparency = 1
  titleBar.Parent = main

  local shieldIcon = Instance.new("ImageLabel")
  shieldIcon.Name = "ShieldIcon"
  shieldIcon.BackgroundTransparency = 1
  shieldIcon.AnchorPoint = Vector2.new(0, 0.5)
  shieldIcon.Position = UDim2.new(0, 16, 0.5, 0)
  shieldIcon.Size = UDim2.new(0, 22, 0, 22)
  shieldIcon.Image = "rbxassetid://84528813312016"
  shieldIcon.ImageColor3 = TEXT_LIGHT
  shieldIcon.Parent = titleBar

  local titleLabel = Instance.new("TextLabel")
  titleLabel.BackgroundTransparency = 1
  titleLabel.Position = UDim2.new(0, 46, 0, 0)
  titleLabel.Size = UDim2.new(0, 172, 1, 0)
  titleLabel.Font = Enum.Font.GothamBold
  titleLabel.TextSize = 18
  titleLabel.TextXAlignment = Enum.TextXAlignment.Left
  titleLabel.TextColor3 = TEXT_LIGHT
  titleLabel.Text = "VYRNOX GUARD"
  titleLabel.Parent = titleBar

  local statusDot = Instance.new("Frame")
  statusDot.Size = UDim2.new(0, 10, 0, 10)
  statusDot.Position = UDim2.new(0, 218, 0.5, -5)
  statusDot.BackgroundColor3 = RED
  statusDot.BorderSizePixel = 0
  statusDot.Parent = titleBar
  NewCorner(5, statusDot)

  local statusLabel = Instance.new("TextLabel")
  statusLabel.BackgroundTransparency = 1
  statusLabel.Position = UDim2.new(1, -260, 0, 0)
  statusLabel.Size = UDim2.new(0, 170, 1, 0)
  statusLabel.Font = Enum.Font.GothamMedium
  statusLabel.TextSize = 13
  statusLabel.TextXAlignment = Enum.TextXAlignment.Right
  statusLabel.TextColor3 = TEXT_DIM
  statusLabel.Text = "UNPROTECTED"
  statusLabel.Parent = titleBar

  local closeBtn = Instance.new("TextButton")
  closeBtn.Name = "CloseButton"
  closeBtn.AutoButtonColor = false
  closeBtn.AnchorPoint = Vector2.new(1, 0.5)
  closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
  closeBtn.Size = UDim2.new(0, 28, 0, 28)
  closeBtn.BackgroundColor3 = RED
  closeBtn.Font = Enum.Font.GothamBold
  closeBtn.TextSize = 15
  closeBtn.TextColor3 = RED:Lerp(Color3.fromRGB(255, 255, 255), 0.75)
  closeBtn.Text = "X"
  closeBtn.Parent = titleBar
  NewCorner(8, closeBtn)

  do
   local baseSize = closeBtn.Size
   local hoverSize = UDim2.new(0, 32, 0, 32)
   closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     Size = hoverSize,
    }):Play()
   end)
   closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     Size = baseSize,
    }):Play()
   end)
  end

  do
   local dragging, dragStart, startPos
   titleBar.Active = true
   titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
     dragging = true
     dragStart = input.Position
     startPos = main.Position
     input.Changed:Connect(function()
      if input.UserInputState == Enum.UserInputState.End then dragging = false end
     end)
    end
   end)
   titleBar.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
     local delta = input.Position - dragStart
     main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
   end)
  end

  local orb = Instance.new("TextButton")
  orb.Name = "VyrnoxOrb"
  orb.AutoButtonColor = false
  orb.AnchorPoint = Vector2.new(0.5, 0.5)
  orb.Position = UDim2.new(0, 46, 0, 46)
  orb.Size = UDim2.new(0, 46, 0, 46)
  orb.BackgroundColor3 = RED
  orb.Text = ""
  orb.ZIndex = 50
  orb.Parent = ScreenGui
  NewCorner(23, orb)
  NewStroke(orb, Color3.fromRGB(255, 255, 255), 1, 0.75)

  local orbShadow = Instance.new("UIShadow")
  orbShadow.Color = Color3.fromRGB(0, 0, 0)
  orbShadow.Transparency = 0.5
  orbShadow.BlurRadius = UDim.new(0, 10)
  orbShadow.Offset = UDim2.new(0, 0, 0, 4)
  orbShadow.Parent = orb

  local orbGradient = Instance.new("UIGradient")
  orbGradient.Rotation = 60
  orbGradient.Color = ColorSequence.new(RED, RED:Lerp(Color3.fromRGB(255, 255, 255), 0.12))
  orbGradient.Parent = orb

  local orbIcon = Instance.new("ImageLabel")
  orbIcon.BackgroundTransparency = 1
  orbIcon.Position = UDim2.new(0, 10, 0, 10)
  orbIcon.Size = UDim2.new(1, -20, 1, -20)
  orbIcon.Image = "rbxassetid://84528813312016"
  orbIcon.ZIndex = 51
  orbIcon.Parent = orb

  local function SetOrbTheme(color)
   TweenService:Create(orb, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    BackgroundColor3 = color,
   }):Play()
   orbGradient.Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(255, 255, 255), 0.12))
  end

  local orbBaseSize = orb.Size
  local orbHoverSize = UDim2.new(0, 52, 0, 52)
  local orbDragging, orbDragStart, orbStartPos, orbMoved

  orb.MouseEnter:Connect(function()
   if orbDragging then return end
   TweenService:Create(orb, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = orbHoverSize,
   }):Play()
  end)
  orb.MouseLeave:Connect(function()
   if orbDragging then return end
   TweenService:Create(orb, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = orbBaseSize,
   }):Play()
  end)

  orb.InputBegan:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    orbDragging = true
    orbMoved = false
    orbDragStart = input.Position
    orbStartPos = orb.Position
    input.Changed:Connect(function()
     if input.UserInputState == Enum.UserInputState.End then orbDragging = false end
    end)
   end
  end)
  orb.InputChanged:Connect(function(input)
   if orbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    local delta = input.Position - orbDragStart
    if delta.Magnitude > 3 then orbMoved = true end
    orb.Position = UDim2.new(orbStartPos.X.Scale, orbStartPos.X.Offset + delta.X, orbStartPos.Y.Scale, orbStartPos.Y.Offset + delta.Y)
   end
  end)

  local function OpenPanel()
   orb.Visible = false
   main.Visible = true
  end
  local function ClosePanel()
   main.Visible = false
   orb.Visible = true
  end

  orb.MouseButton1Click:Connect(function()
   if orbMoved then return end
   OpenPanel()
  end)
  closeBtn.MouseButton1Click:Connect(ClosePanel)

  local notifCard = Instance.new("Frame")
  notifCard.Name = "ThreatNotifier"
  notifCard.AnchorPoint = Vector2.new(0, 0)
  notifCard.Position = UDim2.new(0, 16, 0, 78)
  notifCard.Size = UDim2.new(0, 280, 0, 0)
  notifCard.AutomaticSize = Enum.AutomaticSize.Y
  notifCard.BackgroundColor3 = BG_DARK
  notifCard.BackgroundTransparency = 1
  notifCard.BorderSizePixel = 0
  notifCard.Visible = false
  notifCard.ZIndex = 40
  notifCard.Parent = ScreenGui
  NewCorner(10, notifCard)
  local notifStroke = NewStroke(notifCard, RED, 1, 1)

  local notifShadow = Instance.new("UIShadow")
  notifShadow.Color = Color3.fromRGB(0, 0, 0)
  notifShadow.Transparency = 1
  notifShadow.BlurRadius = UDim.new(0, 14)
  notifShadow.Offset = UDim2.new(0, 0, 0, 6)
  notifShadow.Parent = notifCard

  local notifPad = Instance.new("UIPadding")
  notifPad.PaddingLeft = UDim.new(0, 12)
  notifPad.PaddingRight = UDim.new(0, 12)
  notifPad.PaddingTop = UDim.new(0, 10)
  notifPad.PaddingBottom = UDim.new(0, 10)
  notifPad.Parent = notifCard

  local notifLayout = Instance.new("UIListLayout")
  notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
  notifLayout.Padding = UDim.new(0, 4)
  notifLayout.Parent = notifCard

  local notifHeaderRow = Instance.new("Frame")
  notifHeaderRow.Name = "HeaderRow"
  notifHeaderRow.Size = UDim2.new(1, 0, 0, 18)
  notifHeaderRow.BackgroundTransparency = 1
  notifHeaderRow.LayoutOrder = 1
  notifHeaderRow.Parent = notifCard

  local notifIcon = Instance.new("ImageLabel")
  notifIcon.BackgroundTransparency = 1
  notifIcon.ImageTransparency = 1
  notifIcon.Size = UDim2.new(0, 16, 0, 16)
  notifIcon.Image = "rbxassetid://84528813312016"
  notifIcon.ImageColor3 = RED
  notifIcon.Parent = notifHeaderRow

  local notifTitle = Instance.new("TextLabel")
  notifTitle.BackgroundTransparency = 1
  notifTitle.TextTransparency = 1
  notifTitle.Position = UDim2.new(0, 22, 0, 0)
  notifTitle.Size = UDim2.new(1, -22, 1, 0)
  notifTitle.Font = Enum.Font.GothamBold
  notifTitle.TextSize = 13
  notifTitle.TextXAlignment = Enum.TextXAlignment.Left
  notifTitle.TextColor3 = TEXT_LIGHT
  notifTitle.Text = "Threat Notification"
  notifTitle.Parent = notifHeaderRow

  local notifReason = Instance.new("TextLabel")
  notifReason.Name = "Reason"
  notifReason.BackgroundTransparency = 1
  notifReason.TextTransparency = 1
  notifReason.Size = UDim2.new(1, 0, 0, 0)
  notifReason.AutomaticSize = Enum.AutomaticSize.Y
  notifReason.TextWrapped = true
  notifReason.Font = Enum.Font.Gotham
  notifReason.TextSize = 12
  notifReason.TextXAlignment = Enum.TextXAlignment.Left
  notifReason.TextColor3 = TEXT_DIM
  notifReason.LayoutOrder = 2
  notifReason.Text = ""
  notifReason.Parent = notifCard

  local NOTIF_FADE_TIME = 0.25
  local NOTIF_HOLD_TIME = 4
  local notifHideToken = 0

  local function NotifSetTransparency(t, instant)
   local ti = instant and TweenInfo.new(0) or TweenInfo.new(NOTIF_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
   TweenService:Create(notifCard, ti, {
    BackgroundTransparency = t == 1 and 1 or 0.08,
   }):Play()
   TweenService:Create(notifStroke, ti, {
    Transparency = t == 1 and 1 or 0.4,
   }):Play()
   TweenService:Create(notifShadow, ti, {
    Transparency = t == 1 and 1 or 0.5,
   }):Play()
   TweenService:Create(notifIcon, ti, {
    ImageTransparency = t,
   }):Play()
   TweenService:Create(notifTitle, ti, {
    TextTransparency = t,
   }):Play()
   TweenService:Create(notifReason, ti, {
    TextTransparency = t,
   }):Play()
  end

  local function ShowNotif(reasonText)
   notifReason.Text = tostring(reasonText)
   notifHideToken = notifHideToken + 1
   local myToken = notifHideToken

   if not notifCard.Visible then
    notifCard.Visible = true
    NotifSetTransparency(1, true)
   end
   NotifSetTransparency(0)

   spawn_func(function()
    wait_func(NOTIF_HOLD_TIME)
    if myToken ~= notifHideToken then return end
    NotifSetTransparency(1)
    wait_func(NOTIF_FADE_TIME + 0.05)
    if myToken ~= notifHideToken then return end
    notifCard.Visible = false
   end)
  end

  ShowThreatNotification = ShowNotif
  VyrnoxGuard._ShowNotif = ShowNotif

  local body = Instance.new("Frame")
  body.Name = "Body"
  body.Position = UDim2.new(0, 0, 0, 46)
  body.Size = UDim2.new(1, 0, 1, -46)
  body.BackgroundTransparency = 1
  body.Parent = main

  local tabBar = Instance.new("Frame")
  tabBar.Name = "TabBar"
  tabBar.Position = UDim2.new(0, 12, 0, 8)
  tabBar.Size = UDim2.new(0, 220, 0, 28)
  tabBar.BackgroundTransparency = 1
  tabBar.Parent = body

  local tabLayout = Instance.new("UIListLayout")
  tabLayout.FillDirection = Enum.FillDirection.Horizontal
  tabLayout.Padding = UDim.new(0, 6)
  tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
  tabLayout.Parent = tabBar

  local TAB_COUNT = 3
  local tabButtonWidth = math.floor((tabBar.Size.X.Offset - (TAB_COUNT - 1) * tabLayout.Padding.Offset) / TAB_COUNT)

  local function BuildTabButton(text, order)
   local btn = Instance.new("TextButton")
   btn.Name = text .. "Tab"
   btn.AutoButtonColor = false
   btn.Size = UDim2.new(0, tabButtonWidth, 1, 0)
   btn.LayoutOrder = order
   btn.BackgroundColor3 = PANEL_DARK
   btn.BackgroundTransparency = 0.2
   btn.Font = Enum.Font.GothamMedium
   btn.TextSize = 12
   btn.TextScaled = true
   btn.TextColor3 = TEXT_DIM
   btn.Text = text
   btn.Parent = tabBar
   local textConstraint = Instance.new("UITextSizeConstraint")
   textConstraint.MaxTextSize = 12
   textConstraint.Parent = btn
   local btnPadding = Instance.new("UIPadding")
   btnPadding.PaddingLeft = UDim.new(0, 4)
   btnPadding.PaddingRight = UDim.new(0, 4)
   btnPadding.Parent = btn
   NewCorner(8, btn)
   return btn
  end

  local togglesTabBtn = BuildTabButton("Home", 1)
  local statsTabBtn = BuildTabButton("Stats", 2)
  local changelogTabBtn = BuildTabButton("Changelog", 3)

  local panelHost = Instance.new("Frame")
  panelHost.Name = "PanelHost"
  panelHost.Position = UDim2.new(0, 12, 0, 42)
  panelHost.Size = UDim2.new(0, 220, 1, -54)
  panelHost.BackgroundTransparency = 1
  panelHost.BorderSizePixel = 0
  panelHost.ClipsDescendants = true
  panelHost.Parent = body

  local leftPanel = Instance.new("ScrollingFrame")
  leftPanel.Name = "LeftPanel"
  leftPanel.Position = UDim2.new(0, 0, 0, 0)
  leftPanel.Size = UDim2.new(1, 0, 1, 0)
  leftPanel.BackgroundColor3 = PANEL_DARK
  leftPanel.BackgroundTransparency = 0.2
  leftPanel.BorderSizePixel = 0
  leftPanel.ScrollBarThickness = 4
  leftPanel.ScrollBarImageColor3 = TEXT_DIM
  leftPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
  leftPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
  leftPanel.Parent = panelHost
  NewCorner(10, leftPanel)

  local leftLayout = Instance.new("UIListLayout")
  leftLayout.Padding = UDim.new(0, 8)
  leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
  leftLayout.Parent = leftPanel

  local leftPadding = Instance.new("UIPadding")
  leftPadding.PaddingTop = UDim.new(0, 10)
  leftPadding.PaddingLeft = UDim.new(0, 10)
  leftPadding.PaddingRight = UDim.new(0, 10)
  leftPadding.PaddingBottom = UDim.new(0, 10)
  leftPadding.Parent = leftPanel

  local statsPanel = Instance.new("ScrollingFrame")
  statsPanel.Name = "StatsPanel"
  statsPanel.Position = UDim2.new(0, 0, 0, 0)
  statsPanel.Size = UDim2.new(1, 0, 1, 0)
  statsPanel.BackgroundColor3 = PANEL_DARK
  statsPanel.BackgroundTransparency = 0.2
  statsPanel.BorderSizePixel = 0
  statsPanel.ScrollBarThickness = 4
  statsPanel.ScrollBarImageColor3 = TEXT_DIM
  statsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
  statsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
  statsPanel.Visible = false
  statsPanel.Parent = panelHost
  NewCorner(10, statsPanel)

  local statsLayout = Instance.new("UIListLayout")
  statsLayout.Padding = UDim.new(0, 6)
  statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
  statsLayout.Parent = statsPanel

  local statsPadding = Instance.new("UIPadding")
  statsPadding.PaddingTop = UDim.new(0, 10)
  statsPadding.PaddingLeft = UDim.new(0, 10)
  statsPadding.PaddingRight = UDim.new(0, 10)
  statsPadding.PaddingBottom = UDim.new(0, 10)
  statsPadding.Parent = statsPanel

  local changelogPanel = Instance.new("ScrollingFrame")
  changelogPanel.Name = "ChangelogPanel"
  changelogPanel.Position = UDim2.new(0, 0, 0, 0)
  changelogPanel.Size = UDim2.new(1, 0, 1, 0)
  changelogPanel.BackgroundColor3 = PANEL_DARK
  changelogPanel.BackgroundTransparency = 0.2
  changelogPanel.BorderSizePixel = 0
  changelogPanel.ScrollBarThickness = 4
  changelogPanel.ScrollBarImageColor3 = TEXT_DIM
  changelogPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
  changelogPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
  changelogPanel.Visible = false
  changelogPanel.Parent = panelHost
  NewCorner(10, changelogPanel)

  local changelogLayout = Instance.new("UIListLayout")
  changelogLayout.Padding = UDim.new(0, 10)
  changelogLayout.SortOrder = Enum.SortOrder.LayoutOrder
  changelogLayout.Parent = changelogPanel

  local changelogPadding = Instance.new("UIPadding")
  changelogPadding.PaddingTop = UDim.new(0, 10)
  changelogPadding.PaddingLeft = UDim.new(0, 10)
  changelogPadding.PaddingRight = UDim.new(0, 10)
  changelogPadding.PaddingBottom = UDim.new(0, 10)
  changelogPadding.Parent = changelogPanel

  local function BuildChangelogPanel()
   local order = 0

   for _, entry in ipairs(ChangelogData) do
    order = order + 1
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 18)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = TEXT_LIGHT
    header.Text = "v" .. tostring(entry.version) .. (entry.date and ("  -  " .. entry.date) or "")
    header.LayoutOrder = order
    header.Parent = changelogPanel

    for _, change in ipairs(entry.changes or {}) do
     order = order + 1
     local line = Instance.new("TextLabel")
     line.BackgroundTransparency = 1
     line.Size = UDim2.new(1, 0, 0, 0)
     line.AutomaticSize = Enum.AutomaticSize.Y
     line.TextWrapped = true
     line.Font = Enum.Font.Gotham
     line.TextSize = 12
     line.TextXAlignment = Enum.TextXAlignment.Left
     line.TextYAlignment = Enum.TextYAlignment.Top
     line.TextColor3 = TEXT_DIM
     line.Text = "•  " .. change
     line.LayoutOrder = order
     line.Parent = changelogPanel
    end

    order = order + 1
    local spacer = Instance.new("Frame")
    spacer.BackgroundTransparency = 1
    spacer.Size = UDim2.new(1, 0, 0, 4)
    spacer.LayoutOrder = order
    spacer.Parent = changelogPanel
   end

   if #ChangelogData == 0 then
    local empty = Instance.new("TextLabel")
    empty.BackgroundTransparency = 1
    empty.Size = UDim2.new(1, 0, 0, 18)
    empty.Font = Enum.Font.Gotham
    empty.TextSize = 12
    empty.TextXAlignment = Enum.TextXAlignment.Left
    empty.TextColor3 = TEXT_DIM
    empty.Text = "No changelog entries yet."
    empty.Parent = changelogPanel
   end
  end

  BuildChangelogPanel()

  local function SetTabButtonActive(btn, active)
   btn.BackgroundColor3 = active and CALM or PANEL_DARK
   btn.BackgroundTransparency = active and 0.05 or 0.2
   btn.TextColor3 = active and TEXT_LIGHT or TEXT_DIM
  end

  local RefreshStatsPanel

  local TAB_ORDER = { toggles = 1, stats = 2, changelog = 3 }
  local tabPanels = { toggles = leftPanel, stats = statsPanel, changelog = changelogPanel }
  local currentTab = "toggles"
  local slideTweens = {}
  local slideGen = 0
  local SLIDE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

  local function SwitchTab(tab)
   if not tabPanels[tab] then tab = "toggles" end
   if tab == currentTab then return end

   local fromTab = currentTab
   currentTab = tab
   slideGen = slideGen + 1
   local myGen = slideGen

   for _, tw in ipairs(slideTweens) do tw:Cancel() end
   slideTweens = {}

   SetTabButtonActive(togglesTabBtn, tab == "toggles")
   SetTabButtonActive(statsTabBtn, tab == "stats")
   SetTabButtonActive(changelogTabBtn, tab == "changelog")

   local direction = TAB_ORDER[tab] > TAB_ORDER[fromTab] and 1 or -1
   local fromPanel = tabPanels[fromTab]
   local toPanel = tabPanels[tab]

   for name, panel in pairs(tabPanels) do
    if panel ~= fromPanel and panel ~= toPanel then
     panel.Visible = false
     panel.Position = UDim2.new(0, 0, 0, 0)
    end
   end

   toPanel.Position = UDim2.new(direction, 0, 0, 0)
   toPanel.Visible = true

   local outTween = TweenService:Create(fromPanel, SLIDE_INFO, { Position = UDim2.new(-direction, 0, 0, 0) })
   local inTween = TweenService:Create(toPanel, SLIDE_INFO, { Position = UDim2.new(0, 0, 0, 0) })
   slideTweens = { outTween, inTween }

   outTween.Completed:Connect(function(state)
    if myGen ~= slideGen then return end
    fromPanel.Visible = false
    fromPanel.Position = UDim2.new(0, 0, 0, 0)
   end)

   outTween:Play()
   inTween:Play()

   if tab == "stats" and RefreshStatsPanel then
    RefreshStatsPanel()
   end
  end

  togglesTabBtn.MouseButton1Click:Connect(function() SwitchTab("toggles") end)
  statsTabBtn.MouseButton1Click:Connect(function() SwitchTab("stats") end)
  changelogTabBtn.MouseButton1Click:Connect(function() SwitchTab("changelog") end)
  SetTabButtonActive(togglesTabBtn, true)
  SetTabButtonActive(statsTabBtn, false)
  SetTabButtonActive(changelogTabBtn, false)

  local rightPanel = Instance.new("Frame")
  rightPanel.Name = "RightPanel"
  rightPanel.Position = UDim2.new(0, 244, 0, 8)
  rightPanel.Size = UDim2.new(1, -256, 1, -20)
  rightPanel.BackgroundColor3 = PANEL_DARK
  rightPanel.BackgroundTransparency = 0.2
  rightPanel.BorderSizePixel = 0
  rightPanel.Parent = body
  NewCorner(10, rightPanel)

  local consoleScroll = Instance.new("ScrollingFrame")
  consoleScroll.Name = "Console"
  consoleScroll.Position = UDim2.new(0, 8, 0, 8)
  consoleScroll.Size = UDim2.new(1, -16, 1, -56)
  consoleScroll.BackgroundTransparency = 1
  consoleScroll.BorderSizePixel = 0
  consoleScroll.ScrollBarThickness = 4
  consoleScroll.ScrollBarImageColor3 = TEXT_DIM
  consoleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
  consoleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
  consoleScroll.Parent = rightPanel

  local consoleLayout = Instance.new("UIListLayout")
  consoleLayout.Padding = UDim.new(0, 2)
  consoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
  consoleLayout.Parent = consoleScroll

  consoleLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
   consoleScroll.CanvasPosition = Vector2.new(0, consoleLayout.AbsoluteContentSize.Y)
  end)

  local MAX_CONSOLE_LINES = 50
  local consoleLineCount = 0

  local consolePool = {}

  local function GetPooledConsoleLabel(slot)
   local line = consolePool[slot]
   if not line then
    line = Instance.new("TextLabel")
    line.BackgroundTransparency = 1
    line.Size = UDim2.new(1, -4, 0, 0)
    line.AutomaticSize = Enum.AutomaticSize.Y
    line.TextWrapped = true
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.Font = Enum.Font.Code
    line.TextSize = 13
    line.Archivable = false
    line.Parent = consoleScroll
    consolePool[slot] = line
   end
   return line
  end

  AddConsoleLine = function(msg_type, msg)
   consoleLineCount = consoleLineCount + 1
   local slot = ((consoleLineCount - 1) % MAX_CONSOLE_LINES) + 1

   local line = GetPooledConsoleLabel(slot)
   line.Visible = true
   line.TextColor3 = (msg_type == "warn") and Color3.fromRGB(255, 138, 138) or TEXT_LIGHT
   line.Text = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(msg)
   line.LayoutOrder = consoleLineCount
  end

  local actionBar = Instance.new("Frame")
  actionBar.Name = "ActionBar"
  actionBar.Position = UDim2.new(0, 8, 1, -40)
  actionBar.Size = UDim2.new(1, -16, 0, 32)
  actionBar.BackgroundTransparency = 1
  actionBar.Parent = rightPanel

  local actionDefs = {
   { text = "Blocked Log", run = function() VyrnoxGuard.PrintLog() end },
   { text = "Events", run = function() VyrnoxGuard.PrintEvents() end },
   { text = "Hook Status", run = function() VyrnoxGuard.PrintHookStatus() end },
  }

  for i, def in ipairs(actionDefs) do
   local btn = Instance.new("TextButton")
   btn.Name = "Action" .. i
   btn.AutoButtonColor = false
   btn.Size = UDim2.new(1 / #actionDefs, -4, 1, 0)
   btn.Position = UDim2.new((i - 1) / #actionDefs, (i == 1) and 0 or 2, 0, 0)
   btn.BackgroundColor3 = BG_DARK
   btn.BackgroundTransparency = 0.15
   btn.BorderSizePixel = 0
   btn.Font = Enum.Font.GothamMedium
   btn.TextSize = 12
   btn.TextColor3 = TEXT_LIGHT
   btn.Text = def.text
   btn.Parent = actionBar
   NewCorner(8, btn)
   NewStroke(btn, Color3.fromRGB(255, 255, 255), 1, 0.88)

   btn.MouseEnter:Connect(function()
    TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = CALM:Lerp(BG_DARK, 0.7) }):Play()
   end)
   btn.MouseLeave:Connect(function()
    TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = BG_DARK }):Play()
   end)
   btn.MouseButton1Click:Connect(function()
    local ok, err = pcall(def.run)
    if not ok then
     Console("warn", "Error running " .. def.text .. ": " .. tostring(err))
    end
   end)
  end

  local function ApplyTheme(fraction)
   local base = RED:Lerp(CALM, fraction)

   TweenService:Create(statusDot, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    BackgroundColor3 = base,
   }):Play()

   TweenService:Create(shieldIcon, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    ImageColor3 = base,
   }):Play()

   SetOrbTheme(base)

   if fraction >= 1 then
    statusLabel.Text = "PROTECTED"
   elseif fraction <= 0 then
    statusLabel.Text = "UNPROTECTED"
   else
    statusLabel.Text = "HALF PROTECTED"
   end
  end
  AddShine(main)

  local tooltip = Instance.new("Frame")
  tooltip.Name = "InfoTooltip"
  tooltip.AnchorPoint = Vector2.new(0.5, 1)
  tooltip.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
  tooltip.BorderSizePixel = 0
  tooltip.Size = UDim2.new(0, 220, 0, 0)
  tooltip.AutomaticSize = Enum.AutomaticSize.Y
  tooltip.Visible = false
  tooltip.ZIndex = 50
  tooltip.Parent = ScreenGui
  NewCorner(8, tooltip)
  NewStroke(tooltip, Color3.fromRGB(255, 255, 255), 1, 0.85)

  local tooltipPad = Instance.new("UIPadding")
  tooltipPad.PaddingTop = UDim.new(0, 8)
  tooltipPad.PaddingBottom = UDim.new(0, 8)
  tooltipPad.PaddingLeft = UDim.new(0, 10)
  tooltipPad.PaddingRight = UDim.new(0, 10)
  tooltipPad.Parent = tooltip

  local tooltipLayout = Instance.new("UIListLayout")
  tooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
  tooltipLayout.Padding = UDim.new(0, 2)
  tooltipLayout.Parent = tooltip

  local tooltipTitle = Instance.new("TextLabel")
  tooltipTitle.BackgroundTransparency = 1
  tooltipTitle.Size = UDim2.new(1, 0, 0, 0)
  tooltipTitle.AutomaticSize = Enum.AutomaticSize.Y
  tooltipTitle.Font = Enum.Font.GothamBold
  tooltipTitle.TextSize = 13
  tooltipTitle.TextColor3 = TEXT_LIGHT
  tooltipTitle.TextXAlignment = Enum.TextXAlignment.Left
  tooltipTitle.TextWrapped = true
  tooltipTitle.LayoutOrder = 1
  tooltipTitle.Parent = tooltip

  local tooltipBody = Instance.new("TextLabel")
  tooltipBody.BackgroundTransparency = 1
  tooltipBody.Size = UDim2.new(1, 0, 0, 0)
  tooltipBody.AutomaticSize = Enum.AutomaticSize.Y
  tooltipBody.Font = Enum.Font.Gotham
  tooltipBody.TextSize = 12
  tooltipBody.TextColor3 = TEXT_DIM
  tooltipBody.TextXAlignment = Enum.TextXAlignment.Left
  tooltipBody.TextWrapped = true
  tooltipBody.LayoutOrder = 2
  tooltipBody.Parent = tooltip

  local tooltipGen = 0
  local delay_func = (task and task.delay) or delay

  local function ShowTooltip(def, screenPos)
   tooltipGen = tooltipGen + 1
   local myGen = tooltipGen

   tooltipTitle.Text = def.label
   tooltipBody.Text = def.desc or ""

   local camera = workspace.CurrentCamera
   local vpSize = (camera and camera.ViewportSize) or Vector2.new(1920, 1080)
   local inset = ScreenGui.IgnoreGuiInset and GuiService:GetGuiInset() or Vector2.zero
   local x = math.clamp(screenPos.X + inset.X, 120, vpSize.X - 120)
   local y = math.max(screenPos.Y + inset.Y - 14, 60)

   tooltip.Position = UDim2.new(0, x, 0, y)
   tooltip.Visible = true
   tooltip.BackgroundTransparency = 1
   tooltipTitle.TextTransparency = 1
   tooltipBody.TextTransparency = 1

   TweenService:Create(tooltip, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    BackgroundTransparency = 0.05,
   }):Play()
   TweenService:Create(tooltipTitle, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
   TweenService:Create(tooltipBody, TweenInfo.new(0.15), { TextTransparency = 0.15 }):Play()

   delay_func(3, function()
    if myGen ~= tooltipGen then return end
    TweenService:Create(tooltip, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(tooltipTitle, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
    local hideTween = TweenService:Create(tooltipBody, TweenInfo.new(0.2), { TextTransparency = 1 })
    hideTween:Play()
    hideTween.Completed:Connect(function()
     if myGen == tooltipGen then tooltip.Visible = false end
    end)
   end)
  end

  local toggleDefs = {
   {
    label = "Protect Cookies", desc = "Blocks your .ROBLOSECURITY session cookie from leaving, plaintext, URL/hex/base64-encoded, reversed, or XOR-obfuscated.",
    get = function()
     return ProtectCookies
    end,
    set = VyrnoxGuard.ToggleCookies
   },
   {
    label = "Protect IP", desc = "Blocks your public IP address from appearing in outgoing requests or file writes.",
    get = function()
     return ProtectIP
    end,
    set = VyrnoxGuard.ToggleIP,
    subToggles = {
     {
      label = "Fake IP", desc = "Instead of blocking, swaps your real IP for a random decoy IPv4/IPv6 address in outgoing requests so the request still goes through.",
      get = function()
       return FakeIPEnabled
      end,
      set = VyrnoxGuard.ToggleFakeIP
     },
    },
   },
   {
    label = "Protect WebSocket", desc = "Scans WebSocket connections and outgoing messages the same way HTTP requests are scanned.",
    get = function()
     return ProtectWebSocket
    end,
    set = VyrnoxGuard.ToggleWebSocket
   },
   {
    label = "Protect Domains", desc = "Blocks known IP-logger domains and scores suspicious infrastructure, raw IPs, dynamic DNS, odd ports, DGA-style hostnames.",
    get = function()
     return ProtectDomains
    end,
    set = VyrnoxGuard.ToggleDomains
   },
   {
    label = "Protect Filesystem", desc = "Blocks sensitive data before it's written to disk, and guards against mass file deletion.",
    get = function()
     return ProtectFilesystem
    end,
    set = VyrnoxGuard.ToggleFilesystem,
    subToggles = {
     {
      label = "Block Big Files", desc = "Blocks writefile/appendfile when the resulting file would be over 10MB (disk-filling attacks).",
      get = function()
       return BlockBigFiles
      end,
      set = VyrnoxGuard.ToggleBigFiles
     },
     {
      kind = "textbox", label = "Max Size (MB)", desc = "Largest file a write may reach before it's blocked.", boxWidth = 64, placeholder = "10",
      get = function()
       return string.format("%g", MaxWriteFileSize / (1024 * 1024))
      end,
      set = VyrnoxGuard.SetMaxFileSizeMB
     },
    },
   },
   {
    label = "Protect Console/GUI", desc = "Redacts sensitive data before it can be printed to console or shown in a GUI text label.",
    get = function()
     return ProtectConsoleGui
    end,
    set = VyrnoxGuard.ToggleConsoleGui
   },
   {
    label = "Protect Fingerprint", desc = "Learns and blocks new IP-logger domains from page content.",
    get = function()
     return ProtectFingerprint
    end,
    set = VyrnoxGuard.ToggleFingerprint
   },
   {
    label = "Protect Tokens", desc = "Blocks Discord, JWT, and OAuth tokens from leaving in outgoing requests.",
    get = function()
     return ProtectTokens
    end,
    set = VyrnoxGuard.ToggleTokens
   },
   {
    label = "Protect Clipboard", desc = "Hooks setclipboard and its variants (toclipboard, syn.write_clipboard...) and warns when a script copies a link that looks like a fake Roblox site (roblox.com.bz, robIox.com...). Also rate limits clipboard spam.",
    get = function()
     return VyrnoxGuard.ProtectClipboard
    end,
    set = VyrnoxGuard.ToggleClipboard,
    subToggles = {
     {
      label = "Block", desc = "On: stops the copy entirely. Off: only warns and logs, the text is still copied.",
      get = function()
       return VyrnoxGuard.BlockClipboard
      end,
      set = VyrnoxGuard.ToggleClipboardBlock
     },
     {
      label = "Rate Limit", desc = "Drops clipboard writes from scripts that spam it (more than 5 copies in 2 seconds) so they can't flood or hijack your clipboard.",
      get = function()
       return VyrnoxGuard.RateLimitClipboard
      end,
      set = VyrnoxGuard.ToggleClipboardRateLimit
     },
    },
   },
   {
    label = "Protect Chat", desc = "Blocks executor-made chat sends (TextChannel:SendAsync / legacy SayMessageRequest) so a script can't spam chat as you. Needs Protect Metatable.",
    get = function()
     return BlockForcedMessages
    end,
    set = VyrnoxGuard.ToggleForcedMessages
   },
   {
    label = "Protect Metatable", desc = "Hooks game's raw __namecall/__newindex (catches direct Instance:HttpGet() calls, pixel-buffer APIs, GUI leaks).",
    get = function()
     return ProtectMetatable
    end,
    set = VyrnoxGuard.ToggleMetatable
   },
   {
    label = "Protect Webhooks", desc = "Blocks requests to webhook and exfiltration endpoints: Discord, Telegram, Slack, Teams, Zapier/Make/n8n, request catchers (webhook.site, Pipedream...), tunnels (ngrok...), paste/file upload endpoints, and form-to-email relays.",
    get = function()
     return BlockWebhooks
    end,
    set = VyrnoxGuard.ToggleWebhooks,
    subToggles = {
     {
      label = "Block", desc = "On: actually blocks the request. Off: still detects and warns/logs it, but lets it through.",
      get = function()
       return BlockWebhooksHardBlock
      end,
      set = VyrnoxGuard.ToggleWebhookBlock
     },
    },
   },
   {
    label = "Cloud Reputation", desc = "Sends borderline-suspicion URLs to a reputation-check server before blocking. Needs an endpoint configured and adds a network round-trip. Set the worker link in this toggle's submenu.",
    get = function()
     return ProtectCloudReputation
    end,
    set = VyrnoxGuard.ToggleCloudReputation,
    subToggles = {
     {
      kind = "textbox", label = "Worker Link", desc = "URL of your deployed reputation worker (https://...). Leave empty to clear.", boxWidth = 120, placeholder = "https://...",
      get = function()
       return CRE
      end,
      set = function(text)
       if text ~= "" and not text:match("^https?://") then
        Console("warn", "Worker link must start with http:// or https://")
        return false
       end
       VyrnoxGuard.SetCloudReputationEndpoint(text)
       return true
      end
     },
    },
   },
  }
  local totalToggles = 0
  for _, def in ipairs(toggleDefs) do
   if def.kind ~= "textbox" then totalToggles = totalToggles + 1 end
  end

  local function CountEnabled()
   local n = 0
   for _, def in ipairs(toggleDefs) do
    if def.kind ~= "textbox" and def.get() then n = n + 1 end
   end
   return n
  end

  local toggleVisuals = {}
  local textboxVisuals = {}

  local function SyncToggleVisual(def, animate)
   local vis = toggleVisuals[def]
   if not vis then return end
   local state = def.get()
   if animate then
    TweenService:Create(vis.pill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = state and CALM or KNOB_OFF,
    }):Play()
    TweenService:Create(vis.knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
     Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
    }):Play()
   else
    vis.pill.BackgroundColor3 = state and CALM or KNOB_OFF
    vis.knob.Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
   end
  end

  local function SyncAllToggleVisuals()
   for _, def in ipairs(toggleDefs) do
    if def.kind ~= "textbox" then SyncToggleVisual(def, true) end
   end
   for def, box in pairs(textboxVisuals) do
    if not box:IsFocused() then
     local okGet, value = pcall(def.get)
     box.Text = okGet and tostring(value or "") or ""
    end
   end
   ApplyTheme(CountEnabled() / totalToggles)
  end

  local TAP_MOVE_THRESHOLD = 8

  local function IsInsideBounds(position, guiObject)
   local absPos = guiObject.AbsolutePosition
   local absSize = guiObject.AbsoluteSize
   return position.X >= absPos.X and position.X <= (absPos.X + absSize.X) and position.Y >= absPos.Y and position.Y <= (absPos.Y + absSize.Y)
  end

  local function ToggleSubmenu(def)
   local vis = toggleVisuals[def]
   if not vis or not vis.subContainer then return end

   vis.expanded = not vis.expanded
   if vis.tween then vis.tween:Cancel() end

   local targetHeight = vis.expanded and vis.subContainerHeight or 0
   vis.tween = TweenService:Create(vis.subContainer, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(1, 0, 0, targetHeight),
   })
   vis.tween:Play()

   if vis.caret then
    TweenService:Create(vis.caret, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     Rotation = vis.expanded and 90 or 0,
    }):Play()
   end
  end

  local SUB_ON = UDim2.new(1, -16, 0.5, 0)
  local SUB_OFF = UDim2.new(0, 2, 0.5, 0)

  local function BuildTextboxRow(def, order, parent, isSub)
   local row = Instance.new("Frame")
   if isSub then
    row.Size = UDim2.new(1, -8, 0, 28)
   else
    row.Size = UDim2.new(1, 0, 0, 36)
   end
   row.BackgroundTransparency = 1
   row.LayoutOrder = order
   row.Parent = parent

   local boxWidth = def.boxWidth or 110
   if isSub then boxWidth = math.max(48, boxWidth - 24) end

   local rowLabel = Instance.new("TextLabel")
   rowLabel.BackgroundTransparency = 1
   rowLabel.Size = UDim2.new(1, -(boxWidth + 8), 1, 0)
   rowLabel.Font = isSub and Enum.Font.Gotham or Enum.Font.GothamMedium
   rowLabel.TextSize = isSub and 12 or 13
   rowLabel.TextXAlignment = isSub and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
   rowLabel.TextColor3 = isSub and TEXT_DIM or TEXT_LIGHT
   rowLabel.Text = def.label
   rowLabel.Parent = row

   local box = Instance.new("TextBox")
   box.Name = "Input"
   box.AnchorPoint = Vector2.new(1, 0.5)
   box.Position = UDim2.new(1, 0, 0.5, 0)
   box.Size = UDim2.new(0, boxWidth, 0, isSub and 20 or 22)
   box.BackgroundColor3 = BG_DARK
   box.BackgroundTransparency = 0.15
   box.BorderSizePixel = 0
   box.Font = Enum.Font.Code
   box.TextSize = isSub and 11 or 12
   box.TextColor3 = TEXT_LIGHT
   box.PlaceholderText = def.placeholder or ""
   box.PlaceholderColor3 = TEXT_DIM
   box.TextXAlignment = Enum.TextXAlignment.Left
   box.ClearTextOnFocus = false
   box.ClipsDescendants = true
   local okGet, initial = pcall(def.get)
   box.Text = okGet and tostring(initial or "") or ""
   box.Parent = row
   NewCorner(6, box)
   NewStroke(box, Color3.fromRGB(255, 255, 255), 1, 0.88)

   local pad = Instance.new("UIPadding")
   pad.PaddingLeft = UDim.new(0, 6)
   pad.PaddingRight = UDim.new(0, 6)
   pad.Parent = box

   textboxVisuals[def] = box

   box.FocusLost:Connect(function()
    local text = box.Text:match("^%s*(.-)%s*$")
    local okSet, accepted = pcall(def.set, text)
    if not okSet or accepted == false then
     if not okSet then Console("warn", "Couldn't apply " .. tostring(def.label) .. ": " .. tostring(accepted)) end
    end
    local okNow, current = pcall(def.get)
    box.Text = okNow and tostring(current or "") or ""
   end)

   return row
  end

  local function BuildSubToggleRow(subDef, order, parent)
   if subDef.kind == "textbox" then
    return BuildTextboxRow(subDef, order, parent, true)
   end
   local subState = subDef.get and subDef.get() == true or (subDef.default == true)

   local subRow = Instance.new("Frame")
   subRow.Size = UDim2.new(1, -8, 0, 28)
   subRow.BackgroundTransparency = 1
   subRow.LayoutOrder = order
   subRow.Parent = parent

   local subLabel = Instance.new("TextLabel")
   subLabel.BackgroundTransparency = 1
   subLabel.Size = UDim2.new(1, -46, 1, 0)
   subLabel.Font = Enum.Font.Gotham
   subLabel.TextSize = 12
   subLabel.TextXAlignment = Enum.TextXAlignment.Right
   subLabel.TextColor3 = TEXT_DIM
   subLabel.Text = subDef.label
   subLabel.Parent = subRow

   local subPill = Instance.new("TextButton")
   subPill.Name = "SubToggle"
   subPill.Text = ""
   subPill.AutoButtonColor = false
   subPill.AnchorPoint = Vector2.new(1, 0.5)
   subPill.Size = UDim2.new(0, 34, 0, 18)
   subPill.Position = UDim2.new(1, 0, 0.5, 0)
   subPill.BackgroundColor3 = subState and CALM or KNOB_OFF
   subPill.BorderSizePixel = 0
   subPill.Parent = subRow
   NewCorner(9, subPill)

   local subKnob = Instance.new("Frame")
   subKnob.Size = UDim2.new(0, 14, 0, 14)
   subKnob.AnchorPoint = Vector2.new(0, 0.5)
   subKnob.Position = subState and SUB_ON or SUB_OFF
   subKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
   subKnob.BorderSizePixel = 0
   subKnob.Parent = subPill
   NewCorner(7, subKnob)

   subPill.MouseButton1Click:Connect(function()
    subState = not subState
    if subDef.set then subDef.set(subState) end
    TweenService:Create(subPill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = subState and CALM or KNOB_OFF,
    }):Play()
    TweenService:Create(subKnob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
     Position = subState and SUB_ON or SUB_OFF,
    }):Play()
   end)

   return subRow
  end

  local function BuildToggleRow(def, order)
   if def.kind == "textbox" then
    local holder = Instance.new("Frame")
    holder.Name = "TextboxGroup"
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order * 10
    holder.Parent = leftPanel
    BuildTextboxRow(def, 1, holder, false)
    return holder
   end
   local group = Instance.new("Frame")
   group.Name = "ToggleGroup"
   group.Size = UDim2.new(1, 0, 0, 0)
   group.AutomaticSize = Enum.AutomaticSize.Y
   group.BackgroundTransparency = 1
   group.LayoutOrder = order * 10
   group.Parent = leftPanel

   local groupLayout = Instance.new("UIListLayout")
   groupLayout.Padding = UDim.new(0, 0)
   groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
   groupLayout.Parent = group

   local row = Instance.new("Frame")
   row.Size = UDim2.new(1, 0, 0, 36)
   row.BackgroundTransparency = 1
   row.LayoutOrder = 1
   row.Parent = group

   local hasSubs = def.subToggles ~= nil and #def.subToggles > 0
   local rightInset = hasSubs and 22 or 0

   local infoZone = Instance.new("TextButton")
   infoZone.Name = "InfoZone"
   infoZone.Text = ""
   infoZone.AutoButtonColor = false
   infoZone.BackgroundTransparency = 1
   infoZone.Size = UDim2.new(1, -(56 + rightInset), 1, 0)
   infoZone.Parent = row

   local isPressed = false
   local startPosition = Vector2.zero

   infoZone.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
     isPressed = true
     startPosition = Vector2.new(input.Position.X, input.Position.Y)
    end
   end)

   infoZone.InputEnded:Connect(function(input)
    if not isPressed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
     isPressed = false
     local endPosition = Vector2.new(input.Position.X, input.Position.Y)
     local dragDistance = (endPosition - startPosition).Magnitude
     if dragDistance <= TAP_MOVE_THRESHOLD and IsInsideBounds(endPosition, infoZone) then
      ShowTooltip(def, endPosition)
     end
    end
   end)

   local label = Instance.new("TextLabel")
   label.BackgroundTransparency = 1
   label.Size = UDim2.new(1, -(56 + rightInset), 1, 0)
   label.Font = Enum.Font.GothamMedium
   label.TextSize = 13
   label.TextXAlignment = Enum.TextXAlignment.Left
   label.TextColor3 = TEXT_LIGHT
   label.Text = def.label
   label.Parent = row

   local caret
   if hasSubs then
    caret = Instance.new("ImageButton")
    caret.Name = "Caret"
    caret.AutoButtonColor = false
    caret.BackgroundTransparency = 1
    caret.AnchorPoint = Vector2.new(1, 0.5)
    caret.Position = UDim2.new(1, -54, 0.5, 0)
    caret.Size = UDim2.new(0, 14, 0, 14)
    caret.Image = "rbxassetid://81462102154124"
    caret.ImageColor3 = TEXT_DIM
    caret.Rotation = 0
    caret.ZIndex = 3
    caret.Parent = row
    caret.MouseButton1Click:Connect(function()
     ToggleSubmenu(def)
    end)
   end

   local pill = Instance.new("TextButton")
   pill.Name = "Toggle"
   pill.Text = ""
   pill.AutoButtonColor = false
   pill.AnchorPoint = Vector2.new(1, 0.5)
   pill.Size = UDim2.new(0, 44, 0, 22)
   pill.Position = UDim2.new(1, 0, 0.5, 0)
   pill.BackgroundColor3 = def.get() and CALM or KNOB_OFF
   pill.BorderSizePixel = 0
   pill.Parent = row
   NewCorner(11, pill)

   local knob = Instance.new("Frame")
   knob.Size = UDim2.new(0, 18, 0, 18)
   knob.AnchorPoint = Vector2.new(0, 0.5)
   knob.Position = def.get() and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
   knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
   knob.BorderSizePixel = 0
   knob.Parent = pill
   NewCorner(9, knob)

   toggleVisuals[def] = { pill = pill, knob = knob, caret = caret }

   if def.subToggles and #def.subToggles > 0 then
    local subContainer = Instance.new("Frame")
    subContainer.Name = "SubContainer"
    subContainer.BackgroundTransparency = 1
    subContainer.ClipsDescendants = true
    subContainer.Size = UDim2.new(1, 0, 0, 0)
    subContainer.LayoutOrder = 2
    subContainer.Parent = group

    local subLayout = Instance.new("UIListLayout")
    subLayout.SortOrder = Enum.SortOrder.LayoutOrder
    subLayout.Padding = UDim.new(0, 2)
    subLayout.Parent = subContainer

    for si, subDef in ipairs(def.subToggles) do
     BuildSubToggleRow(subDef, si, subContainer)
    end

    local subCount = #def.subToggles
    toggleVisuals[def].subContainer = subContainer
    toggleVisuals[def].subContainerHeight = subCount * 28 + math.max(0, subCount - 1) * 2
    toggleVisuals[def].expanded = false
   end

   local baseSize = pill.Size
   local hoverSize = UDim2.new(0, 50, 0, 25)

   pill.MouseEnter:Connect(function()
    TweenService:Create(pill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     Size = hoverSize,
    }):Play()
   end)
   pill.MouseLeave:Connect(function()
    TweenService:Create(pill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     Size = baseSize,
    }):Play()
   end)

   pill.MouseButton1Click:Connect(function()
    def.set(not def.get())
   end)

   return row
  end

  for i, def in ipairs(toggleDefs) do
   BuildToggleRow(def, i)
  end

  VyrnoxGuard.OnToggleChange(SyncAllToggleVisuals)
  SyncAllToggleVisuals()

  do
   local section = Instance.new("Frame")
   section.Name = "WhitelistSection"
   section.Size = UDim2.new(1, 0, 0, 0)
   section.AutomaticSize = Enum.AutomaticSize.Y
   section.BackgroundTransparency = 1
   section.LayoutOrder = #toggleDefs * 10 + 3
   section.Parent = leftPanel

   local sectionLayout = Instance.new("UIListLayout")
   sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
   sectionLayout.Padding = UDim.new(0, 4)
   sectionLayout.Parent = section

   local header = Instance.new("Frame")
   header.Size = UDim2.new(1, 0, 0, 32)
   header.BackgroundTransparency = 1
   header.LayoutOrder = 1
   header.Parent = section

   local headerLabel = Instance.new("TextLabel")
   headerLabel.BackgroundTransparency = 1
   headerLabel.Size = UDim2.new(1, -36, 1, 0)
   headerLabel.Font = Enum.Font.GothamMedium
   headerLabel.TextSize = 13
   headerLabel.TextXAlignment = Enum.TextXAlignment.Left
   headerLabel.TextColor3 = TEXT_LIGHT
   headerLabel.Text = "Whitelisted Links"
   headerLabel.Parent = header

   local addBtn = Instance.new("TextButton")
   addBtn.Name = "AddLink"
   addBtn.AutoButtonColor = false
   addBtn.AnchorPoint = Vector2.new(1, 0.5)
   addBtn.Position = UDim2.new(1, -4, 0.5, 0)
   addBtn.Size = UDim2.new(0, 24, 0, 24)
   addBtn.BackgroundColor3 = BG_DARK
   addBtn.BackgroundTransparency = 0.15
   addBtn.BorderSizePixel = 0
   addBtn.Font = Enum.Font.GothamBold
   addBtn.TextSize = 16
   addBtn.TextColor3 = CALM
   addBtn.Text = "+"
   addBtn.Parent = header
   NewCorner(12, addBtn)
   NewStroke(addBtn, CALM, 1, 0.3)

   addBtn.MouseEnter:Connect(function()
    TweenService:Create(addBtn, TweenInfo.new(0.15), { BackgroundColor3 = CALM:Lerp(BG_DARK, 0.7) }):Play()
   end)
   addBtn.MouseLeave:Connect(function()
    TweenService:Create(addBtn, TweenInfo.new(0.15), { BackgroundColor3 = BG_DARK }):Play()
   end)

   local entries = Instance.new("Frame")
   entries.Name = "Entries"
   entries.Size = UDim2.new(1, 0, 0, 0)
   entries.AutomaticSize = Enum.AutomaticSize.Y
   entries.BackgroundTransparency = 1
   entries.LayoutOrder = 2
   entries.Parent = section

   local entriesLayout = Instance.new("UIListLayout")
   entriesLayout.SortOrder = Enum.SortOrder.LayoutOrder
   entriesLayout.Padding = UDim.new(0, 4)
   entriesLayout.Parent = entries

   local rowCounter = 0
   local function BuildLinkRow(entry)
    rowCounter = rowCounter + 1

    local row = Instance.new("Frame")
    row.Name = "LinkRow"
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = rowCounter
    row.Parent = entries

    local box = Instance.new("TextBox")
    box.Name = "Input"
    box.Size = UDim2.new(1, -6, 1, 0)
    box.BackgroundColor3 = BG_DARK
    box.BackgroundTransparency = 0.15
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.TextColor3 = TEXT_LIGHT
    box.PlaceholderText = "example.com"
    box.PlaceholderColor3 = TEXT_DIM
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.ClipsDescendants = true
    box.Text = entry.raw
    box.Parent = row
    NewCorner(6, box)
    NewStroke(box, Color3.fromRGB(255, 255, 255), 1, 0.88)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 26)
    pad.Parent = box

    local removeBtn = Instance.new("TextButton")
    removeBtn.Name = "Remove"
    removeBtn.AutoButtonColor = false
    removeBtn.AnchorPoint = Vector2.new(1, 0.5)
    removeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    removeBtn.Size = UDim2.new(0, 18, 0, 18)
    removeBtn.BackgroundTransparency = 1
    removeBtn.BorderSizePixel = 0
    removeBtn.Font = Enum.Font.GothamBold
    removeBtn.TextSize = 13
    removeBtn.TextColor3 = TEXT_DIM
    removeBtn.Text = "x"
    removeBtn.ZIndex = 2
    removeBtn.Parent = row

    removeBtn.MouseEnter:Connect(function()
     removeBtn.TextColor3 = RED
    end)
    removeBtn.MouseLeave:Connect(function()
     removeBtn.TextColor3 = TEXT_DIM
    end)
    removeBtn.MouseButton1Click:Connect(function()
     VyrnoxGuard.RemoveWhitelistedLink(entry)
     row:Destroy()
    end)

    box.FocusLost:Connect(function()
     VyrnoxGuard.SetWhitelistedLink(entry, box.Text)
     box.Text = entry.raw
    end)

    return box
   end

   for _, entry in ipairs(VyrnoxGuard.WhitelistedLinks) do
    BuildLinkRow(entry)
   end

   addBtn.MouseButton1Click:Connect(function()
    local entry = VyrnoxGuard.AddWhitelistedLink("")
    local box = BuildLinkRow(entry)
    box:CaptureFocus()
   end)
  end

  do
   local scanOrderBase = #toggleDefs * 10 + 10

   local spacer = Instance.new("Frame")
   spacer.Size = UDim2.new(1, 0, 0, 6)
   spacer.BackgroundTransparency = 1
   spacer.LayoutOrder = scanOrderBase + 1
   spacer.Parent = leftPanel

   local scanSlot = Instance.new("Frame")
   scanSlot.Name = "ScanSlot"
   scanSlot.Size = UDim2.new(1, 0, 0, 40)
   scanSlot.BackgroundTransparency = 1
   scanSlot.LayoutOrder = scanOrderBase + 2
   scanSlot.Parent = leftPanel

   local scanBtn = Instance.new("TextButton")
   scanBtn.Name = "ScanButton"
   scanBtn.AutoButtonColor = false
   scanBtn.AnchorPoint = Vector2.new(0.5, 0.5)
   scanBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
   scanBtn.Size = UDim2.new(1, 0, 0, 34)
   scanBtn.BackgroundColor3 = CALM
   scanBtn.Font = Enum.Font.GothamBold
   scanBtn.TextSize = 13
   scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
   scanBtn.Text = "Scan Workspace Files"
   scanBtn.Parent = scanSlot
   NewCorner(9, scanBtn)

   local baseColor = CALM
   local hoverColor = CALM:Lerp(Color3.fromRGB(255, 255, 255), 0.15)
   local runningColor = KNOB_OFF
   local baseSize = scanBtn.Size
   local hoverSize = UDim2.new(1, 6, 0, 37)

   scanBtn.MouseEnter:Connect(function()
    if IsFileScanRunning and IsFileScanRunning() then return end
    TweenService:Create(scanBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = hoverColor,
     Size = hoverSize,
    }):Play()
   end)
   scanBtn.MouseLeave:Connect(function()
    if IsFileScanRunning and IsFileScanRunning() then return end
    TweenService:Create(scanBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = baseColor,
     Size = baseSize,
    }):Play()
   end)

   scanBtn.MouseButton1Click:Connect(function()
    if IsFileScanRunning and IsFileScanRunning() then
     Console("warn", "Scan already running, please wait for it to finish.")
     return
    end
    if not TriggerFileScan then
     Console("warn", "Scan is not available yet, try again in a moment.")
     return
    end

    scanBtn.Text = "Scanning..."
    scanBtn.BackgroundColor3 = runningColor

    TriggerFileScan(function(ok)
     scanBtn.Text = ok and "Scan Complete" or "Scan Failed"
     scanBtn.BackgroundColor3 = ok and baseColor or RED
     spawn_func(function()
      wait_func(1.5)
      scanBtn.Text = "Scan Workspace Files"
      scanBtn.BackgroundColor3 = baseColor
     end)
    end)
   end)
  end

  do
   local function BuildStatRow(order)
    local row = Instance.new("TextLabel")
    row.Name = "StatRow" .. order
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 18)
    row.Font = Enum.Font.GothamMedium
    row.TextSize = 12
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextColor3 = TEXT_LIGHT
    row.Text = ""
    row.LayoutOrder = order
    row.Parent = statsPanel
    return row
   end

   local function BuildSectionHeader(text, order)
    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 20)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 12
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = TEXT_DIM
    header.Text = text
    header.LayoutOrder = order
    header.Parent = statsPanel
    return header
   end

   local headlineRows = {
    BuildStatRow(1),
    BuildStatRow(2),
    BuildStatRow(3),
    BuildStatRow(4),
   }

   BuildSectionHeader("BLOCKED BY REASON", 5)
   local breakdownRows = {}

   local function ClearBreakdownRows()
    for _, row in ipairs(breakdownRows) do
     row:Destroy()
    end
    breakdownRows = {}
   end

   RefreshStatsPanel = function()
    local totals = StatsStore.GetTotals()
    headlineRows[1].Text = "Threats blocked: " .. totals.Blocked
    headlineRows[2].Text = "Flagged events: " .. totals.Events
    headlineRows[3].Text = "HTTP requests seen: " .. totals.Http
    headlineRows[4].Text = "Tracking since: " .. os.date("%Y-%m-%d %H:%M", totals.Since)

    ClearBreakdownRows()

    if #totals.ReasonOrder == 0 then
     local row = BuildStatRow(6)
     row.TextColor3 = TEXT_DIM
     row.Text = "  (none yet)"
     table.insert(breakdownRows, row)
    else
     for i, r in ipairs(totals.ReasonOrder) do
      local row = BuildStatRow(6 + i)
      row.AutomaticSize = Enum.AutomaticSize.Y
      row.Size = UDim2.new(1, 0, 0, 0)
      row.TextWrapped = true
      row.Text = string.format("  %d  %s", totals.Reasons[r], r)
      table.insert(breakdownRows, row)
     end
    end
   end

   local resetSlot = Instance.new("Frame")
   resetSlot.Name = "ResetStatsSlot"
   resetSlot.Size = UDim2.new(1, 0, 0, 40)
   resetSlot.BackgroundTransparency = 1
   resetSlot.LayoutOrder = 1000
   resetSlot.Parent = statsPanel

   local resetBtn = Instance.new("TextButton")
   resetBtn.Name = "ResetStatsButton"
   resetBtn.AutoButtonColor = false
   resetBtn.AnchorPoint = Vector2.new(0.5, 0.5)
   resetBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
   resetBtn.Size = UDim2.new(1, 0, 0, 34)
   resetBtn.BackgroundColor3 = RED
   resetBtn.Font = Enum.Font.GothamBold
   resetBtn.TextSize = 13
   resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
   resetBtn.Text = "Reset Stats"
   resetBtn.Parent = resetSlot
   NewCorner(9, resetBtn)

   local resetBase = RED
   local resetHover = RED:Lerp(Color3.fromRGB(255, 255, 255), 0.15)
   resetBtn.MouseEnter:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = resetHover,
    }):Play()
   end)
   resetBtn.MouseLeave:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = resetBase,
    }):Play()
   end)

   local resetToken = 0
   local resetArmed = false
   resetBtn.MouseButton1Click:Connect(function()
    resetToken = resetToken + 1
    local myToken = resetToken

    if not resetArmed then
     resetArmed = true
     resetBtn.Text = "Click again to confirm"
     spawn_func(function()
      wait_func(3)
      if myToken == resetToken and resetArmed then
       resetArmed = false
       resetBtn.Text = "Reset Stats"
      end
     end)
     return
    end

    resetArmed = false
    local ok = StatsStore.Reset()
    RefreshStatsPanel()
    resetBtn.Text = ok and "Stats Reset!" or "Reset Failed"
    spawn_func(function()
     wait_func(1.5)
     if myToken == resetToken then
      resetBtn.Text = "Reset Stats"
     end
    end)
   end)

   RefreshStatsPanel()

   spawn_func(function()
    while true do
     wait_func(2)
     if statsPanel.Visible then
      RefreshStatsPanel()
     end
    end
   end)
  end

  ApplyTheme(CountEnabled() / totalToggles)
 end)

 if not ok_ui then
  Console("warn", "Failed to build control panel UI: " .. tostring(ui_err))
 end
end)

local MaxBodySize = 8192
local SeenHosts = {}
local function CheckFirstContact(host)
 if host == "" then return false end
 if not SeenHosts[host] then
  SeenHosts[host] = true
  return true
 end
 return false
end

local HostByteTotals = {}
local MaxCumulativeBytes = 32768
local function TrackHostBytes(host, size)
 HostByteTotals[host] = (HostByteTotals[host] or 0) + size
 return HostByteTotals[host]
end

local FirstContactTimestamps = {}
local BurstWindowSeconds = 5
local BurstThresholdCount = 4
local function CheckFirstContactBurst()
 local now = (tick and tick()) or os.clock()
 table.insert(FirstContactTimestamps, now)
 while #FirstContactTimestamps > 0 and now - FirstContactTimestamps[1] > BurstWindowSeconds do
  table.remove(FirstContactTimestamps, 1)
 end
 return #FirstContactTimestamps >= BurstThresholdCount, #FirstContactTimestamps
end

local function UrlDecode(str)
 if typeof(str) ~= "string" then return "" end
 str = str:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
 return str:gsub("+", " ")
end

local function FullyUrlDecode(str, maxPasses)
 maxPasses = maxPasses or 5
 local current = str
 for _ = 1, maxPasses do
  local decoded = UrlDecode(current)
  if decoded == current then break end
  current = decoded
 end
 return current
end

local b64chars = "^[%a%d%+%/=]+$"
local function TryBase64Decode(str)
 if typeof(str) ~= "string" or #str < 8 then return nil end
 if not str:match(b64chars) then return nil end
 if #str % 4 ~= 0 then return nil end
 local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
 local decodeTable = {}
 for i = 1, #b64 do decodeTable[b64:sub(i, i)] = i - 1 end
 local input = str:gsub("=", "")
 local bits, value, output = 0, 0, {}
 for i = 1, #input do
  local c = input:sub(i, i)
  local d = decodeTable[c]
  if not d then return nil end
  value = (value * 64) + d
  bits = bits + 6
  if bits >= 8 then
   bits = bits - 8
   local byte = math.floor(value / (2 ^ bits)) % 256
   table.insert(output, string.char(byte))
  end
 end
 local ok, result = pcall(table.concat, output)
 if ok then return result end
 return nil
end

local DeobfuscateCache = {}
local DeobfuscateCacheOrder = {}
local MaxDeobfuscateCacheSize = 256
local MaxDeobfuscateInputLen = 32768

local function CacheDeobfuscated(key, value)
 if not DeobfuscateCache[key] then
  table.insert(DeobfuscateCacheOrder, key)
  if #DeobfuscateCacheOrder > MaxDeobfuscateCacheSize then
   local oldest = table.remove(DeobfuscateCacheOrder, 1)
   DeobfuscateCache[oldest] = nil
  end
 end
 DeobfuscateCache[key] = value
 return value
end

local function Deobfuscate(str)
 if typeof(str) ~= "string" or str == "" then return "" end
 if #str > MaxDeobfuscateInputLen then return str end
 local cached = DeobfuscateCache[str]
 if cached then return cached end

 local current = str
 local lastState
 local passes = 0
 repeat
  lastState = current
  passes = passes + 1

  current = current:gsub("\\x(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
  current = current:gsub("\\(%d%d%d)", function(d)
   local v = tonumber(d)
   return (v and v <= 255) and string.char(v) or ("\\" .. d)
  end)
  current = current:gsub("\\u(%x%x%x%x)", function(h)
   local c = tonumber(h, 16)
   return (c and c <= 255) and string.char(c) or ""
  end)
  current = current:gsub("([01][01][01][01][01][01][01][01][%s,_]?[01][01][01][01][01][01][01][01][%s,_]?[01][01][01][01][01][01][01][01])", function(chain)
   local resolved = chain:gsub("[01][01][01][01][01][01][01][01]", function(b)
    local v = tonumber(b, 2)
    return (v and v > 31 and v < 127) and string.char(v) or b
   end)
   return resolved:gsub("[%s,_]", "")
  end)
 until current == lastState or passes >= 5

 return CacheDeobfuscated(str, current)
end

local function ExtractHost(url)
 url = (url:gsub("%c", ""))
 url = url:match("^%s*(.-)%s*$")
 local stripped = url:match("^%a[%w%+%.%-]*:[/\\]+(.*)$") or url
 local authority = stripped:match("^([^/?#\\]*)") or stripped
 authority = authority:match("^.*@(.*)$") or authority

 local bracketed = authority:match("^%[([^%]]+)%]")
 if bracketed then
  return bracketed
 end

 local colonCount = 0
 for _ in authority:gmatch(":") do colonCount = colonCount + 1 end
 if colonCount >= 2 and authority:match("^[%x:]+$") then
  return authority
 end

 local host = authority:match("^([^:]+)") or authority
 host = (host:gsub("%.+$", ""))
 return host
end

local function MatchesDomainList(host, list)
 for _, domain in ipairs(list) do
  if host == domain or host:sub(-(#domain + 1)) == "." .. domain then
   return true, domain
  end
 end
 return false, nil
end

local RuntimeBlockedDomains = {}
local function MarkRuntimeBlocked(host, reason)
 if not RuntimeBlockedDomains[host] then
  RuntimeBlockedDomains[host] = true
  LogEvent("runtime-blacklist", host .. ", " .. reason)
 end
end

local function BlockedDomain(host)
 if RuntimeBlockedDomains[host] then
  return true, host .. " (learned this session)"
 end
 return MatchesDomainList(host, BlockedDomains)
end
local function IsWhitelistedHost(host) return MatchesDomainList(host, WhitelistedDomains) end

local function ParseWhitelistEntry(raw)
 local s = raw:lower():match("^%s*(.-)%s*$")
 s = s:gsub("^%a[%w%+%.%-]*://", "")
 local hostPart, rest = s:match("^([^/?#]+)(.*)$")
 if not hostPart then return nil end
 hostPart = hostPart:gsub(":%d+$", "")
 hostPart = hostPart:gsub("^%*%.", "")
 if hostPart == "" then return nil end
 local path = rest:match("^(/[^?#]*)")
 if path == "/" then path = nil end
 return hostPart, path
end

function VyrnoxGuard.IsUserWhitelistedUrl(url)
 local list = VyrnoxGuard.WhitelistedLinks
 if typeof(url) ~= "string" or url == "" or #list == 0 then return false end
 if url:find("[%c\\]") then return false end
 local lowered = url:lower()
 local decoded = FullyUrlDecode(lowered)
 if decoded:find("[%c\\]") then return false end
 local host = ExtractHost(lowered)
 if host == "" or host ~= ExtractHost(decoded) then return false end
 local rest = lowered:gsub("^%a[%w%+%.%-]*://", "")
 local urlPath = rest:match("^[^/?#]*(/[^?#]*)")
 local decodedPath = urlPath and FullyUrlDecode(urlPath) or nil
 if decodedPath and (decodedPath .. "/"):find("/%.%./") then return false end
 for _, entry in ipairs(list) do
  if entry.parsedFor ~= entry.raw then
   entry.parsedFor = entry.raw
   entry.host, entry.path = ParseWhitelistEntry(entry.raw)
  end
  local eh = entry.host
  if eh and (host == eh or host:sub(-(#eh + 1)) == "." .. eh) then
   local ep = entry.path
   if not ep then
    return true
   end
   if urlPath and urlPath:sub(1, #ep) == ep and decodedPath:sub(1, #ep) == ep then
    local nextChar = urlPath:sub(#ep + 1, #ep + 1)
    if nextChar == "" or nextChar == "/" or ep:sub(-1) == "/" then
     return true
    end
   end
  end
 end
 return false
end
local function IsHighVolumeTrusted(host) return MatchesDomainList(host, HighVolumeTrustedDomains) end

local KnownGiveaways = {
 "ip logger", "iplogger", "grabify", "ip grabber", "grab your ip",
 "track your ip", "logs your ip address", "captures your ip",
 "ip tracking service", "shorten url ip", "ip address tracking",
}

local function ScanForGiveaways(bodyStr)
 if typeof(bodyStr) ~= "string" or bodyStr == "" then return nil end
 local lower = bodyStr:lower()
 for _, phrase in ipairs(KnownGiveaways) do
  if lower:find(phrase, 1, true) then
   return phrase
  end
 end
 return nil
end

local LocationFieldNamesSoft = {
 "country", "region", "city", "zip", "postal", "lat", "latitude", "lon",
 "longitude", "timezone", "country_code", "region_code",
 "continent", "continent_code", "currency", "calling_code", "area_code",
 "metro_code", "organization",
}
local LocationFieldNamesHard = {
 "isp", "org", "asn", "ip", "ipaddress", "ip_address", "query",
 "origin", "ipv4", "ipv6", "publicip", "public_ip",
}
local LocationFieldSet = {}
for _, f in ipairs(LocationFieldNamesSoft) do LocationFieldSet[f] = "soft" end
for _, f in ipairs(LocationFieldNamesHard) do LocationFieldSet[f] = "hard" end

local LocationFieldThreshold = 5

local function ScanJSONForLocationSchema(bodyStr)
 if typeof(bodyStr) ~= "string" or bodyStr == "" then return false, 0 end
 local ok, decoded = pcall(function()
  return game:GetService("HttpService"):JSONDecode(bodyStr)
 end)
 if not ok or typeof(decoded) ~= "table" then return false, 0 end

 local matches = 0
 local hardMatches = 0
 local function Scan(t, depth)
  if depth > 4 then return end
  for k, v in pairs(t) do
   if typeof(k) == "string" then
    local kind = LocationFieldSet[k:lower()]
    if kind then
     matches = matches + 1
     if kind == "hard" then hardMatches = hardMatches + 1 end
    end
   end
   if typeof(v) == "table" then
    Scan(v, depth + 1)
   end
  end
 end
 pcall(Scan, decoded, 0)

 local isLocationSchema = matches >= LocationFieldThreshold and hardMatches >= 1
 return isLocationSchema, matches
end

local SuspiciousHeaderNames = {
 "^x%-forwarded%-for$", "^x%-real%-ip$", "^cf%-connecting%-ip$", "^x%-client%-ip$",
 "^forwarded$", "^true%-client%-ip$", "^x%-forwarded%-host$", "^x%-originating%-ip$",
 "^client%-ip$", "^remote%-addr$",
}

local function HasSuspiciousHeaderNames(headers)
 if typeof(headers) ~= "table" then return false, nil end
 for key in pairs(headers) do
  local lowered = tostring(key):lower()
  for _, pattern in ipairs(SuspiciousHeaderNames) do
   if lowered:match(pattern) then
    return true, tostring(key)
   end
  end
 end
 return false, nil
end

local function InspectResponseForGiveaways(host, bodyStr, responseHeaders)
 if host == "" or IsWhitelistedHost(host) or RuntimeBlockedDomains[host] then return false end

 local match = ScanForGiveaways(bodyStr)
 if match then
  MarkRuntimeBlocked(host, 'response matched blocklist "' .. match .. '"')
  return true
 end

 local isLocationSchema, fieldCount = ScanJSONForLocationSchema(bodyStr)
 if isLocationSchema then
  MarkRuntimeBlocked(host, "response JSON matched geolocation/logger schema (" .. fieldCount .. " matching fields)")
  return true
 end

 local susHeader, headerName = HasSuspiciousHeaderNames(responseHeaders)
 if susHeader then
  MarkRuntimeBlocked(host, "response contained suspicious IP-forwarding header: " .. headerName)
  return true
 end

 return false
end

local IPLookupCandidates = {
 "https://api.ipify.org", "https://icanhazip.com",
 "https://checkip.amazonaws.com", "https://ident.me"
}

local UserIP = nil
local function FetchUserIP()
 if not request_func then
  Console("warn", "No raw request available, IP-leak detection disabled")
  return
 end
 for _, url in ipairs(IPLookupCandidates) do
  local ok, res = pcall(request_func, { Url = url, Method = "GET" })
  if ok and res and res.Body then
   local candidate = res.Body:gsub("%s+", "")
   if candidate:match("^%d+%.%d+%.%d+%.%d+$") or candidate:match("^[%x:]+$") then
    UserIP = candidate
    return
   end
  end
 end
 Console("warn", "Could not determine user IP, IP-leak detection disabled")
end
FetchUserIP()

local function ContainsUserIP(str)
 if not UserIP or typeof(str) ~= "string" then return false end
 local escaped = UserIP:gsub("[%.%-]", "%%%1")
 local pattern = "%f[%w]" .. escaped .. "%f[%W]"
 local pos = 1
 while true do
  local s, e = str:find(pattern, pos)
  if not s then return false end
  local before = str:sub(s - 1, s - 1)
  local after = str:sub(e + 1, e + 1)
  if before ~= "." and after ~= "." and not before:match("%d") and not after:match("%d") then
   return true
  end
  pos = e + 1
 end
end

local function ScrubUserIP(str)
 if not (ProtectIP and FakeIPEnabled and UserIP) or typeof(str) ~= "string" or str == "" then
  return str, false
 end
 local escaped = UserIP:gsub("[%.%-]", "%%%1")
 local pattern = "%f[%w]" .. escaped .. "%f[%W]"
 local fake = GetFakeIP()
 local changed = false
 local out = {}
 local pos = 1
 while true do
  local s, e = str:find(pattern, pos)
  if not s then
   table.insert(out, str:sub(pos))
   break
  end
  local before = str:sub(s - 1, s - 1)
  local after = str:sub(e + 1, e + 1)
  if before ~= "." and after ~= "." and not before:match("%d") and not after:match("%d") then
   table.insert(out, str:sub(pos, s - 1))
   table.insert(out, fake)
   changed = true
  else
   table.insert(out, str:sub(pos, e))
  end
  pos = e + 1
 end
 return table.concat(out), changed
end

local function ScrubHeaders(headers)
 if not (ProtectIP and FakeIPEnabled and UserIP) or typeof(headers) ~= "table" then
  return headers, false
 end
 local changed = false
 local out = {}
 for k, v in pairs(headers) do
  if typeof(v) == "string" then
   local scrubbed, didChange = ScrubUserIP(v)
   out[k] = scrubbed
   if didChange then changed = true end
  else
   out[k] = v
  end
 end
 return out, changed
end

local function ApplyScrubbedOptions(options, scrubbedUrl, urlChanged, scrubbedBody, bodyChanged, scrubbedHeaders, headersChanged)
 if not (urlChanged or bodyChanged or headersChanged) then return options end
 local out = {}
 for k, v in pairs(options) do out[k] = v end
 if urlChanged then
  if out.Url ~= nil then out.Url = scrubbedUrl else out.url = scrubbedUrl end
 end
 if bodyChanged then
  if out.Body ~= nil then out.Body = scrubbedBody else out.body = scrubbedBody end
 end
 if headersChanged then
  if out.Headers ~= nil then out.Headers = scrubbedHeaders else out.headers = scrubbedHeaders end
 end
 return out
end

local WebhookSignatures = {
 {"Discord", "/api/webhooks/"},
 {"Discord", "/api/v%d+/webhooks/", true},
 {"Discord", "discord[%w%.%-]*%.com/api/v%d+/channels/%d+/messages", true},
 {"Discord", "webhook.lewisakura.moe"},
 {"Discord", "hooks.hyra.io"},
 {"Telegram", "api.telegram.org"},
 {"Slack", "hooks.slack.com"},
 {"Microsoft Teams", "webhook.office.com"},
 {"Microsoft Teams", "outlook.office.com/webhook"},
 {"Microsoft Teams", "outlook.office365.com/webhook"},
 {"Power Automate", "logic.azure.com"},
 {"Google Chat", "chat.googleapis.com/v1/spaces/"},
 {"Guilded", "guilded.gg/webhooks"},
 {"LINE Notify", "notify-api.line.me"},
 {"Pushover", "api.pushover.net"},
 {"Pushbullet", "api.pushbullet.com"},
 {"ntfy", "ntfy.sh/"},
 {"Zapier", "hooks.zapier.com"},
 {"IFTTT", "maker.ifttt.com"},
 {"Make", "hook%.[%w%-]+%.make%.com", true},
 {"Make", "hook.integromat.com"},
 {"n8n", "n8n.cloud/webhook"},
 {"webhook.site", "webhook.site"},
 {"Pipedream", "pipedream.net"},
 {"RequestCatcher", "requestcatcher.com"},
 {"RequestBin", "requestbin.com"},
 {"RequestBin", "requestbin.net"},
 {"Hookbin", "hookbin.com"},
 {"Beeceptor", "beeceptor.com"},
 {"Mockbin", "mockbin.org"},
 {"Postb.in", "postb.in"},
 {"PTSV2", "ptsv2.com"},
 {"Hookdeck", "hookdeck.com"},
 {"Smee", "smee.io"},
 {"Request Inspector", "requestinspector.com"},
 {"Burp Collaborator", "burpcollaborator.net"},
 {"Interactsh", "interact.sh"},
 {"Canarytokens", "canarytokens.com"},
 {"ngrok", "ngrok.io"},
 {"ngrok", "ngrok-free.app"},
 {"ngrok", "ngrok-free.dev"},
 {"ngrok", "ngrok.app"},
 {"ngrok", "ngrok.dev"},
 {"Cloudflare Tunnel", "trycloudflare.com"},
 {"localtunnel", "loca.lt"},
 {"Serveo", "serveo.net"},
 {"localhost.run", "localhost.run"},
 {"localhost.run", "lhr.life"},
 {"Pastebin upload", "pastebin.com/api"},
 {"Hastebin upload", "hastebin.com/documents"},
 {"dpaste upload", "dpaste.com/api"},
 {"Catbox upload", "catbox.moe/user/api.php"},
 {"Litterbox upload", "catbox.moe/resources/internals/api.php"},
 {"GoFile upload", "gofile.io/uploadfile"},
 {"file.io upload", "%f[%w]file%.io/?$", true},
 {"file.io upload", "%f[%w]file%.io/?%?", true},
 {"temp.sh upload", "%f[%w]temp%.sh/upload", true},
 {"Formspree", "formspree.io"},
 {"FormSubmit", "formsubmit.co"},
 {"Getform", "getform.io"},
 {"Web3Forms", "web3forms.com"},
 {"EmailJS", "api.emailjs.com"},
}

local function FindWebhookSignature(text)
 if typeof(text) ~= "string" or text == "" then return nil end
 local lower = text:lower()
 for _, sig in ipairs(WebhookSignatures) do
  if lower:find(sig[2], 1, not sig[3]) then
   return sig[1]
  end
 end
 return nil
end

local function ScanString(str, checkDeobfuscated)
 if typeof(str) ~= "string" or str == "" then return false, nil end

 if ProtectCookies and str:find(cookies, 1, true) then
  return true, "Blocked request containing .ROBLOSECURITY cookie"
 end

 local decoded = FullyUrlDecode(str)
 if ProtectCookies and decoded ~= str and decoded:find(cookies, 1, true) then
  return true, "Blocked URL-encoded .ROBLOSECURITY cookie leak"
 end

 if BlockWebhooks then
  local service = FindWebhookSignature(decoded)
  if service then
   return true, "Blocked data exfiltration to Webhook (" .. service .. ")", "webhook"
  end
 end

 if ProtectDomains then
  local host = ExtractHost(decoded):lower()
  local isBad, domain = BlockedDomain(host)
  if isBad then return true, "Blocked connection to IP logger: " .. domain end
 end

 local b64Decoded = TryBase64Decode(str)
 if b64Decoded and b64Decoded ~= str then
  if ProtectCookies and b64Decoded:find(cookies, 1, true) then
   return true, "Blocked base64-encoded .ROBLOSECURITY cookie leak"
  end
  if BlockWebhooks then
   local service = FindWebhookSignature(b64Decoded)
   if service then
    return true, "Blocked base64-encoded webhook exfiltration (" .. service .. ")", "webhook"
   end
  end
 end

 if ProtectCookies then
  if #str >= #cookiesHex and str:lower():find(cookiesHex, 1, true) then
   return true, "Blocked hex-encoded .ROBLOSECURITY cookie leak"
  end
  if str:reverse():find(cookies, 1, true) then
   return true, "Blocked reversed .ROBLOSECURITY cookie leak"
  end
 end

 if ProtectTokens then
  if ContainsDiscordToken(str) then
   return true, "Blocked request containing Discord token"
  end
  if ContainsJwtToken(str) then
   return true, "Blocked request containing JWT/OAuth bearer token"
  end
  if b64Decoded and b64Decoded ~= str then
   if ContainsDiscordToken(b64Decoded) then
    return true, "Blocked base64-encoded Discord token leak"
   end
   if ContainsJwtToken(b64Decoded) then
    return true, "Blocked base64-encoded JWT/OAuth token leak"
   end
  end
 end

 if ProtectIP and ContainsUserIP(str) then
  return true, "Blocked content containing user's IP address"
 end

 if checkDeobfuscated then
  local clean = Deobfuscate(str)
  if clean ~= str and clean ~= "" then
   local bad, reason, kind = ScanString(clean, false)
   if bad then
    return true, reason .. " (found after deobfuscation)", kind
   end
  end
 end

 return false, nil
end

local function ScanHeaders(headers)
 if typeof(headers) ~= "table" then return false, nil end
 local parts = {}
 for k, v in pairs(headers) do table.insert(parts, tostring(k) .. ": " .. tostring(v)) end
 return ScanString(table.concat(parts, "\n"))
end

local function CalculateEntropy(str)
 if not str or #str == 0 then return 0 end
 local freq = {}
 local len = #str
 for i = 1, len do
  local c = str:byte(i)
  freq[c] = (freq[c] or 0) + 1
 end
 local entropy = 0
 for _, count in pairs(freq) do
  local p = count / len
  if p > 0 then entropy = entropy - p * math.log(p, 2) end
 end
 return entropy
end

local XorCheckByteCap = 2048
local cookieLen = #cookies
local cookieBytes = { cookies:byte(1, cookieLen) }

local function TryXorContainsCookie(str)
 if typeof(str) ~= "string" or str == "" or not bit32 then return false end
 local capped = str:sub(1, XorCheckByteCap)
 local n = #capped
 if n < cookieLen then return false end

 for key = 1, 255 do
  for pos = 1, n - cookieLen + 1 do
   local matched = true
   for i = 1, cookieLen do
    if bit32.bxor(capped:byte(pos + i - 1), key) ~= cookieBytes[i] then
     matched = false
     break
    end
   end
   if matched then return true end
  end
 end
 return false
end

local HostBodyBuffers = {}
local MaxBufferSize = 4096
local function AppendAndScanBuffer(host, chunk)
 if typeof(chunk) ~= "string" or chunk == "" then return false, nil end
 local buf = (HostBodyBuffers[host] or "") .. chunk
 if #buf > MaxBufferSize then
  buf = buf:sub(-MaxBufferSize)
 end
 HostBodyBuffers[host] = buf
 return ScanString(buf, true)
end

local DynamicDnsDomains = {
 "duckdns.org", "no-ip.com", "no-ip.org", "no-ip.biz", "ddns.net", "hopto.org",
 "zapto.org", "sytes.net", "mooo.com", "changeip.com", "afraid.org",
 "ngrok.io", "ngrok-free.app", "ngrok.app", "serveo.net", "localtunnel.me",
 "loca.lt", "pagekite.me", "trycloudflare.com", "portmap.io", "localhost.run",
}

local SuspiciousTlds = {
 "tk", "ml", "ga", "cf", "gq", "xyz", "top", "club", "icu", "click", "loan",
}

local function IsRawIPHost(host)
 if host:match("^%d+%.%d+%.%d+%.%d+$") then return true end

 local candidate = host:match("^%[(.+)%]$") or host
 if candidate:match("^[%x:]+$") then
  local colonCount = 0
  for _ in candidate:gmatch(":") do colonCount = colonCount + 1 end
  local _, doubleColons = candidate:gsub("::", "")
  if colonCount >= 2 and doubleColons <= 1 then
   return true
  end
 end
 return false
end

local function HasNonStandardPort(url)
 if typeof(url) ~= "string" then return false end

 local authority = url:match("^https?://([^/?#]+)")
 if not authority then return false end

 local port
 local bracketPort = authority:match("^%[[^%]]+%]:(%d+)$")
 if bracketPort then
  port = tonumber(bracketPort)
 elseif not authority:find("%[") then
  local colonCount = 0
  for _ in authority:gmatch(":") do colonCount = colonCount + 1 end
  if colonCount <= 1 then
   port = tonumber(authority:match(":(%d+)$"))
  end
 end

 return port ~= nil and port ~= 80 and port ~= 443
end

local function IsPunycodeHost(host)
 return host:find("xn--", 1, true) ~= nil
end

local function HasSuspiciousTld(host)
 local tld = host:match("%.([%a]+)$")
 return tld ~= nil and MatchesDomainList(tld:lower(), SuspiciousTlds)
end

local function IsDynamicDnsHost(host)
 return MatchesDomainList(host, DynamicDnsDomains)
end

local function HasHighEntropyLabel(host)
 local label = host:match("^([^%.]+)")
 if not label or #label < 20 then return false end
 return CalculateEntropy(label) > 4.3
end

local function ScoreC2Suspicion(url, host, body, method)
 if host == "" then return 0, "" end
 local score = 0
 local reasons = {}
 local extraReasons = {}

 local rawIP = IsRawIPHost(host)
 local dynDns = IsDynamicDnsHost(host)

 if rawIP then score = score + 3; table.insert(reasons, "raw IP address") end
 if dynDns then score = score + 2; table.insert(reasons, "dynamic DNS/tunnel provider") end
 if IsPunycodeHost(host) then score = score + 2; table.insert(reasons, "punycode/homograph domain") end
 if HasHighEntropyLabel(host) then score = score + 1; table.insert(reasons, "high-entropy subdomain (possible DGA)") end

 if HasNonStandardPort(url) then
  if rawIP or dynDns then
   score = score + 2
   table.insert(reasons, "non-standard port")
  else
   table.insert(extraReasons, "non-standard port")
  end
 end

 if HasSuspiciousTld(host) then
  table.insert(extraReasons, "disposable-leaning TLD")
 end

 if method == "POST" and typeof(body) == "string" and #body > 200 then
  local entropy = CalculateEntropy(body)
  if entropy > 7.2 then
   score = score + 1
   table.insert(reasons, string.format("high-entropy payload (%.2f)", entropy))
  end
 end

 if #extraReasons > 0 then
  table.insert(reasons, "noted: " .. table.concat(extraReasons, ", "))
 end

 return score, table.concat(reasons, ", ")
end

local function UrlEncode(str)
 return (str:gsub("[^%w%-%.%_%~]", function(c)
  return string.format("%%%02X", c:byte())
 end))
end

local function CloudReputationCheck(url)
 if not ProtectCloudReputation or CRE == "" or not request_func then
  return nil
 end

 local ok, response = pcall(request_func, {
  Url = CRE .. "?url=" .. UrlEncode(url),
  Method = "GET",
 })
 if not ok or typeof(response) ~= "table" or response.StatusCode ~= 200 or typeof(response.Body) ~= "string" then
  return nil
 end

 local decodeOk, data = pcall(function()
  return game:GetService("HttpService"):JSONDecode(response.Body)
 end)
 if not decodeOk or typeof(data) ~= "table" then
  return nil
 end

 if data.malicious == true then
  return true, typeof(data.reason) == "string" and data.reason or "flagged by cloud reputation check"
 elseif data.malicious == false then
  return false, nil
 end
 return nil
end

local C2BlockThreshold = 4

local function ThreatScan(url, body, headers, method)
 if typeof(url) == "string" then
  local noCtl = url:gsub("%c", "")
  local afterScheme = noCtl:gsub("^%s*%a[%w%+%.%-]*:[/\\]+", "")
  local authority = afterScheme:match("^([^/?#]*)")
  if authority and authority:find("\\", 1, true) then
   return true, "Blocked URL with a backslash in its host (parser-confusion trick to disguise the real destination)"
  end
 end
 local host = ExtractHost(FullyUrlDecode(typeof(url) == "string" and url or "")):lower()
 if IsWhitelistedHost(host) then return false, nil end

 local trustedVolume = IsHighVolumeTrusted(host)

 if ProtectDomains and not trustedVolume then
  local c2Score, c2Reasons = ScoreC2Suspicion(url, host, body, method)
  if c2Score >= C2BlockThreshold then
   return true, "Blocked, possible C2 infrastructure (" .. c2Reasons .. ")"
  elseif c2Score > 0 then
   LogEvent("c2-suspicion", host .. " meter " .. c2Score .. " (" .. c2Reasons .. ")")
   if method ~= "POST" or typeof(body) ~= "string" or #body < 4096 then
    local cloudBad, cloudReason = CloudReputationCheck(url)
    if cloudBad then
     return true, "Blocked, cloud reputation check (" .. cloudReason .. ")"
    end
   end
  end
 end

 local bad, reason, kind = ScanString(url, true)
 if bad then return true, reason, kind end
 bad, reason, kind = ScanString(body, true)
 if bad then return true, reason, kind end
 bad, reason = ScanHeaders(headers)
 if bad then return true, reason end

 if ProtectIP and not trustedVolume then
  local susHeader, headerName = HasSuspiciousHeaderNames(headers)
  if susHeader then
   return true, "Blocked request setting suspicious IP-forwarding header: " .. headerName
  end
 end

 if ProtectCookies and typeof(body) == "string" and body ~= "" then
  if TryXorContainsCookie(body) then
   return true, "Blocked XOR-obfuscated .ROBLOSECURITY cookie leak"
  end
  local bufBad, bufReason = AppendAndScanBuffer(host, body)
  if bufBad then
   return true, "Blocked (reassembled across multiple requests): " .. bufReason
  end
 end

 local firstContact = CheckFirstContact(host)
 local bodySize = typeof(body) == "string" and #body or 0

 if firstContact then
  LogEvent("first-contact", host .. " (" .. bodySize .. " bytes)", "info")
  local burst, count = CheckFirstContactBurst()
  if burst then
   LogEvent("first-contact-burst", string.format("%d new hosts contacted within %ds", count, BurstWindowSeconds))
  end
 end

 if bodySize > MaxBodySize then
  if trustedVolume then
   LogEvent("oversized-allowed", string.format("%d bytes to trusted AI host %s", bodySize, host), "info")
  elseif firstContact then
   LogEvent("oversized-first-contact", string.format("%d bytes to unseen host %s (allowed, watch cumulative total)", bodySize, host))
  else
   LogEvent("oversized-allowed", string.format("%d bytes to known host %s", bodySize, host), "info")
  end
 end

 if not trustedVolume then
  local cumulative = TrackHostBytes(host, bodySize)
  if cumulative > MaxCumulativeBytes then
   return true, string.format("Blocked cumulative payload to %s (%d bytes)", host, cumulative)
  end
 end

 return false, nil
end

local function ScanArgs(...)
 local n = select("#", ...)
 for i = 1, n do
  local v = select(i, ...)
  if typeof(v) == "string" then
   local bad, reason = ScanString(v)
   if bad then return true, reason end
  end
 end
 return false, nil
end

function VyrnoxGuard.WhitelistLeakCheck(url, body, headers)
 if not ProtectCookies then return false, nil end
 local function leaks(str)
  if typeof(str) ~= "string" or str == "" then return nil end
  if str:find(cookies, 1, true) then return "Blocked request containing .ROBLOSECURITY cookie" end
  local decoded = FullyUrlDecode(str)
  if decoded ~= str and decoded:find(cookies, 1, true) then return "Blocked URL-encoded .ROBLOSECURITY cookie leak" end
  local b64 = TryBase64Decode(str)
  if b64 and b64:find(cookies, 1, true) then return "Blocked base64-encoded .ROBLOSECURITY cookie leak" end
  if #str >= #cookiesHex and str:lower():find(cookiesHex, 1, true) then return "Blocked hex-encoded .ROBLOSECURITY cookie leak" end
  if str:reverse():find(cookies, 1, true) then return "Blocked reversed .ROBLOSECURITY cookie leak" end
  if TryXorContainsCookie(str) then return "Blocked XOR-obfuscated .ROBLOSECURITY cookie leak" end
  return nil
 end
 local reason = leaks(url) or leaks(body)
 if not reason and typeof(headers) == "table" then
  local parts = {}
  for k, v in pairs(headers) do table.insert(parts, tostring(k) .. ": " .. tostring(v)) end
  reason = leaks(table.concat(parts, "\n"))
 end
 if reason then return true, reason end
 return false, nil
end

local HookWatchList = {}
Safe.Hidden[HookWatchList] = true
local function RegisterHookWatch(label, getCurrent, kind, repair)
 local ok, baseline = pcall(getCurrent)
 if not ok then return end
 local entry = { label = label, getCurrent = getCurrent, baseline = baseline, tamperedWarned = false, kind = kind, repair = repair, repairs = 0, okStreak = 0 }
 Safe.Hidden[entry] = true
 if repair then Safe.Hidden[repair] = true end
 table.insert(HookWatchList, entry)
end
for _, g in ipairs(Safe.RestoreGuards or {}) do
 RegisterHookWatch("restore:" .. g.name, g.getCurrent, "restore", {
  set = g.setCurrent,
  rehook = g.hooked and function(f) pcall(hook_func, f, g.guard) end or nil,
 })
end

local http_targets = {
 {"request", env.request, function() return env.request end, function(v) env.request = v end},
 {"http_request", env.http_request, function() return env.http_request end, function(v) env.http_request = v end},
}

local namespaces = { "syn", "fluxus", "krnl", "proto", "scriptware", "delta", "WR", "electron", "macsploit", "http", "sirhurt", "temple" }
for _, ns in ipairs(namespaces) do
 local obj = env[ns]
 if typeof(obj) == "table" then
  if typeof(obj.request) == "function" then
   table.insert(http_targets, {ns .. ".request", obj.request, function() local o = env[ns]; return o and o.request end, function(v) local o = env[ns]; if o then o.request = v end end})
  end
  if typeof(obj.get) == "function" then
   table.insert(http_targets, {ns .. ".get", obj.get, function() local o = env[ns]; return o and o.get end, function(v) local o = env[ns]; if o then o.get = v end end})
  end
  if typeof(obj.post) == "function" then
   table.insert(http_targets, {ns .. ".post", obj.post, function() local o = env[ns]; return o and o.post end, function(v) local o = env[ns]; if o then o.post = v end end})
  end
 end
end

local hooked_functions = {}
Safe.Hidden[hooked_functions] = true
Safe.Hidden[http_targets] = true
if hook_func then
 for _, target in ipairs(http_targets) do
  local name, func, getCurrent, setCurrent = target[1], target[2], target[3], target[4]
  if typeof(func) == "function" and not hooked_functions[func] then
   local old
   local wrapper = cclosure(function(options)
    CountHttpRequestSeen()
    local url, body, headers, method = "", "", nil, nil
    local optsIsTable = Safe.typeof(options) == "table"
    if optsIsTable then
     url = options.Url or options.url or ""
     body = options.Body or options.body or ""
     headers = options.Headers or options.headers
     method = options.method or options.Method
    elseif Safe.typeof(options) == "string" then
     url = options
    end

    if VyrnoxGuard.IsUserWhitelistedUrl(url) then
     local leak, leakReason = VyrnoxGuard.WhitelistLeakCheck(url, body, headers)
     if leak then
      Console("warn", leakReason .. " [Hook: " .. name .. "] (whitelisted host, still blocked)")
      LogBlock(leakReason, name, url)
      return {StatusCode = 403, Success = false, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
     end
     return old(options)
    end

    local scrubbedUrl, urlChanged = ScrubUserIP(url)
    local scrubbedBody, bodyChanged = ScrubUserIP(body)
    local scrubbedHeaders, headersChanged = ScrubHeaders(headers)

    local bad, reason, kind = ThreatScan(scrubbedUrl, scrubbedBody, scrubbedHeaders, method)
    if bad then
     if kind == "webhook" and not BlockWebhooksHardBlock then
      Console("warn", reason .. " [Hook: " .. name .. "] (Block is off, letting it through)")
      LogEvent("webhook-passthrough", reason .. " -> " .. tostring(scrubbedUrl), "warn")
     else
      Console("warn", reason .. " [Hook: " .. name .. "]")
      LogBlock(reason, name, url)
      return {StatusCode = 403, Success = false, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
     end
    end

    local finalOptions = options
    if optsIsTable then
     finalOptions = ApplyScrubbedOptions(options, scrubbedUrl, urlChanged, scrubbedBody, bodyChanged, scrubbedHeaders, headersChanged)
    elseif urlChanged then
     finalOptions = scrubbedUrl
    end

    local res = old(finalOptions)
    if ProtectFingerprint and Safe.typeof(res) == "table" and Safe.typeof(scrubbedUrl) == "string" then
     local host = Safe.lower(ExtractHost(FullyUrlDecode(scrubbedUrl)))
     if InspectResponseForGiveaways(host, res.Body, res.Headers) then
      Console("warn", "Blocked response, matched IP logger content blocklist [Hook: " .. name .. "]")
      LogBlock("Matched IP logger content blocklist", name, scrubbedUrl)
      return {StatusCode = 403, Success = false, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
     end
    end
    return res
   end)
   pcall(function()
    old = hook_func(func, wrapper)
   end)
   OriginalFunctions[old] = true
   HookedLiveFunctions[func] = true
   hooked_functions[func] = true
   if getCurrent then
    RegisterHookWatch(name, getCurrent, (name == "request" or name == "http_request" or name:sub(-8) == ".request") and "http" or nil, {
     set = setCurrent,
     rehook = function(f) pcall(hook_func, f, wrapper) end,
    })
   end
  end
 end
else
 Console("warn", "hookfunction is not supported!")
end

if hook_func then
 local oldPrint, oldWarn
 local livePrint, liveWarn = print, warn
 oldPrint = hook_func(print, cclosure(function(...)
  if ProtectConsoleGui then
   local bad, reason = ScanArgs(...)
   if bad then
    LogBlock(reason, "print", "(console)")
    return oldWarn("[Vyrnox Guard]: Blocked suspicious print - " .. reason)
   end
  end
  return oldPrint(...)
 end))
 OriginalFunctions[oldPrint] = true
 HookedLiveFunctions[livePrint] = true

 oldWarn = hook_func(warn, cclosure(function(...)
  if ProtectConsoleGui then
   local bad, reason = ScanArgs(...)
   if bad then
    LogBlock(reason, "warn", "(console)")
    return oldWarn("[Vyrnox Guard]: Blocked suspicious warn - " .. reason)
   end
  end
  return oldWarn(...)
 end))
 OriginalFunctions[oldWarn] = true
 HookedLiveFunctions[liveWarn] = true
end

if hook_func and typeof(Instance) == "table" and typeof(Instance.new) == "function" then
 local oldInstanceNew
 local liveInstanceNew = Instance.new
 oldInstanceNew = hook_func(Instance.new, cclosure(function(className, ...)
  if typeof(className) == "string" and (className == "EditableImage" or className == "ViewportFrame") then
   LogEvent("instance-created", className .. " created", "info")
  end
  return oldInstanceNew(className, ...)
 end))
 OriginalFunctions[oldInstanceNew] = true
 HookedLiveFunctions[liveInstanceNew] = true
end

local function WrapWebSocketConnect(name, connectFn)
 if typeof(connectFn) ~= "function" or hooked_functions[connectFn] then return end
 local oldConnect
 oldConnect = hook_func(connectFn, cclosure(function(url, ...)
  local scrubbedUrl = url
  local socketWhitelisted = VyrnoxGuard.IsUserWhitelistedUrl(url)
  if socketWhitelisted and ProtectWebSocket then
   local leak, leakReason = VyrnoxGuard.WhitelistLeakCheck(url, nil, nil)
   if leak then
    Console("warn", leakReason .. " [Hook: " .. name .. "] (whitelisted host, still blocked)")
    LogBlock(leakReason, name, url)
    return nil
   end
  end
  if ProtectWebSocket and not socketWhitelisted and typeof(url) == "string" then
   scrubbedUrl = ScrubUserIP(url)
   local bad, reason, kind = ThreatScan(scrubbedUrl, "", nil, nil)
   if bad then
    if kind == "webhook" and not BlockWebhooksHardBlock then
     Console("warn", reason .. " [Hook: " .. name .. "] (Block is off, letting it through)")
     LogEvent("webhook-passthrough", reason .. " -> " .. tostring(scrubbedUrl), "warn")
    else
     Console("warn", reason .. " [Hook: " .. name .. "]")
     LogBlock(reason, name, url)
     return nil
    end
   end
  end
  local socket = oldConnect(scrubbedUrl, ...)
  if typeof(socket) == "table" and typeof(socket.Send) == "function" and not hooked_functions[socket.Send] then
   local oldSend
   local liveSend = socket.Send
   oldSend = hook_func(socket.Send, cclosure(function(self, data, ...)
    if ProtectWebSocket and socketWhitelisted and typeof(data) == "string" then
     local leak, leakReason = VyrnoxGuard.WhitelistLeakCheck("", data, nil)
     if leak then
      Console("warn", leakReason .. " [Hook: " .. name .. ":Send] (whitelisted host, still blocked)")
      LogBlock(leakReason, name .. ":Send", tostring(url))
      return nil
     end
    end
    if ProtectWebSocket and not socketWhitelisted and typeof(data) == "string" then
     local scrubbedData = ScrubUserIP(data)
     local bad, reason, kind = ScanString(scrubbedData, true)
     if bad then
      if kind == "webhook" and not BlockWebhooksHardBlock then
       Console("warn", reason .. " [Hook: " .. name .. ":Send] (Block is off, letting it through)")
       LogEvent("webhook-passthrough", reason .. " -> " .. tostring(scrubbedUrl), "warn")
      else
       Console("warn", reason .. " [Hook: " .. name .. ":Send]")
       LogBlock(reason, name .. ":Send", scrubbedUrl)
       return nil
      end
     end
     return oldSend(self, scrubbedData, ...)
    end
    return oldSend(self, data, ...)
   end))
   OriginalFunctions[oldSend] = true
   HookedLiveFunctions[liveSend] = true
   hooked_functions[socket.Send] = true
  end
  return socket
 end))
 OriginalFunctions[oldConnect] = true
 HookedLiveFunctions[connectFn] = true
 hooked_functions[connectFn] = true
end

if hook_func then
 if typeof(env.WebSocket) == "table" and typeof(env.WebSocket.connect) == "function" then
  WrapWebSocketConnect("WebSocket.connect", env.WebSocket.connect)
 end
 for _, ns in ipairs(namespaces) do
  local obj = env[ns]
  if typeof(obj) == "table" and typeof(obj.websocket) == "table" and typeof(obj.websocket.connect) == "function" then
   WrapWebSocketConnect(ns .. ".websocket.connect", obj.websocket.connect)
  end
 end
end

do
 local PhishBrand = "roblox"
 local LegitDomains = { "roblox.com", "rbxcdn.com", "robloxlabs.com" }
 local IgnoredExtensions = {
  lua = true, luau = true, txt = true, json = true, md = true, xml = true, csv = true, cfg = true, ini = true, log = true, dat = true,
  png = true, jpg = true, jpeg = true, gif = true, webp = true, mp3 = true, ogg = true,
  rbxm = true, rbxmx = true, rbxl = true, rbxlx = true,
 }

 local Confusables = {
  [0x430] = "a", [0x435] = "e", [0x43E] = "o", [0x440] = "p", [0x441] = "c", [0x443] = "y", [0x445] = "x", [0x433] = "r",
  [0x456] = "i", [0x458] = "j", [0x455] = "s", [0x4CF] = "l", [0x4C0] = "l", [0x4BB] = "h", [0x501] = "d", [0x51B] = "q", [0x51D] = "w",
  [0x410] = "a", [0x412] = "b", [0x415] = "e", [0x41A] = "k", [0x41C] = "m", [0x41D] = "h", [0x41E] = "o", [0x420] = "p",
  [0x421] = "c", [0x422] = "t", [0x425] = "x", [0x406] = "i", [0x405] = "s",
  [0x3BF] = "o", [0x3BD] = "v", [0x3C1] = "p", [0x3B9] = "i", [0x3B1] = "a",
  [0x39F] = "o", [0x399] = "i", [0x392] = "b", [0x395] = "e", [0x39A] = "k", [0x3A1] = "p", [0x3A4] = "t", [0x3A7] = "x",
  [0x131] = "i", [0x269] = "i", [0x142] = "l", [0x1C0] = "l", [0x2113] = "l", [0x217C] = "l", [0x216C] = "l", [0x2179] = "x", [0x261] = "g",
 }

 local function Normalize(text)
  local out, invisible = {}, false
  local ok = pcall(function()
   for _, cp in utf8.codes(text) do
    if cp < 0x80 then
     out[#out + 1] = string.char(cp):lower()
    elseif cp == 0x200B or cp == 0x200C or cp == 0x200D or cp == 0x200E or cp == 0x200F or cp == 0x2060 or cp == 0xFEFF or cp == 0x00AD then
     invisible = true
    elseif cp == 0x3002 or cp == 0xFF0E or cp == 0xFF61 then
     out[#out + 1] = "."
    elseif cp >= 0xFF01 and cp <= 0xFF5E then
     out[#out + 1] = string.char(cp - 0xFEE0):upper()
    elseif Confusables[cp] then
     out[#out + 1] = Confusables[cp]:upper()
    else
     out[#out + 1] = "Z"
    end
   end
  end)
  if not ok then
   return text:lower(), false
  end
  return table.concat(out), invisible
 end

 local function Fold(s)
  return (s:lower():gsub("[i1|!]", "l"):gsub("0", "o"))
 end

 local function WithinOneEdit(a, b)
  if a == b then return true end
  local la, lb = #a, #b
  if math.abs(la - lb) > 1 then return false end
  local i, j, edits = 1, 1, 0
  while i <= la and j <= lb do
   if a:sub(i, i) == b:sub(j, j) then
    i = i + 1
    j = j + 1
   else
    edits = edits + 1
    if edits > 1 then return false end
    if la > lb then
     i = i + 1
    elseif lb > la then
     j = j + 1
    else
     i = i + 1
     j = j + 1
    end
   end
  end
  edits = edits + (la - i + 1) + (lb - j + 1)
  return edits <= 1
 end

 local function IsLegitHost(host)
  for _, d in ipairs(LegitDomains) do
   if host == d or host:sub(-(#d + 1)) == "." .. d then
    return true
   end
  end
  return false
 end

 local function AnalyzeToken(token, invisible)
  if not token:find(".", 1, true) then return nil end
  local labels = {}
  for l in token:gmatch("[^%.]+") do
   labels[#labels + 1] = l
  end
  if #labels < 2 then return nil end
  if IgnoredExtensions[labels[#labels]:lower()] then return nil end
  if not invisible and IsLegitHost(token) then return nil end

  if Fold(token):find(PhishBrand, 1, true) then
   return "has \"roblox\" in it but isn't a Roblox domain"
  end
  for i = 1, #labels - 1 do
   for part in Fold(labels[i]):gmatch("[^%-_]+") do
    if #part >= 5 and #part <= 7 and WithinOneEdit(part, PhishBrand) then
     return "looks like a misspelling of roblox"
    end
   end
  end
  return nil
 end

 local function ScanClipboardText(text)
  local norm, invisible = Normalize(text)

  for authority in norm:gmatch("://([^/?#%s]+)") do
   local userinfo, hostport = authority:match("^(.*)@([^@]*)$")
   if userinfo and Fold(userinfo):find(PhishBrand, 1, true) then
    local host = hostport:match("^([^:]+)") or hostport
    if invisible or not IsLegitHost(host) then
     return true, host, "real destination is hidden behind a roblox.com-style prefix"
    end
   end
  end

  for token in norm:gmatch("[%w%-%._]+") do
   token = token:gsub("^[%.%-_]+", ""):gsub("[%.%-_]+$", "")
   local why = AnalyzeToken(token, invisible)
   if why then
    return true, token, why
   end
  end
  return false
 end

 local ClipTimes = {}
 local ClipWindow = 2
 local ClipMaxCalls = 5
 local ClipLastWarn = -math.huge

 local function ClipboardRateLimited(name)
  local now = (tick and tick()) or os.clock()
  ClipTimes[#ClipTimes + 1] = now
  while #ClipTimes > 0 and now - ClipTimes[1] > ClipWindow do
   table.remove(ClipTimes, 1)
  end
  if #ClipTimes <= ClipMaxCalls then
   return false
  end
  if now - ClipLastWarn > 5 then
   ClipLastWarn = now
   local reason = string.format("Clipboard spam blocked (more than %d writes in %ds)", ClipMaxCalls, ClipWindow)
   Console("warn", reason .. " [Hook: " .. name .. "]")
   LogBlock(reason, name, "(clipboard)")
  end
  return true
 end

 local function InspectClipboard(name, text)
  if not VyrnoxGuard.ProtectClipboard then
   return false
  end
  if VyrnoxGuard.RateLimitClipboard and ClipboardRateLimited(name) then
   return true
  end
  if typeof(text) ~= "string" or text == "" then
   return false
  end
  if #text > 32768 then
   text = text:sub(1, 32768)
  end
  local okScan, bad, host, why = pcall(ScanClipboardText, text)
  if not okScan or not bad then
   return false
  end
  if VyrnoxGuard.IsUserWhitelistedUrl(host) then
   return false
  end

  local shown = (#host > 60) and (host:sub(1, 57) .. "...") or host
  local reason = "Possible phishing link copied to clipboard: " .. shown .. " (" .. why .. ")"
  if VyrnoxGuard.BlockClipboard then
   Console("warn", reason .. " [Hook: " .. name .. "] (Blocked)")
   LogBlock(reason, name, host)
   return true
  end
  LogEvent("clipboard-phishing", reason .. " [Hook: " .. name .. "]")
  if ShowThreatNotification then
   pcall(ShowThreatNotification, reason)
  end
  return false
 end

 local function HookClipboardFunction(name, func, getCurrent, setCurrent)
  if typeof(func) ~= "function" or hooked_functions[func] then return end
  local old
  local wrapper = cclosure(function(text, ...)
   if InspectClipboard(name, text) then
    return nil
   end
   return old(text, ...)
  end)
  local ok = pcall(function()
   old = hook_func(func, wrapper)
  end)
  if not ok or not old then return end
  OriginalFunctions[old] = true
  HookedLiveFunctions[func] = true
  hooked_functions[func] = true
  if getCurrent then
   RegisterHookWatch(name, getCurrent, nil, {
    set = setCurrent,
    rehook = function(f) pcall(hook_func, f, wrapper) end,
   })
  end
 end

 if hook_func then
  local clipboardNames = {
   "setclipboard", "toclipboard", "set_clipboard", "setrbxclipboard", "writeclipboard",
   "write_clipboard", "copytoclipboard", "copy_to_clipboard",
  }
  for _, fname in ipairs(clipboardNames) do
   HookClipboardFunction(fname, env[fname], function() return env[fname] end, function(v) env[fname] = v end)
  end
  for _, ns in ipairs(namespaces) do
   local obj = env[ns]
   if typeof(obj) == "table" then
    for _, fname in ipairs(clipboardNames) do
     if typeof(obj[fname]) == "function" then
      HookClipboardFunction(ns .. "." .. fname, obj[fname], function() local o = env[ns]; return o and o[fname] end, function(v) local o = env[ns]; if o then o[fname] = v end end)
     end
    end
   end
  end
  for _, tname in ipairs({ "clipboard", "Clipboard" }) do
   local obj = env[tname]
   if typeof(obj) == "table" then
    for _, fname in ipairs({ "set", "write", "copy", "setclipboard", "settext" }) do
     if typeof(obj[fname]) == "function" then
      HookClipboardFunction(tname .. "." .. fname, obj[fname], function() local o = env[tname]; return o and o[fname] end, function(v) local o = env[tname]; if o then o[fname] = v end end)
     end
    end
   end
  end
 end
end

local FileSystemLocked = false
local DeleteTimestamps = {}
local DeleteBurstWindow = 2
local DeleteBurstThreshold = 5

local function CheckDeleteBurst()
 local now = (tick and tick()) or os.clock()
 table.insert(DeleteTimestamps, now)
 while #DeleteTimestamps > 0 and now - DeleteTimestamps[1] > DeleteBurstWindow do
  table.remove(DeleteTimestamps, 1)
 end
 return #DeleteTimestamps >= DeleteBurstThreshold, #DeleteTimestamps
end

local fs_delete_funcs = {"delfile", "deletefile", "delfolder", "deletefolder"}
for _, fname in ipairs(fs_delete_funcs) do
 local func = env[fname]
 if typeof(func) == "function" then
  local old
  old = hook_func(func, cclosure(function(path, ...)
   if GuardFS.Depth == 0 and (GuardFS.IsInside(path) or GuardFS.IsAncestor(path)) then
    GuardFS.Deny(fname, path)
    return false
   end
   if not ProtectFilesystem then
    return old(path, ...)
   end

   if FileSystemLocked then
    Console("warn", "Blocked deletion of '" .. tostring(path) .. "' (FileSystem Lockdown Active)")
    return false
   end

   if typeof(path) == "string" then
    if path == "" or path == "/" or path == "*" or path == "." or path:lower() == "workspace" then
     Console("warn", "Blocked root wipe attempt via " .. fname .. ". Enabling FileSystem Lockdown.")
     LogBlock("Root wipe attempt - Lockdown", fname, path)
     FileSystemLocked = true
     return false
    end

    local burst, count = CheckDeleteBurst()
    if burst then
     Console("warn", string.format("Burst deletion detected (%d in %ds). Enabling FileSystem Lockdown.", count, DeleteBurstWindow))
     LogBlock("Burst deletion - Lockdown", fname, path)
     FileSystemLocked = true
     return false
    end
   end

   return old(path, ...)
  end))

  OriginalFunctions[old] = true
  HookedLiveFunctions[func] = true
 end
end

local fs_write_funcs = {"writefile", "appendfile"}
for _, fname in ipairs(fs_write_funcs) do
 local func = env[fname]
 if typeof(func) == "function" then
  local old
  old = hook_func(func, cclosure(function(path, content, ...)
   if GuardFS.Depth == 0 and GuardFS.IsInside(path) then
    GuardFS.Deny(fname, path)
    return nil
   end
   if ProtectFilesystem and BlockBigFiles and typeof(content) == "string" then
    local resultingSize = #content
    if fname == "appendfile" and typeof(isfile) == "function" and typeof(getfilesize) == "function" then
     local okExists, exists = pcall(isfile, path)
     if okExists and exists then
      local okSize, existingSize = pcall(getfilesize, path)
      if okSize and typeof(existingSize) == "number" then
       resultingSize = resultingSize + existingSize
      end
     end
    end
    if resultingSize > MaxWriteFileSize then
     local reason = string.format("Blocked oversized file write (%.1f MB, limit %d MB)", resultingSize / (1024 * 1024), MaxWriteFileSize / (1024 * 1024))
     Console("warn", reason .. " [Hook: " .. fname .. " -> " .. tostring(path) .. "]")
     LogBlock(reason, fname, tostring(path))
     return nil
    end
   end
   if ProtectFilesystem and typeof(content) == "string" and content ~= "" then
    local bad, reason = ScanString(content)
    if not bad and TryXorContainsCookie(content) then
     bad, reason = true, "Blocked XOR-obfuscated .ROBLOSECURITY cookie leak"
    end
    if bad then
     Console("warn", reason .. " [Hook: " .. fname .. " -> " .. tostring(path) .. "]")
     LogBlock(reason, fname, tostring(path))
     return nil
    end
   end
   return old(path, content, ...)
  end))

  OriginalFunctions[old] = true
  HookedLiveFunctions[func] = true
 end
end

local fs_guard_funcs = {"readfile", "readbinfile", "loadfile", "dofile", "isfile", "isfolder", "getfilesize", "getcustomasset", "getsynasset", "listfiles", "makefolder", "movefile", "renamefile", "copyfile"}
local fs_two_path = { movefile = true, renamefile = true, copyfile = true }
for _, fname in ipairs(fs_guard_funcs) do
 local func = env[fname]
 if typeof(func) == "function" then
  local old
  old = hook_func(func, cclosure(function(...)
   if GuardFS.Depth > 0 then
    return old(...)
   end
   local a, b = ...
   local blocked = GuardFS.IsInside(a) or (fs_two_path[fname] and GuardFS.IsInside(b))
   if not blocked and (fname == "movefile" or fname == "renamefile") and GuardFS.IsAncestor(a) then
    blocked = true
   end
   if blocked then
    GuardFS.Deny(fname, GuardFS.IsInside(a) and a or b)
    if fname == "isfile" or fname == "isfolder" then
     return false
    elseif fname == "listfiles" then
     return {}
    elseif fname == "loadfile" then
     return nil, tostring(a) .. " does not exist"
    elseif fname == "readfile" or fname == "readbinfile" or fname == "dofile" or fname == "getfilesize" or fname == "getcustomasset" or fname == "getsynasset" then
     error(tostring(a) .. " does not exist", 0)
    end
    return nil
   end
   if fname == "listfiles" then
    local result = old(...)
    if typeof(result) == "table" then
     local filtered = {}
     for _, entry in ipairs(result) do
      if not GuardFS.IsInside(entry) then
       table.insert(filtered, entry)
      end
     end
     return filtered
    end
    return result
   end
   return old(...)
  end))

  OriginalFunctions[old] = true
  HookedLiveFunctions[func] = true
 end
end

local FileScanLog = {}
local function LogFileScan(path, reason)
 table.insert(FileScanLog, { time = os.time(), path = path, reason = reason })
 Console("warn", "[File Scan] " .. path .. " - " .. reason)
end
VyrnoxGuard.FileScan = FileScanLog
local function PrintFileScan()
 if #FileScanLog == 0 then
  Console("print", "No sensitive data found in the workspace scan.")
  return
 end
 for i, entry in ipairs(FileScanLog) do
  Console("print", string.format("[%d] %s - %s", i, entry.path, entry.reason))
 end
end
VyrnoxGuard.PrintFileScan = PrintFileScan

local ScanIsRunning = false
VyrnoxGuard.ScanIsRunning = false

local function RunFilesystemScanImpl(onComplete)
 if not (ProtectFilesystem and typeof(listfiles) == "function") then
  if not ProtectFilesystem then
   Console("print", "Filesystem protection disabled - enable it to run a workspace scan.")
  else
   Console("warn", "listfiles not supported in this environment - cannot run a workspace scan.")
  end
  if onComplete then onComplete(false) end
  return
 end

 if ScanIsRunning then
  Console("warn", "A workspace scan is already running.")
  return
 end
 ScanIsRunning = true
 VyrnoxGuard.ScanIsRunning = true

 local AUDIT_BATCH_SIZE = 10
 local scanOpCount = 0

 local function ScanYield()
  scanOpCount = scanOpCount + 1
  if scanOpCount % AUDIT_BATCH_SIZE == 0 then
   wait_func()
  end
 end

 local function GetWorkspaceRoot()
  for _, candidate in ipairs({"", ".", "/"}) do
   local ok, entries = pcall(listfiles, candidate)
   ScanYield()
   if ok and typeof(entries) == "table" and #entries > 0 then
    return candidate
   end
  end
  return ""
 end

 local function RecursiveList(path, out)
  out = out or {}
  local ok, entries = pcall(listfiles, path)
  ScanYield()
  if not ok or typeof(entries) ~= "table" then return out end
  for _, entryPath in ipairs(entries) do
   if GuardFS.IsInside(entryPath) then continue end
   local isEntryFolder = false
   if typeof(isfolder) == "function" then
    local folderOk, folderResult = pcall(isfolder, entryPath)
    ScanYield()
    isEntryFolder = folderOk and folderResult == true
   end
   if isEntryFolder then
    RecursiveList(entryPath, out)
   else
    table.insert(out, entryPath)
   end
  end
  return out
 end

 local MaxScanFileSize = 5 * 1024 * 1024

 spawn_func(function()
  table.clear(FileScanLog)

  local ok, allFiles = pcall(RecursiveList, GetWorkspaceRoot())

  if ok and typeof(allFiles) == "table" then
   Console("print", "Scanning " .. #allFiles .. " workspace file(s) for sensitive data (batched)...")
   for _, path in ipairs(allFiles) do
    if typeof(readfile) == "function" then
     local skipTooLarge = false
     if typeof(getfilesize) == "function" then
      local sizeOk, size = pcall(getfilesize, path)
      ScanYield()
      if sizeOk and typeof(size) == "number" and size > MaxScanFileSize then
       skipTooLarge = true
      end
     end

     if skipTooLarge then
      LogFileScan(path, "skipped - file too large to scan safely")
     else
      local readOk, content = pcall(readfile, path)
      ScanYield()
      if readOk and typeof(content) == "string" and content ~= "" and #content <= MaxScanFileSize then
       local bad, reason = ScanString(content)
       if not bad and TryXorContainsCookie(content) then
        bad, reason = true, "XOR-obfuscated .ROBLOSECURITY cookie"
       end
       if bad then
        LogFileScan(path, reason)
       end
      end
     end
    end
   end
   PrintFileScan()
  else
   Console("warn", "Workspace file scan failed to enumerate files.")
  end

  ScanIsRunning = false
  VyrnoxGuard.ScanIsRunning = false
  if onComplete then onComplete(ok) end
 end)
end

function VyrnoxGuard.RunFileScan()
 RunFilesystemScanImpl(nil)
end

TriggerFileScan = function(onComplete)
 RunFilesystemScanImpl(onComplete)
end
IsFileScanRunning = function()
 return ScanIsRunning
end

local MetaHook = { installed = nil }
local function InstallMetatableHook()
 local raw = ProtectMetatable and Safe.getrawmetatable(game) or nil
 if raw and not MetaHook.installed then
  local oldnamecall = raw.__namecall
  local oldnewindex = raw.__newindex
  Safe.setreadonly(raw, false)

  raw.__namecall = cclosure(function(self, ...)
   local method = Safe.getnamecallmethod()
   if method == "HttpGet" or method == "HttpGetAsync" or method == "HttpPost" or method == "HttpPostAsync" or method == "GetAsync" or method == "PostAsync" then
    local n = Safe.select("#", ...)
    local args = {...}
    local url, body = args[1], args[2]
    if Safe.typeof(url) == "string" then
     CountHttpRequestSeen()
     if VyrnoxGuard.IsUserWhitelistedUrl(url) then
      local leak, leakReason = VyrnoxGuard.WhitelistLeakCheck(url, body, nil)
      if leak then
       Console("warn", leakReason .. " [Hook: " .. method .. "] (whitelisted host, still blocked)")
       LogBlock(leakReason, method, url)
       return BLOCKED_JSON_BODY
      end
      return oldnamecall(self, ...)
     end
     local scrubbedUrl, urlChanged = ScrubUserIP(url)
     local scrubbedBody, bodyChanged = ScrubUserIP(Safe.typeof(body) == "string" and body or "")
     local bad, reason, kind = ThreatScan(scrubbedUrl, scrubbedBody, nil, method)
     if bad then
      if kind == "webhook" and not BlockWebhooksHardBlock then
       Console("warn", reason .. " [Hook: " .. method .. "] (Block is off, letting it through)")
       LogEvent("webhook-passthrough", reason .. " -> " .. tostring(scrubbedUrl), "warn")
      else
       Console("warn", reason .. " [Hook: " .. method .. "]")
       LogBlock(reason, method, url)
       return BLOCKED_JSON_BODY
      end
     end

     if urlChanged then args[1] = scrubbedUrl end
     if bodyChanged and Safe.typeof(body) == "string" then args[2] = scrubbedBody end

     local result = oldnamecall(self, Safe.unpack(args, 1, n))
     if ProtectFingerprint and Safe.typeof(result) == "string" then
      local host = Safe.lower(ExtractHost(FullyUrlDecode(scrubbedUrl)))
      if InspectResponseForGiveaways(host, result) then
       Console("warn", "Blocked response, matched IP logger content blocklist [Hook: " .. method .. "]")
       LogBlock("Matched IP logger content blocklist", method, scrubbedUrl)
       return BLOCKED_JSON_BODY
      end
     end
     return result
    end
   elseif BlockForcedMessages and (method == "SendAsync" or method == "FireServer") then
    local isChatSend = false
    if method == "SendAsync" then
     local okClass, isChannel = Safe.pcall(function() return Safe.typeof(self) == "Instance" and self:IsA("TextChannel") end)
     isChatSend = okClass and isChannel == true
    else
     local okName, remoteName = Safe.pcall(function() return Safe.typeof(self) == "Instance" and self.Name end)
     isChatSend = okName and remoteName == "SayMessageRequest"
    end
    if isChatSend and Safe.checkcaller and Safe.checkcaller() then
     local preview = tostring((...) ~= nil and (...) or ""):sub(1, 60)
     Console("warn", "Blocked forced chat message: \"" .. preview .. "\" [Hook: " .. method .. "]")
     LogBlock("Forced chat message blocked", method, "(chat)")
     return nil
    end
   elseif method == "ReadPixels" or method == "WritePixels" or method == "GetImage" or method == "ImageContent" then
    local ok, className = Safe.pcall(function() return self.ClassName end)
    LogEvent("pixel-buffer-access", method .. " called on " .. (ok and tostring(className) or "instance"), "info")
   elseif method == "RequestAsync" then
    local options = ...
    if Safe.typeof(options) == "table" then
     CountHttpRequestSeen()
     local url = options.Url or options.url or ""
     if VyrnoxGuard.IsUserWhitelistedUrl(url) then
      local leak, leakReason = VyrnoxGuard.WhitelistLeakCheck(url, options.Body or options.body, options.Headers or options.headers)
      if leak then
       Console("warn", leakReason .. " [Hook: RequestAsync] (whitelisted host, still blocked)")
       LogBlock(leakReason, "RequestAsync", url)
       return {Success = false, StatusCode = 403, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
      end
      return oldnamecall(self, ...)
     end
     local body = options.Body or options.body or ""
     local headers = options.Headers or options.headers
     local scrubbedUrl, urlChanged = ScrubUserIP(url)
     local scrubbedBody, bodyChanged = ScrubUserIP(body)
     local scrubbedHeaders, headersChanged = ScrubHeaders(headers)
     local bad, reason, kind = ThreatScan(scrubbedUrl, scrubbedBody, scrubbedHeaders, method)
     if bad then
      if kind == "webhook" and not BlockWebhooksHardBlock then
       Console("warn", reason .. " [Hook: RequestAsync] (Block is off, letting it through)")
       LogEvent("webhook-passthrough", reason .. " -> " .. tostring(scrubbedUrl), "warn")
      else
       Console("warn", reason .. " [Hook: RequestAsync]")
       LogBlock(reason, "RequestAsync", url)
       return {Success = false, StatusCode = 403, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
      end
     end

     local finalOptions = ApplyScrubbedOptions(options, scrubbedUrl, urlChanged, scrubbedBody, bodyChanged, scrubbedHeaders, headersChanged)
     local result = oldnamecall(self, finalOptions)
     if ProtectFingerprint and Safe.typeof(result) == "table" and Safe.typeof(scrubbedUrl) == "string" then
      local host = Safe.lower(ExtractHost(FullyUrlDecode(scrubbedUrl)))
      if InspectResponseForGiveaways(host, result.Body, result.Headers) then
       Console("warn", "Blocked response, matched IP logger content blocklist [Hook: RequestAsync]")
       LogBlock("Matched IP logger content blocklist", "RequestAsync", scrubbedUrl)
       return {Success = false, StatusCode = 403, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
      end
     end
     return result
    end
   end
   return oldnamecall(self, ...)
  end)

  raw.__newindex = cclosure(function(self, index, value)
   if ProtectConsoleGui and Safe.typeof(index) == "string" and Safe.typeof(value) == "string" and (index == "Text" or index == "PlaceholderText" or index == "ContentText") then
    local bad, reason = ScanString(value)
    if bad then
     Console("warn", reason .. " [Blocked GUI text assignment]")
     LogBlock(reason, "Text: " .. index, "(gui)")
     return oldnewindex(self, index, "[REDACTED by Vyrnox Guard]")
    end
   end
   return oldnewindex(self, index, value)
  end)
  Safe.setreadonly(raw, true)
  MetaHook.installed = { raw = raw, oldnamecall = oldnamecall, oldnewindex = oldnewindex }

  local function SetMeta(field)
   return function(v)
    local r = Safe.getrawmetatable(game)
    if r then
     Safe.setreadonly(r, false)
     r[field] = v
     Safe.setreadonly(r, true)
    end
   end
  end
  RegisterHookWatch("__namecall", function()
   local r = Safe.getrawmetatable(game)
   return r and r.__namecall
  end, nil, { set = SetMeta("__namecall") })
  RegisterHookWatch("__newindex", function()
   local r = Safe.getrawmetatable(game)
   return r and r.__newindex
  end, nil, { set = SetMeta("__newindex") })
 end
end

InstallMetatableHook()

spawn_func(function()
 wait_func(0.5)

 if not UserSetMetatableManually then
  local anti = AntiCheatPresent()
  if anti and MetaHook.installed then
   ProtectMetatable = false
   local m = MetaHook.installed
   pcall(function()
    Safe.setreadonly(m.raw, false)
    m.raw.__namecall = m.oldnamecall
    m.raw.__newindex = m.oldnewindex
    Safe.setreadonly(m.raw, true)
   end)
   for i = #HookWatchList, 1, -1 do
    local lbl = HookWatchList[i].label
    if lbl == "__namecall" or lbl == "__newindex" then table.remove(HookWatchList, i) end
   end
   MetaHook.installed = nil
   Console("warn", "Metatable protection (__namecall/__newindex) toggled off: this game appears to have an anti-cheat/admin system that can detect hooked metamethods. HTTP requests made through executor functions are still protected.")
   NotifyToggleChange()
  elseif not anti and not ProtectMetatable then
   ProtectMetatable = true
   InstallMetatableHook()
   NotifyToggleChange()
  end
 end
end)

local WatchIntervalSeconds = 5

local CANARY_URL = "http://127.0.0.1:1/vyrnox-canary"
local function RunHttpCanary(fn)
 if not ProtectCookies or Safe.typeof(fn) ~= "function" then return true end
 if VyrnoxGuard.IsUserWhitelistedUrl(CANARY_URL) then return true end
 Safe.Canary = true
 local ok, res = Safe.pcall(fn, { Url = CANARY_URL, Method = "POST", Body = cookies })
 Safe.Canary = false
 return ok and Safe.typeof(res) == "table" and res.StatusCode == 403 and res.Body == BLOCKED_JSON_BODY
end
Safe.RunRestoreCanary = function(fn)
 if Safe.typeof(fn) ~= "function" then return true end
 local before = RestoreFunctionBlocked
 Safe.Canary = true
 Safe.pcall(fn, Safe.RestoreCanaryTarget)
 Safe.Canary = false
 local blocked = (RestoreFunctionBlocked == before + 1)
 RestoreFunctionBlocked = before
 return blocked
end

local MaxRepairsPerWindow = 4

local function IsEntryIntact(entry)
 local ok, current = pcall(entry.getCurrent)
 local intact = ok and current == entry.baseline
 if intact and entry.kind == "http" then
  intact = RunHttpCanary(current)
 elseif intact and entry.kind == "restore" then
  intact = Safe.RunRestoreCanary(current)
 end
 return intact
end

local function RepairEntry(entry)
 local repair = entry.repair
 if not repair then return false end
 local ok, current = pcall(entry.getCurrent)
 if ok and current ~= entry.baseline and repair.set then
  pcall(repair.set, entry.baseline)
 end
 if IsEntryIntact(entry) then return true end
 if repair.rehook then
  local ok2, cur2 = pcall(entry.getCurrent)
  local target = (ok2 and Safe.typeof(cur2) == "function") and cur2 or entry.baseline
  pcall(repair.rehook, target)
 end
 return IsEntryIntact(entry)
end

local function CheckEntry(entry)
 if IsEntryIntact(entry) then
  entry.tamperedWarned = false
  entry.okStreak = entry.okStreak + 1
  if entry.okStreak >= 12 then entry.repairs = 0 end
  return
 end
 entry.okStreak = 0
 local repaired = false
 if entry.repairs < MaxRepairsPerWindow then
  entry.repairs = entry.repairs + 1
  repaired = RepairEntry(entry)
 end
 if repaired then
  entry.tamperedWarned = false
  Console("warn", "Hook tampering detected and repaired: \"" .. entry.label .. "\" was altered and Vyrnox Guard re-installed it. Something in this session is trying to bypass protection.")
  LogEvent("hook-repaired", entry.label .. " was altered and automatically re-installed")
 elseif not entry.tamperedWarned then
  entry.tamperedWarned = true
  local why = (entry.repairs >= MaxRepairsPerWindow) and "it keeps being re-tampered after repeated repairs" or "it could not be repaired automatically"
  Console("warn", "Hook tampering detected: \"" .. entry.label .. "\" not matching the state Vyrnox Guard installed (" .. why .. "), protection for this hook may have been silently removed. Treat this session as reduced protection.")
  LogEvent("hook-tampered", entry.label .. " changed from its post-install baseline (" .. why .. ")")
 end
end

if #HookWatchList > 0 then
 spawn_func(function()
  while true do
   wait_func(WatchIntervalSeconds)
   for _, entry in ipairs(HookWatchList) do
    pcall(CheckEntry, entry)
   end
  end
 end)
end

function VyrnoxGuard.PrintHookStatus()
 if #HookWatchList == 0 then
  Console("print", "No hooks are being watched (hookfunction unsupported or no hooks installed).")
  return
 end
 for i, entry in ipairs(HookWatchList) do
  local intact = IsEntryIntact(entry)
  Console("print", string.format("[%d] %s: %s", i, entry.label, intact and "GOOD" or "TAMPERED"))
 end
end

Console("print", "Protection Loaded")
