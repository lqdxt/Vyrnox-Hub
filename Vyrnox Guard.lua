--[[
 Vyrnox Guard
 ------------
 if your executor does not support hooking it's own functions, this will not work
 place this file in your executor's autoexec/Autoexecution folder so it runs on every game,
 should load before any other script has a chance to execute.
 load order matters: Vyrnox Guard can only catch what happens after it's active
 that said, you still shouldn't execute untrusted + obfuscated scripts blindly
]]

local httprequest = (getgenv and getgenv().request) or (getgenv and getgenv().http_request) or request or http_request or syn.request or syn.http_request or nil
local hook_func = hookfunction or detour_function or detourfunction or replace_function or replacefunction or replaceclosure or hookfunc or nil
local get_nil = getnilinstances or nil
local cclosure = newcclosure or (typeof(syn) == "table" and syn.newcclosure) or makecclosure or tocclosure or forcecclosure or function(f) return f end
local env = getgenv and getgenv() or getfenv and getfenv() or _G or nil
local spawn_func = (task and task.spawn) or spawn
local wait_func = (task and task.wait) or wait
local hash_func = (crypt and crypt.hash) or sha256 or (hash and hash.sha256) or nil
local restore_func = restorefunction or restorefunc or restorehook or unhookfunction or nil
if env.VyrnoxGuardEnabled then error("script already exists?", 1) end
env.VyrnoxGuardEnabled = true

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

local OriginalFunctions = {}
local HookedLiveFunctions = {}
local ReportRestoreBlocked
local RestoreFunctionBlocked = 0
local AddConsoleLine
local TriggerFileScan
local IsFileScanRunning
local ShowThreatNotification

local function Console(msg_type, msg)
 if AddConsoleLine then
  AddConsoleLine(msg_type, msg)
  return
 end
end

pcall(function()
 if restore_func then
  restore_func(restore_func)
  restore_func(httprequest)
  restore_func(hook_func)
 end
end)

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
 if restore_func then
  local layer1Ok = false
  if hook_func then
   local hookedOldRestore
   local hookOk = pcall(function()
    hookedOldRestore = hook_func(restore_func, cclosure(function(target)
     return GuardedRestore(hookedOldRestore, target)
    end))
   end)
   if hookOk and hookedOldRestore then
    OriginalFunctions[hookedOldRestore] = true
    layer1Ok = true
   end
  end
  if not layer1Ok then
   local GuardedGlobal = cclosure(function(target)
    return GuardedRestore(restore_func, target)
   end)
   pcall(function()
    if env then env.restorefunction = GuardedGlobal end
   end)
   pcall(function()
    getgenv().restorefunction = GuardedGlobal
   end)
   restorefunction = GuardedGlobal
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

local BlockLog = {}
local function LogBlock(reason, hookName, url)
 table.insert(BlockLog, { time = os.time(), reason = reason, hook = hookName, url = url })
 if ShowThreatNotification then
  ShowThreatNotification(reason)
 end
end

local EventLog = {}
local function LogEvent(kind, detail, severity)
 severity = severity or "warn"
 table.insert(EventLog, { time = os.time(), kind = kind, detail = detail, severity = severity })
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
 Stats.HttpRequestsSeen = Stats.HttpRequestsSeen + 1
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

local ProtectCookies = true
local ProtectIP = true
local ProtectWebSocket = true
local ProtectDomains = true
local ProtectFilesystem = true
local ProtectConsoleGui = true
local ProtectFingerprint = true
local ProtectTokens = true

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

local ConfigFolder = "VyrnoxGuard"
local ConfigPath = "VyrnoxGuard/config.json"

