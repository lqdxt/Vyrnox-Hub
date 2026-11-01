local HttpService = game:GetService("HttpService")

local ChangelogManager = {}
ChangelogManager.__index = ChangelogManager

local TAG_COLORS = {
 ["+"] = Color3.fromRGB(117, 255, 111),
 ["!"] = Color3.fromRGB(255, 87, 93),
 ["*"] = Color3.fromRGB(0, 170, 255),
 ["~"] = Color3.fromRGB(235, 180, 52),
 ["-"] = Color3.fromRGB(180, 180, 180),
 ["i"] = Color3.fromRGB(255, 200, 0),
}

local GAME_HEADER_COLOR = Color3.fromRGB(160, 180, 255)

local function Hex(c)
 return string.format("#%02x%02x%02x",
  math.floor(c.R * 255 + 0.5),
  math.floor(c.G * 255 + 0.5),
  math.floor(c.B * 255 + 0.5))
end

function ChangelogManager.Parse(jsonString)
 if type(jsonString) ~= "string" or jsonString == "" then return nil end
 local ok, decoded = pcall(HttpService.JSONDecode, HttpService, jsonString)
 if not ok or type(decoded) ~= "table" then return nil end
 if type(decoded.versions) ~= "table" then return nil end
 return decoded.versions
end

function ChangelogManager.Render(tab, versions)
 if not tab or not tab.Container then return end

 local box = Instance.new("ScrollingFrame")
 box.Size = UDim2.new(1, 0, 1, 0)
 box.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
 box.BorderSizePixel = 0
 box.ScrollBarThickness = 6
 box.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
 box.CanvasSize = UDim2.new(0, 0, 0, 0)
 box.AutomaticCanvasSize = Enum.AutomaticSize.Y
 box.ScrollingDirection = Enum.ScrollingDirection.Y
 box.Parent = tab.Container

 local pad = Instance.new("UIPadding")
 pad.PaddingTop = UDim.new(0, 8)
 pad.PaddingBottom = UDim.new(0, 8)
 pad.PaddingLeft = UDim.new(0, 10)
 pad.PaddingRight = UDim.new(0, 10)
 pad.Parent = box

 local list = Instance.new("UIListLayout")
 list.SortOrder = Enum.SortOrder.LayoutOrder
 list.Padding = UDim.new(0, 4)
 list.Parent = box

 if not versions or #versions == 0 then
  local lbl = Instance.new("TextLabel")
  lbl.Size = UDim2.new(1, -6, 0, 20)
  lbl.BackgroundTransparency = 1
  lbl.Text = "Changelog unavailable. Check the GitHub repo."
  lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
  lbl.TextXAlignment = Enum.TextXAlignment.Left
  lbl.Font = Enum.Font.Code
  lbl.TextSize = 12
  lbl.RichText = true
  lbl.Parent = box
  return
 end

 local order = 0

 for vIndex, ver in ipairs(versions) do
  if vIndex > 1 then
   order += 1
   local spacer = Instance.new("Frame")
   spacer.Size = UDim2.new(1, -6, 0, 8)
   spacer.BackgroundTransparency = 1
   spacer.LayoutOrder = order
   spacer.Parent = box
  end

  order += 1
  local header = Instance.new("TextLabel")
  header.Size = UDim2.new(1, -6, 0, 20)
  header.BackgroundTransparency = 1
  header.TextWrapped = true
  header.TextXAlignment = Enum.TextXAlignment.Left
  header.RichText = true
  header.Font = Enum.Font.Code
  header.TextSize = 14
  header.LayoutOrder = order
  header.Text = string.format('<font color="#ffffff"><b>%s</b></font>',
   tostring(ver.version or "?"))
  header.Parent = box

  for _, section in ipairs(ver.games or {}) do
   local entries = section.entries or {}
   if #entries > 0 then
    order += 1
    local gameHeader = Instance.new("TextLabel")
    gameHeader.Size = UDim2.new(1, -6, 0, 18)
    gameHeader.BackgroundTransparency = 1
    gameHeader.TextWrapped = true
    gameHeader.TextXAlignment = Enum.TextXAlignment.Left
    gameHeader.RichText = true
    gameHeader.Font = Enum.Font.Code
    gameHeader.TextSize = 12
    gameHeader.LayoutOrder = order
    gameHeader.Text = string.format('<font color="%s"><b>── %s ──</b></font>',
     Hex(GAME_HEADER_COLOR), tostring(section.name or "Unknown"))
    gameHeader.Parent = box

    for _, entry in ipairs(entries) do
     order += 1
     local tag = entry[1] or "-"
     local text = entry[2] or ""
     local color = TAG_COLORS[tag] or Color3.fromRGB(180, 180, 180)

     local line = Instance.new("TextLabel")
     line.Size = UDim2.new(1, -6, 0, 18)
     line.BackgroundTransparency = 1
     line.TextWrapped = true
     line.TextXAlignment = Enum.TextXAlignment.Left
     line.RichText = true
     line.Font = Enum.Font.Code
     line.TextSize = 12
     line.LayoutOrder = order
     line.Text = string.format('<font color="%s">[%s]</font> <font color="%s">%s</font>',
      Hex(color), tag, Hex(color), text)
     line.Parent = box
    end
   end
  end
 end
end

return ChangelogManager
