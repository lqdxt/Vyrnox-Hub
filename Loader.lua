local GAMES = {
 [2413927524] = {
  name = "The Rake REMASTERED",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/The%20Rake%20REMASTERED.lua"
 },
 --[[ not done
 [2768379856] = {
  name = "3008",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/3008.lua"
 }
 ]]
}

local FOLDER_ROOT = "Vyrnox"
local FOLDER_HUB = "Vyrnox/Hub"
local SEEN_FLAG = FOLDER_HUB .. "/notice_seen.flag"

local StarterGui = game:GetService("StarterGui")

local Seen = function()
 local ok = pcall(readfile, SEEN_FLAG)
 return ok
end

local MarkSeen = function()
 pcall(function()
  if type(isfolder) == "function" and type(makefolder) == "function" then
   if not isfolder(FOLDER_ROOT) then makefolder(FOLDER_ROOT) end
   if not isfolder(FOLDER_HUB) then makefolder(FOLDER_HUB) end
  end
  writefile(SEEN_FLAG, "seen")
 end)
end

local ConfirmLog = function()
 if Seen() then return true end

 local shown = false
 for _ = 1, 20 do
  shown = pcall(function()
   StarterGui:SetCore("SendNotification", {
    Title = "using Vyrnox Hub",
    Text = "Sends your username and user ID on security events (kicks, bans, appeals, feedback).",
    Duration = 10,
   })
  end)
  if shown then break end
  task.wait(0.25)
 end

 if shown then MarkSeen() end
 return shown
end

local ResolveGame = function()
 local id = game.PlaceId
 if GAMES[id] then return GAMES[id] end
 return nil
end

local NotifyUnsupported = function()
 pcall(function()
  StarterGui:SetCore("SendNotification", {
   Title = "Vyrnox Hub",
   Text = "This game (" .. tostring(game.PlaceId) .. ") isn't supported.",
   Duration = 6,
  })
 end)
end

local entry = ResolveGame()
if not entry then
 NotifyUnsupported()
 return
end

ConfirmLog()

local k, e = pcall(function()
 loadstring(game:HttpGet(entry.url))()
end)
if not k then warn("Something went wrong: " .. e) end