local function BuildStatsSummaryText()
 local reasonCounts = {}
 local reasonOrder = {}
 for _, entry in ipairs(BlockLog) do
  local r = entry.reason or "Unknown"
  if not reasonCounts[r] then
   reasonCounts[r] = 0
   table.insert(reasonOrder, r)
  end
  reasonCounts[r] = reasonCounts[r] + 1
 end

 local lines = {}
 table.insert(lines, "Vyrnox Guard, Stats Snapshot")
 table.insert(lines, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
 table.insert(lines, "Session started: " .. os.date("%Y-%m-%d %H:%M:%S", Stats.SessionStart))
 table.insert(lines, "")
 table.insert(lines, "Threats blocked: " .. #BlockLog)
 table.insert(lines, "Flagged events: " .. #EventLog)
 table.insert(lines, "HTTP requests seen: " .. Stats.HttpRequestsSeen)
 table.insert(lines, "")
 table.insert(lines, "Blocked by reason:")
 if #reasonOrder == 0 then
  table.insert(lines, "  (none)")
 else
  for _, r in ipairs(reasonOrder) do
   table.insert(lines, string.format("  %d  %s", reasonCounts[r], r))
  end
 end
 return table.concat(lines, "\n")
end

local function SaveStats()
 if typeof(writefile) ~= "function" then
  Console("warn", "writefile is not supported in this environment, cannot save stats.")
  return false
 end
 local ok = pcall(function()
  if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(ConfigFolder) then
   makefolder(ConfigFolder)
  end
  writefile("VyrnoxGuard/stats_" .. os.date("%Y%m%d_%H%M%S") .. ".txt", BuildStatsSummaryText())
 end)
 if ok then
  Console("print", "Saved stats snapshot to VyrnoxGuard/ folder.")
 else
  Console("warn", "Failed to save stats snapshot.")
 end
 return ok
end
VyrnoxGuard.SaveStats = SaveStats

local function SaveConfig()
 if typeof(writefile) ~= "function" then return end
 local ok = pcall(function()
  if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(ConfigFolder) then
   makefolder(ConfigFolder)
  end
  local data = {
   ProtectCookies = ProtectCookies,
   ProtectIP = ProtectIP,
   ProtectWebSocket = ProtectWebSocket,
   ProtectDomains = ProtectDomains,
   ProtectFilesystem = ProtectFilesystem,
   ProtectConsoleGui = ProtectConsoleGui,
   ProtectFingerprint = ProtectFingerprint,
   ProtectTokens = ProtectTokens,
   BlockWebhooks = BlockWebhooks,
  }
  writefile(ConfigPath, game:GetService("HttpService"):JSONEncode(data))
 end)
 if not ok then
  Console("warn", "Failed to save toggle configuration.")
 end
end

local function LoadConfig()
 if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
 local ok, result = pcall(function()
  if not isfile(ConfigPath) then return nil end
  return game:GetService("HttpService"):JSONDecode(readfile(ConfigPath))
 end)
 if not ok or typeof(result) ~= "table" then return end

 if typeof(result.ProtectCookies) == "boolean" then VyrnoxGuard.ToggleCookies(result.ProtectCookies) end
 if typeof(result.ProtectIP) == "boolean" then VyrnoxGuard.ToggleIP(result.ProtectIP) end
 if typeof(result.ProtectWebSocket) == "boolean" then VyrnoxGuard.ToggleWebSocket(result.ProtectWebSocket) end
 if typeof(result.ProtectDomains) == "boolean" then VyrnoxGuard.ToggleDomains(result.ProtectDomains) end
 if typeof(result.ProtectFilesystem) == "boolean" then VyrnoxGuard.ToggleFilesystem(result.ProtectFilesystem) end
 if typeof(result.ProtectConsoleGui) == "boolean" then VyrnoxGuard.ToggleConsoleGui(result.ProtectConsoleGui) end
 if typeof(result.ProtectFingerprint) == "boolean" then VyrnoxGuard.ToggleFingerprint(result.ProtectFingerprint) end
 if typeof(result.ProtectTokens) == "boolean" then VyrnoxGuard.ToggleTokens(result.ProtectTokens) end
 if typeof(result.BlockWebhooks) == "boolean" then VyrnoxGuard.ToggleWebhooks(result.BlockWebhooks) end

 Console("print", "Loaded saved toggle configuration from " .. ConfigPath)
end

LoadConfig()
VyrnoxGuard.OnToggleChange(SaveConfig)

spawn_func(function()
 local ok_ui, ui_err = pcall(function()
  local TweenService = game:GetService("TweenService")
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

  local function BuildTabButton(text, order)
   local btn = Instance.new("TextButton")
   btn.Name = text .. "Tab"
   btn.AutoButtonColor = false
   btn.Size = UDim2.new(0, 105, 1, 0)
   btn.LayoutOrder = order
   btn.BackgroundColor3 = PANEL_DARK
   btn.BackgroundTransparency = 0.2
   btn.Font = Enum.Font.GothamMedium
   btn.TextSize = 12
   btn.TextColor3 = TEXT_DIM
   btn.Text = text
   btn.Parent = tabBar
   NewCorner(8, btn)
   return btn
  end

  local togglesTabBtn = BuildTabButton("Home", 1)
  local statsTabBtn = BuildTabButton("Stats", 2)

  local leftPanel = Instance.new("ScrollingFrame")
  leftPanel.Name = "LeftPanel"
  leftPanel.Position = UDim2.new(0, 12, 0, 42)
  leftPanel.Size = UDim2.new(0, 220, 1, -54)
  leftPanel.BackgroundColor3 = PANEL_DARK
  leftPanel.BackgroundTransparency = 0.2
  leftPanel.BorderSizePixel = 0
  leftPanel.ScrollBarThickness = 4
  leftPanel.ScrollBarImageColor3 = TEXT_DIM
  leftPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
  leftPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
  leftPanel.Parent = body
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
  statsPanel.Position = UDim2.new(0, 12, 0, 42)
  statsPanel.Size = UDim2.new(0, 220, 1, -54)
  statsPanel.BackgroundColor3 = PANEL_DARK
  statsPanel.BackgroundTransparency = 0.2
  statsPanel.BorderSizePixel = 0
  statsPanel.ScrollBarThickness = 4
  statsPanel.ScrollBarImageColor3 = TEXT_DIM
  statsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
  statsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
  statsPanel.Visible = false
  statsPanel.Parent = body
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

  local function SetTabButtonActive(btn, active)
   btn.BackgroundColor3 = active and CALM or PANEL_DARK
   btn.BackgroundTransparency = active and 0.05 or 0.2
   btn.TextColor3 = active and TEXT_LIGHT or TEXT_DIM
  end

  local RefreshStatsPanel

  local function SwitchTab(tab)
   local showStats = (tab == "stats")
   leftPanel.Visible = not showStats
   statsPanel.Visible = showStats
   SetTabButtonActive(togglesTabBtn, not showStats)
   SetTabButtonActive(statsTabBtn, showStats)
   if showStats and RefreshStatsPanel then
    RefreshStatsPanel()
   end
  end

  togglesTabBtn.MouseButton1Click:Connect(function() SwitchTab("toggles") end)
  statsTabBtn.MouseButton1Click:Connect(function() SwitchTab("stats") end)
  SetTabButtonActive(togglesTabBtn, true)
  SetTabButtonActive(statsTabBtn, false)

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

  local commandBar = Instance.new("Frame")
  commandBar.Name = "CommandBar"
  commandBar.Position = UDim2.new(0, 8, 1, -40)
  commandBar.Size = UDim2.new(1, -16, 0, 32)
  commandBar.BackgroundColor3 = BG_DARK
  commandBar.BackgroundTransparency = 0.15
  commandBar.BorderSizePixel = 0
  commandBar.Parent = rightPanel
  NewCorner(8, commandBar)
  NewStroke(commandBar, Color3.fromRGB(255, 255, 255), 1, 0.88)

  local promptLabel = Instance.new("TextLabel")
  promptLabel.BackgroundTransparency = 1
  promptLabel.Position = UDim2.new(0, 10, 0, 0)
  promptLabel.Size = UDim2.new(0, 14, 1, 0)
  promptLabel.Font = Enum.Font.Code
  promptLabel.TextSize = 14
  promptLabel.TextColor3 = CALM
  promptLabel.TextXAlignment = Enum.TextXAlignment.Left
  promptLabel.Text = ">"
  promptLabel.Parent = commandBar

  local commandBox = Instance.new("TextBox")
  commandBox.Name = "CommandInput"
  commandBox.BackgroundTransparency = 1
  commandBox.Position = UDim2.new(0, 26, 0, 0)
  commandBox.Size = UDim2.new(1, -34, 1, 0)
  commandBox.Font = Enum.Font.Code
  commandBox.TextSize = 13
  commandBox.TextColor3 = TEXT_LIGHT
  commandBox.PlaceholderText = "help"
  commandBox.PlaceholderColor3 = TEXT_DIM
  commandBox.TextXAlignment = Enum.TextXAlignment.Left
  commandBox.ClearTextOnFocus = false
  commandBox.Text = ""
  commandBox.Parent = commandBar

  local Commands = {
   PrintLog = { get = function() return VyrnoxGuard.PrintLog end, help = "PrintLog() - list blocked requests" },
   PrintEvents = { get = function() return VyrnoxGuard.PrintEvents end, help = "PrintEvents() - list flagged activity" },
   RunFileScan = { get = function() return VyrnoxGuard.RunFileScan end, help = "RunFileScan() - scan workspace files now" },
   ToggleWebhooks = { get = function() return VyrnoxGuard.ToggleWebhooks end, help = "ToggleWebhooks(true/false)" },
   ToggleCookies = { get = function() return VyrnoxGuard.ToggleCookies end, help = "ToggleCookies(true/false)" },
   ToggleIP = { get = function() return VyrnoxGuard.ToggleIP end, help = "ToggleIP(true/false)" },
   ToggleWebSocket = { get = function() return VyrnoxGuard.ToggleWebSocket end, help = "ToggleWebSocket(true/false)" },
   ToggleDomains = { get = function() return VyrnoxGuard.ToggleDomains end, help = "ToggleDomains(true/false)" },
   ToggleFilesystem = { get = function() return VyrnoxGuard.ToggleFilesystem end, help = "ToggleFilesystem(true/false)" },
   ToggleConsoleGui = { get = function() return VyrnoxGuard.ToggleConsoleGui end, help = "ToggleConsoleGui(true/false)" },
   ToggleFingerprint = { get = function() return VyrnoxGuard.ToggleFingerprint end, help = "ToggleFingerprint(true/false)" },
   ToggleTokens = { get = function() return VyrnoxGuard.ToggleTokens end, help = "ToggleTokens(true/false)" },
   ToggleMetatable = { get = function() return VyrnoxGuard.ToggleMetatable end, help = "ToggleMetatable(true/false) - __namecall/__newindex hooks (auto-disabled if anti-cheat detected)" },
   PrintHookStatus = { get = function() return VyrnoxGuard.PrintHookStatus end, help = "PrintHookStatus() - check if hooks are still intact" },
  }

  local function ParseArgs(argStr)
   local args = {}
   if not argStr or argStr:match("^%s*$") then return args end
   for token in argStr:gmatch("[^,]+") do
    token = token:match("^%s*(.-)%s*$")
    if token == "true" then
     table.insert(args, true)
    elseif token == "false" then
     table.insert(args, false)
    elseif token == "nil" then
     table.insert(args, nil)
    elseif tonumber(token) then
     table.insert(args, tonumber(token))
    else
     local unquoted = token:match('^"(.*)"$') or token:match("^'(.*)'$")
     table.insert(args, unquoted or token)
    end
   end
   return args
  end

  local function RunCommand(raw)
   local input = raw:match("^%s*(.-)%s*$")
   if input == "" then return end

   AddConsoleLine("print", "> " .. input)

   if input == "help" then
    for name, entry in pairs(Commands) do
     Console("print", "  " .. entry.help)
    end
    return
   end

   local name, argStr = input:match("^([%a_][%w_]*)%s*%(?(.-)%)?$")
   if not name then
    Console("warn", "Couldn't parse that. Type 'help' for a list of commands.")
    return
   end

   local entry = Commands[name]
   if not entry then
    Console("warn", "Unknown command: " .. tostring(name) .. ", type 'help' for a list.")
    return
   end

   local fn = entry.get()
   if typeof(fn) ~= "function" then
    Console("warn", name .. " is not available yet, try again in a moment.")
    return
   end

   local args = ParseArgs(argStr)
   local ok, result = pcall(fn, table.unpack(args))
   if not ok then
    Console("warn", "Error running " .. name .. ": " .. tostring(result))
   elseif result ~= nil then
    Console("print", "-> " .. tostring(result))
   end
  end

  commandBox.FocusLost:Connect(function(enterPressed)
   if not enterPressed then return end
   local text = commandBox.Text
   commandBox.Text = ""
   RunCommand(text)
   spawn_func(function()
    wait_func()
    commandBox:CaptureFocus()
   end)
  end)

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
   local x = math.clamp(screenPos.X, 120, vpSize.X - 120)
   local y = math.max(screenPos.Y - 14, 60)

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
   { label = "Protect Cookies", desc = "Blocks your .ROBLOSECURITY session cookie from leaving, plaintext, URL/hex/base64-encoded, reversed, or XOR-obfuscated.", get = function() return ProtectCookies end, set = VyrnoxGuard.ToggleCookies },
   { label = "Protect IP", desc = "Blocks your public IP address from appearing in outgoing requests or file writes.", get = function() return ProtectIP end, set = VyrnoxGuard.ToggleIP },
   { label = "Protect WebSocket", desc = "Scans WebSocket connections and outgoing messages the same way HTTP requests are scanned.", get = function() return ProtectWebSocket end, set = VyrnoxGuard.ToggleWebSocket },
   { label = "Protect Domains", desc = "Blocks known IP-logger domains and scores suspicious infrastructure, raw IPs, dynamic DNS, odd ports, DGA-style hostnames.", get = function() return ProtectDomains end, set = VyrnoxGuard.ToggleDomains },
   { label = "Protect Filesystem", desc = "Blocks sensitive data before it's written to disk, and guards against mass file deletion.", get = function() return ProtectFilesystem end, set = VyrnoxGuard.ToggleFilesystem },
   { label = "Protect Console/GUI", desc = "Redacts sensitive data before it can be printed to console or shown in a GUI text label.", get = function() return ProtectConsoleGui end, set = VyrnoxGuard.ToggleConsoleGui },
   { label = "Protect Fingerprint", desc = "Learns and blocks new IP-logger domains from page content.", get = function() return ProtectFingerprint end, set = VyrnoxGuard.ToggleFingerprint },
   { label = "Protect Tokens", desc = "Blocks Discord, JWT, and OAuth tokens from leaving in outgoing requests.", get = function() return ProtectTokens end, set = VyrnoxGuard.ToggleTokens },
   { label = "Protect Metatable", desc = "Hooks game's raw __namecall/__newindex (catches direct Instance:HttpGet() calls, pixel-buffer APIs, GUI leaks).", get = function() return ProtectMetatable end, set = VyrnoxGuard.ToggleMetatable },
   { label = "Protect Webhooks", desc = "Blocks requests to Discord/generic webhook endpoints and known paste/dump services.", get = function() return BlockWebhooks end, set = VyrnoxGuard.ToggleWebhooks },
  }
  local totalToggles = #toggleDefs

  local function CountEnabled()
   local n = 0
   for _, def in ipairs(toggleDefs) do
    if def.get() then n = n + 1 end
   end
   return n
  end

  local toggleVisuals = {}

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
    SyncToggleVisual(def, true)
   end
   ApplyTheme(CountEnabled() / totalToggles)
  end

  local TAP_MOVE_THRESHOLD = 8

  local function IsInsideBounds(position, guiObject)
   local absPos = guiObject.AbsolutePosition
   local absSize = guiObject.AbsoluteSize
   return position.X >= absPos.X and position.X <= (absPos.X + absSize.X) and position.Y >= absPos.Y and position.Y <= (absPos.Y + absSize.Y)
  end

  local function BuildToggleRow(def, order)
   local row = Instance.new("Frame")
   row.Size = UDim2.new(1, 0, 0, 36)
   row.BackgroundTransparency = 1
   row.LayoutOrder = order
   row.Parent = leftPanel

   local infoZone = Instance.new("TextButton")
   infoZone.Name = "InfoZone"
   infoZone.Text = ""
   infoZone.AutoButtonColor = false
   infoZone.BackgroundTransparency = 1
   infoZone.Size = UDim2.new(1, -56, 1, 0)
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
   label.Size = UDim2.new(1, -56, 1, 0)
   label.Font = Enum.Font.GothamMedium
   label.TextSize = 13
   label.TextXAlignment = Enum.TextXAlignment.Left
   label.TextColor3 = TEXT_LIGHT
   label.Text = def.label
   label.Parent = row

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

   toggleVisuals[def] = { pill = pill, knob = knob }

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
   local spacer = Instance.new("Frame")
   spacer.Size = UDim2.new(1, 0, 0, 6)
   spacer.BackgroundTransparency = 1
   spacer.LayoutOrder = totalToggles + 1
   spacer.Parent = leftPanel

   local scanSlot = Instance.new("Frame")
   scanSlot.Name = "ScanSlot"
   scanSlot.Size = UDim2.new(1, 0, 0, 40)
   scanSlot.BackgroundTransparency = 1
   scanSlot.LayoutOrder = totalToggles + 2
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
    headlineRows[1].Text = "Threats blocked: " .. #BlockLog
    headlineRows[2].Text = "Flagged events: " .. #EventLog
    headlineRows[3].Text = "HTTP requests seen: " .. Stats.HttpRequestsSeen
    headlineRows[4].Text = "Session started: " .. os.date("%H:%M:%S", Stats.SessionStart)

    ClearBreakdownRows()
    local reasonCounts = {}
    local reasonOrder = {}
    for _, entry in ipairs(BlockLog) do
     local r = entry.reason or "Unknown"
     if not reasonCounts[r] then
      reasonCounts[r] = 0
      table.insert(reasonOrder, r)
     end
     reasonCounts[r] = reasonCounts[r] + 1
    end

    if #reasonOrder == 0 then
     local row = BuildStatRow(6)
     row.TextColor3 = TEXT_DIM
     row.Text = "  (none yet)"
     table.insert(breakdownRows, row)
    else
     for i, r in ipairs(reasonOrder) do
      local row = BuildStatRow(6 + i)
      row.AutomaticSize = Enum.AutomaticSize.Y
      row.Size = UDim2.new(1, 0, 0, 0)
      row.TextWrapped = true
      row.Text = string.format("  %d  %s", reasonCounts[r], r)
      table.insert(breakdownRows, row)
     end
    end
   end

   local saveSlot = Instance.new("Frame")
   saveSlot.Name = "SaveStatsSlot"
   saveSlot.Size = UDim2.new(1, 0, 0, 40)
   saveSlot.BackgroundTransparency = 1
   saveSlot.LayoutOrder = 1000
   saveSlot.Parent = statsPanel

   local saveBtn = Instance.new("TextButton")
   saveBtn.Name = "SaveStatsButton"
   saveBtn.AutoButtonColor = false
   saveBtn.AnchorPoint = Vector2.new(0.5, 0.5)
   saveBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
   saveBtn.Size = UDim2.new(1, 0, 0, 34)
   saveBtn.BackgroundColor3 = CALM
   saveBtn.Font = Enum.Font.GothamBold
   saveBtn.TextSize = 13
   saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
   saveBtn.Text = "Save Stats to File"
   saveBtn.Parent = saveSlot
   NewCorner(9, saveBtn)

   local saveBase = CALM
   local saveHover = CALM:Lerp(Color3.fromRGB(255, 255, 255), 0.15)
   saveBtn.MouseEnter:Connect(function()
    TweenService:Create(saveBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = saveHover,
    }):Play()
   end)
   saveBtn.MouseLeave:Connect(function()
    TweenService:Create(saveBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
     BackgroundColor3 = saveBase,
    }):Play()
   end)
   saveBtn.MouseButton1Click:Connect(function()
    local ok = SaveStats()
    saveBtn.Text = ok and "Saved!" or "Save Failed"
    spawn_func(function()
     wait_func(1.5)
     saveBtn.Text = "Save Stats to File"
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
 local stripped = url:match("^https?://(.+)$") or url
 local host = stripped:match("^([^/]+)") or stripped
 return host:match("^([^:]+)") or host
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

local function InspectResponseForGiveaways(host, bodyStr)
 if host == "" or IsWhitelistedHost(host) or RuntimeBlockedDomains[host] then return false end
 local match = ScanForGiveaways(bodyStr)
 if match then
  MarkRuntimeBlocked(host, 'response matched blocklist "' .. match .. '"')
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
 if not httprequest then
  Console("warn", "No raw request available, IP-leak detection disabled")
  return
 end
 for _, url in ipairs(IPLookupCandidates) do
  local ok, res = pcall(httprequest, { Url = url, Method = "GET" })
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

local function ScanString(str, checkDeobfuscated)
 if typeof(str) ~= "string" or str == "" then return false, nil end

 if ProtectCookies and str:find(cookies, 1, true) then
  return true, "Blocked request containing .ROBLOSECURITY cookie"
 end

 local decoded = FullyUrlDecode(str)
 if ProtectCookies and decoded ~= str and decoded:find(cookies, 1, true) then
  return true, "Blocked URL-encoded .ROBLOSECURITY cookie leak"
 end

 if BlockWebhooks and (decoded:find("/api/webhooks/", 1, true) or decoded:find("webhook.site", 1, true)
    or decoded:find("pipedream.net", 1, true) or decoded:find("requestcatcher.com", 1, true)) then
  return true, "Blocked data exfiltration to Webhook"
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
  if BlockWebhooks and (b64Decoded:find("/api/webhooks/", 1, true) or b64Decoded:find("webhook.site", 1, true)
     or b64Decoded:find("pipedream.net", 1, true) or b64Decoded:find("requestcatcher.com", 1, true)) then
   return true, "Blocked base64-encoded webhook exfiltration"
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
   local bad, reason = ScanString(clean, false)
   if bad then
    return true, reason .. " (found after deobfuscation)"
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
 if host:find(":", 1, true) and host:match("^[%x:%[%]]+$") then return true end
 return false
end

local function HasNonStandardPort(url)
 if typeof(url) ~= "string" then return false end
 local port = tonumber(url:match("://[^/]-:(%d+)"))
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

 if method == "POST" and typeof(body) == "string" and #body > 20 then
  local entropy = CalculateEntropy(body)
  if entropy > 5.5 then
   score = score + 1
   table.insert(reasons, string.format("high-entropy payload (%.2f)", entropy))
  end
 end

 if #extraReasons > 0 then
  table.insert(reasons, "noted: " .. table.concat(extraReasons, ", "))
 end

 return score, table.concat(reasons, ", ")
end

local C2BlockThreshold = 4

local function ThreatScan(url, body, headers, method)
 local host = ExtractHost(FullyUrlDecode(typeof(url) == "string" and url or "")):lower()
 if IsWhitelistedHost(host) then return false, nil end

 local trustedVolume = IsHighVolumeTrusted(host)

 if ProtectDomains and not trustedVolume then
  local c2Score, c2Reasons = ScoreC2Suspicion(url, host, body, method)
  if c2Score >= C2BlockThreshold then
   return true, "Blocked, possible C2 infrastructure (" .. c2Reasons .. ")"
  elseif c2Score > 0 then
   LogEvent("c2-suspicion", host .. " meter " .. c2Score .. " (" .. c2Reasons .. ")")
  end
 end

 local bad, reason = ScanString(url, true)
 if bad then return true, reason end
 bad, reason = ScanString(body, true)
 if bad then return true, reason end
 bad, reason = ScanHeaders(headers)
 if bad then return true, reason end

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

local HookWatchList = {}
local function RegisterHookWatch(label, getCurrent)
 local ok, baseline = pcall(getCurrent)
 if not ok then return end
 table.insert(HookWatchList, { label = label, getCurrent = getCurrent, baseline = baseline, tamperedWarned = false })
end

local http_targets = {
 {"request", env.request, function() return env.request end},
 {"http_request", env.http_request, function() return env.http_request end},
}

local namespaces = { "syn", "fluxus", "krnl", "proto", "scriptware", "delta", "WR", "electron", "macsploit", "http", "sirhurt", "temple" }
for _, ns in ipairs(namespaces) do
 local obj = env[ns]
 if typeof(obj) == "table" then
  if typeof(obj.request) == "function" then
   table.insert(http_targets, {ns .. ".request", obj.request, function() local o = env[ns]; return o and o.request end})
  end
  if typeof(obj.get) == "function" then
   table.insert(http_targets, {ns .. ".get", obj.get, function() local o = env[ns]; return o and o.get end})
  end
  if typeof(obj.post) == "function" then
   table.insert(http_targets, {ns .. ".post", obj.post, function() local o = env[ns]; return o and o.post end})
  end
 end
end

local hooked_functions = {}
if hook_func then
 for _, target in ipairs(http_targets) do
  local name, func, getCurrent = target[1], target[2], target[3]
  if typeof(func) == "function" and not hooked_functions[func] then
   local old
   local wrapper = cclosure(function(options)
    CountHttpRequestSeen()
    local url, body, headers, method = "", "", nil, nil
    if typeof(options) == "table" then
     url = options.Url or options.url or ""
     body = options.Body or options.body or ""
     headers = options.Headers or options.headers
     method = options.method or options.Method
    elseif typeof(options) == "string" then
     url = options
    end
    local bad, reason = ThreatScan(url, body, headers, method)
    if bad then
     Console("warn", reason .. " [Hook: " .. name .. "]")
     LogBlock(reason, name, url)
     return {StatusCode = 403, Success = false, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
    end

    local res = old(options)
    if ProtectFingerprint and typeof(res) == "table" and typeof(url) == "string" then
     local host = ExtractHost(FullyUrlDecode(url)):lower()
     if InspectResponseForGiveaways(host, res.Body) then
      Console("warn", "Blocked response, matched IP logger content blocklist [Hook: " .. name .. "]")
      LogBlock("Matched IP logger content blocklist", name, url)
      return {StatusCode = 403, Success = false, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
     end
    end
    return res
   end)
   old = hook_func(func, wrapper)
   OriginalFunctions[old] = true
   HookedLiveFunctions[func] = true
   hooked_functions[func] = true
   if getCurrent then
    RegisterHookWatch(name, getCurrent)
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
  if ProtectWebSocket and typeof(url) == "string" then
   local bad, reason = ThreatScan(url, "", nil, nil)
   if bad then
    Console("warn", reason .. " [Hook: " .. name .. "]")
    LogBlock(reason, name, url)
    return nil
   end
  end
  local socket = oldConnect(url, ...)
  if typeof(socket) == "table" and typeof(socket.Send) == "function" and not hooked_functions[socket.Send] then
   local oldSend
   local liveSend = socket.Send
   oldSend = hook_func(socket.Send, cclosure(function(self, data, ...)
    if ProtectWebSocket and typeof(data) == "string" then
     local bad, reason = ScanString(data, true)
     if bad then
      Console("warn", reason .. " [Hook: " .. name .. ":Send]")
      LogBlock(reason, name .. ":Send", url)
      return nil
     end
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


spawn_func(function()
 pcall(wait_func, 1.5)

 if not UserSetMetatableManually then
  ProtectMetatable = not AntiCheatPresent()
  if not ProtectMetatable then
   Console("warn", "Metatable protection (__namecall/__newindex) auto-disabled: this game may have an anti-cheat/admin system that can detect hooked metamethods and kick/ban for it. HTTP requests made through executor functions are still protected. Toggle Metatable if you're confident this game doesn't check for it.")
   NotifyToggleChange()
  end
 end

 local raw = ProtectMetatable and getrawmetatable(game) or nil
 if raw then
  local oldnamecall = raw.__namecall
  local oldnewindex = raw.__newindex
  setreadonly(raw, false)

  raw.__namecall = cclosure(function(self, ...)
   local method = getnamecallmethod()
   if method == "HttpGet" or method == "HttpGetAsync" or method == "HttpPost" or method == "HttpPostAsync" or method == "GetAsync" or method == "PostAsync" then
    local url, body = ...
    if typeof(url) == "string" then
     CountHttpRequestSeen()
     local bad, reason = ThreatScan(url, typeof(body) == "string" and body or "", nil, method)
     if bad then
      Console("warn", reason .. " [Hook: " .. method .. "]")
      LogBlock(reason, method, url)
      return BLOCKED_JSON_BODY
     end

     local result = oldnamecall(self, ...)
     if ProtectFingerprint and typeof(result) == "string" then
      local host = ExtractHost(FullyUrlDecode(url)):lower()
      if InspectResponseForGiveaways(host, result) then
       Console("warn", "Blocked response, matched IP logger content blocklist [Hook: " .. method .. "]")
       LogBlock("Matched IP logger content blocklist", method, url)
       return BLOCKED_JSON_BODY
      end
     end
     return result
    end
   elseif method == "ReadPixels" or method == "WritePixels" or method == "GetImage" or method == "ImageContent" then
    local ok, className = pcall(function() return self.ClassName end)
    LogEvent("pixel-buffer-access", method .. " called on " .. (ok and tostring(className) or "instance"), "info")
   elseif method == "RequestAsync" then
    local options = ...
    if typeof(options) == "table" then
     CountHttpRequestSeen()
     local url = options.Url or options.url or ""
     local body = options.Body or options.body or ""
     local headers = options.Headers or options.headers
     local bad, reason = ThreatScan(url, body, headers, method)
     if bad then
      Console("warn", reason .. " [Hook: RequestAsync]")
      LogBlock(reason, "RequestAsync", url)
      return {Success = false, StatusCode = 403, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
     end

     local result = oldnamecall(self, ...)
     if ProtectFingerprint and typeof(result) == "table" and typeof(url) == "string" then
      local host = ExtractHost(FullyUrlDecode(url)):lower()
      if InspectResponseForGiveaways(host, result.Body) then
       Console("warn", "Blocked response, matched IP logger content blocklist [Hook: RequestAsync]")
       LogBlock("Matched IP logger content blocklist", "RequestAsync", url)
       return {Success = false, StatusCode = 403, Body = BLOCKED_JSON_BODY, Headers = {["Content-Type"] = "application/json"}}
      end
     end
     return result
    end
   end
   return oldnamecall(self, ...)
  end)

  raw.__newindex = cclosure(function(self, index, value)
   if ProtectConsoleGui and typeof(index) == "string" and typeof(value) == "string" and (index == "Text" or index == "PlaceholderText" or index == "ContentText") then
    local bad, reason = ScanString(value)
    if bad then
     Console("warn", reason .. " [Blocked GUI text assignment]")
     LogBlock(reason, "Text: " .. index, "(gui)")
     return oldnewindex(self, index, "[REDACTED by Vyrnox Guard]")
    end
   end
   return oldnewindex(self, index, value)
  end)
  setreadonly(raw, true)

  RegisterHookWatch("__namecall", function()
   local r = getrawmetatable(game)
   return r and r.__namecall
  end)
 end
end)

local WatchIntervalSeconds = 5
if #HookWatchList > 0 then
 spawn_func(function()
  while true do
   wait_func(WatchIntervalSeconds)
   for _, entry in ipairs(HookWatchList) do
    local ok, current = pcall(entry.getCurrent)
    local intact = ok and current == entry.baseline
    if intact then
     entry.tamperedWarned = false
    elseif not entry.tamperedWarned then
     entry.tamperedWarned = true
     Console("warn", "Hook tampering detected: \"" .. entry.label .. "\" not matching the state Vyrnox Guard installed, "
      .. "protection for this hook may have been silently removed. "
      .. "Treat this session as reduced protection.")
     LogEvent("hook-tampered", entry.label .. " changed from its post-install baseline")
    end
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
  local ok, current = pcall(entry.getCurrent)
  local intact = ok and current == entry.baseline
  Console("print", string.format("[%d] %s: %s", i, entry.label, intact and "GOOD" or "TAMPERED"))
 end
end

Console("print", "Protection Loaded")
