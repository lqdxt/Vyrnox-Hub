local FOLDER_ROOT: string = "Vyrnox"
local FOLDER_HUB: string = "Vyrnox/Hub"
local SEEN_FLAG: string = FOLDER_HUB .. "/notice_seen.flag"

local StarterGui: StarterGui = game:GetService("StarterGui")

local function Notify(title: string, text: string, duration: number?): boolean
 local data = {
  Title = title,
  Text = text,
  Duration = duration or 5,
 }

 for _ = 1, 20 do
  local s = pcall(StarterGui.SetCore, StarterGui, "SendNotification", data)
  if s then
   return true
  end
  task.wait(0.25)
 end

 return false
end

local function FileAPI(): boolean
 return type(readfile) == "function"
  and type(writefile) == "function"
  and type(isfile) == "function"
  and type(isfolder) == "function"
  and type(makefolder) == "function"
end

local function Seen(): boolean
 if not FileAPI() then return false end
 local k, et = pcall(isfile, SEEN_FLAG)
 if not k or not et then return false end
 local rk, ct = pcall(readfile, SEEN_FLAG)
 return rk and type(ct) == "string" and #ct > 0
end

local function MarkSeen(): boolean
 if not FileAPI() then
  return false
 end

 return pcall(function()
  if not isfolder(FOLDER_ROOT) then
   makefolder(FOLDER_ROOT)
  end
  if not isfolder(FOLDER_HUB) then
   makefolder(FOLDER_HUB)
  end
  writefile(SEEN_FLAG, "seen")
 end)
end

local function ConfirmLog(): boolean
 if Seen() then return true end

 local shown = Notify(
  "NOTICE",
  "Sends your username on security events (kicks, bans and appeals)",
  6
 )

 if shown then MarkSeen() end
 return shown
end

local function Main(): ()
 ConfirmLog()

 if type(game.HttpGet) ~= "function" then
  Notify("env error", "game:HttpGet is missing")
  return
 end

 if type(loadstring) ~= "function" then
  Notify("env error", "loadstring is missing")
  return
 end

 local k, e = pcall(function()
  loadstring(game:HttpGet("https://api.jnkie.com/api/v1/loaders/public/700dc87c48f4bd6c2a974111b6f3c6d4a984d31f27ef31ab995a6eeff3dc570a/download"))()
 end)

 if not k then
  Notify("unknown error", tostring(e))
 end
end

Main()
