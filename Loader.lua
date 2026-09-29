local GAMES: { [number]: { name: string, url: string } } = table.freeze({
 [2413927524] = {
  name = "The Rake REMASTERED",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/The%20Rake%20REMASTERED.lua"
 },
 [134208374070897] = {
  name = "MONOCHROME",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/MONOCHROME.lua"
 },
 --[[ not done
 [2768379856] = {
  name = "3008",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/3008.lua",
 }
 ]]
})

local FOLDER_ROOT: string = "Vyrnox"
local FOLDER_HUB: string = "Vyrnox/Hub"
local SEEN_FLAG: string = FOLDER_HUB .. "/notice_seen.flag"

local StarterGui = game:GetService("StarterGui")

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

local function HasFileAPI(): boolean
 return type(readfile) == "function"
  and type(writefile) == "function"
  and type(isfile) == "function"
  and type(isfolder) == "function"
  and type(makefolder) == "function"
end

local function Seen(): boolean
 if not HasFileAPI() then return false end
 local ok, exists = pcall(isfile, SEEN_FLAG)
 if not ok or not exists then return false end
 local rok, content = pcall(readfile, SEEN_FLAG)
 return rok and type(content) == "string" and #content > 0
end

local function MarkSeen(): boolean
 if not HasFileAPI() then
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
  "using Vyrnox Hub",
  "Sends your username on security events (kicks, bans and appeals)",
  6
 )

 if shown then MarkSeen() end
 return shown
end

local function GetGame(): { name: string, url: string }?
 return GAMES[game.PlaceId]
end

local function NotifyUnsupported(): ()
 Notify(
  "Vyrnox Hub",
  "This game (" .. tostring(game.PlaceId) .. ") isn't supported",
  6
 )
end

local function Main(): ()
 local entry = GetGame()
 if not entry then
  NotifyUnsupported()
  return
 end

 ConfirmLog()

 if type(game.HttpGet) ~= "function" then
  warn("env error: game:HttpGet is missing")
  return
 end

 local ht, src = pcall(game.HttpGet, game, entry.url)
 if not ht then
  warn("HttpGet failed: " .. tostring(src))
  return
 end
 if type(src) ~= "string" or #src == 0 then
  warn("empty response from " .. entry.url)
  return
 end

 if type(loadstring) ~= "function" then
  warn("env error: loadstring is missing")
  return
 end

 local cf, ce = loadstring(src)
 if not cf or type(cf) ~= "function" then
  warn(tostring(ce))
  return
 end

 local rs, re = pcall(cf)
 if not rs then
  warn(tostring(re))
 end
end

Main()
