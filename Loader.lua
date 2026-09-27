local GAMES = {
 [2413927524] = {
  name = "The Rake REMASTERED",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/The%20Rake%20REMASTERED.lua"
 },
 [2768379856] = {
  name = "3008",
  url = "https://raw.githubusercontent.com/lqdxt/Vyrnox-Hub/refs/heads/main/3008.lua"
 }
}

const FOLDER_ROOT = "Vyrnox"
const FOLDER_HUB = "Vyrnox/Hub"
const CONSENT_PATH = "Vyrnox/Hub/.consent"

local StarterGui = game:GetService("StarterGui")

local function EnsureFolders()
 if not makefolder or not isfolder then return end
 pcall(function()
  if not isfolder(FOLDER_ROOT) then makefolder(FOLDER_ROOT) end
  if not isfolder(FOLDER_HUB) then makefolder(FOLDER_HUB) end
 end)
end

local function HasConsented()
 if not isfile or not readfile then return false end
 local ok, data = pcall(readfile, CONSENT_PATH)
 if not ok or type(data) ~= "string" then return false end
 return data:gsub("%s+", "") == "true"
end

local function SaveConsent()
 if not writefile then return end
 EnsureFolders()
 pcall(writefile, CONSENT_PATH, "true")
end

--- initial. will show in the script anyways if skipped
local function ConfirmLog()
 if HasConsented() then return true end

 local dur = 45
 local signal = Instance.new("BindableEvent")
 local bind = Instance.new("BindableFunction")

 bind.OnInvoke = function(button)
  signal:Fire(button == "Agree")
  return "ok"
 end

 local shown = false
 for _ = 1, 20 do
  shown = pcall(function()
   StarterGui:SetCore("SendNotification", {
    Title = "Clicking you agree",
    Text = "Sends your userid, executor and game info. Security reasons (banning).",
    Duration = dur,
    Callback = bind,
    Button1 = "Agree",
    Button2 = "Decline"
   })
  end)
  if shown then break end
  task.wait(0.25)
 end

 if not shown then
  return false
 end

 task.delay(dur, function()
  signal:Fire(false)
 end)

 local agreed = signal.Event:Wait()
 if agreed then SaveConsent() end
 return agreed
end

local function ResolveGame()
 local id = game.PlaceId

 if GAMES[id] then
  return GAMES[id]
 end

 return nil
end

local function NotifyUnsupported()
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

if not ConfirmLog() then
 return
end

local k, e = pcall(function()
 loadstring(game:HttpGet(entry.url))()
end)
if not k then warn("Something went wrong: " .. e) end
