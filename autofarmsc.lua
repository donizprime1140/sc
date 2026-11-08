-- Custom GrowBlox Farm Script (Auto Plant & Auto Harvest) - Rebuild Version
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- Mengakses remote server
local remotes = ReplicatedStorage:WaitForChild("GameNetworkFolder", 5)
local plantEvent = remotes and remotes:WaitForChild("RequestPlantAction", 5)
local getSeeds = remotes and remotes:WaitForChild("FetchSeedList", 5)

-- Ambil daftar seed dari server
local seeds = {}
if getSeeds then
    local success, result = pcall(function()
        return getSeeds:InvokeServer()
    end)
    if success and type(result) == "table" then
        seeds = result
    end
end

if #seeds == 0 then
    seeds = {"DefaultSeed"}
end

local selectedSeedIndex = 1
local isPlanting = false
local isHarvesting = false
local plantCount = 0
local harvestCount = 0
local runToken = 0

-- Anti-AFK (Mencegah disconnect otomatis)
player.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- Membuat ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomFarmGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(280, 380)
mainFrame.Position = UDim2.new(0.5, -140, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 33)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

-- Header Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CUSTOM GROWBLOX FARM"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

-- Tombol Pilih Seed
local seedButton = Instance.new("TextButton")
seedButton.Size = UDim2.new(1, -30, 0, 35)
seedButton.Position = UDim2.fromOffset(15, 50)
seedButton.BackgroundColor3 = Color3.fromRGB(35, 43, 60)
seedButton.TextColor3 = Color3.fromRGB(240, 240, 240)
seedButton.TextSize = 12
seedButton.Font = Enum.Font.GothamMedium
seedButton.Text = "SEED: " .. seeds[selectedSeedIndex]
seedButton.Parent = mainFrame
Instance.new("UICorner", seedButton).CornerRadius = UDim.new(0, 8)

seedButton.MouseButton1Click:Connect(function()
    selectedSeedIndex = (selectedSeedIndex % #seeds) + 1
    seedButton.Text = "SEED: " .. seeds[selectedSeedIndex]
end)

-- Status & Info Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -30, 0, 25)
statusLabel.Position = UDim2.fromOffset(15, 95)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Status: Ready (Anti-AFK Active)"
statusLabel.Parent = mainFrame

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -30, 0, 25)
countLabel.Position = UDim2.fromOffset(15, 115)
countLabel.BackgroundTransparency = 1
countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
countLabel.TextSize = 11
countLabel.Font = Enum.Font.Gotham
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Text = "Planted: 0 | Harvested: 0"
countLabel.Parent = mainFrame

-- Tombol Start Auto Plant
local startPlantButton = Instance.new("TextButton")
startPlantButton.Size = UDim2.new(1, -30, 0, 38)
startPlantButton.Position = UDim2.fromOffset(15, 150)
startPlantButton.BackgroundColor3 = Color3.fromRGB(46, 160, 67)
startPlantButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startPlantButton.TextSize = 13
startPlantButton.Font = Enum.Font.GothamBold
startPlantButton.Text = "START AUTO PLANT"
startPlantButton.Parent = mainFrame
Instance.new("UICorner", startPlantButton).CornerRadius = UDim.new(0, 8)

-- Tombol Start Auto Harvest
local startHarvestButton = Instance.new("TextButton")
startHarvestButton.Size = UDim2.new(1, -30, 0, 38)
startHarvestButton.Position = UDim2.fromOffset(15, 195)
startHarvestButton.BackgroundColor3 = Color3.fromRGB(30, 130, 200)
startHarvestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startHarvestButton.TextSize = 13
startHarvestButton.Font = Enum.Font.GothamBold
startHarvestButton.Text = "START AUTO HARVEST"
startHarvestButton.Parent = mainFrame
Instance.new("UICorner", startHarvestButton).CornerRadius = UDim.new(0, 8)

-- Tombol Stop All
local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(1, -30, 0, 38)
stopButton.Position = UDim2.fromOffset(15, 250)
stopButton.BackgroundColor3 = Color3.fromRGB(215, 58, 73)
stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopButton.TextSize = 13
stopButton.Font = Enum.Font.GothamBold
stopButton.Text = "STOP ALL"
stopButton.Parent = mainFrame
Instance.new("UICorner", stopButton).CornerRadius = UDim.new(0, 8)

local function updateCounterText()
    countLabel.Text = string.format("Planted: %d | Harvested: %d", plantCount, harvestCount)
end

-- Logika Auto Plant
startPlantButton.MouseButton1Click:Connect(function()
    if isPlanting then return end
    isPlanting = true
    runToken = runToken + 1
    local currentToken = runToken
    statusLabel.Text = "Status: Auto Planting..."

    task.spawn(function()
        while isPlanting and runToken == currentToken do
            local plantSpots = workspace:FindFirstChild("PlantSpots")
            if plantSpots then
                for _, spot in ipairs(plantSpots:GetChildren()) do
                    if not isPlanting or runToken ~= currentToken then break end
                    
                    if spot:IsA("BasePart") and spot:GetAttribute("OwnerUserId") == player.UserId and not spot:GetAttribute("Planted") then
                        if plantEvent then
                            plantEvent:FireServer(seeds[selectedSeedIndex], spot.Name)
                            plantCount = plantCount + 1
                            updateCounterText()
                        end
                        task.wait(0.4)
                    end
                end
            end
            task.wait(1)
        end
        statusLabel.Text = "Status: Plant Stopped"
    end)
end)

-- Logika Auto Harvest (Mendeteksi objek tanaman yang siap dipanen di workspace)
startHarvestButton.MouseButton1Click:Connect(function()
    if isHarvesting then return end
    isHarvesting = true
    runToken = runToken + 1
    local currentToken = runToken
    statusLabel.Text = "Status: Auto Harvesting..."

    task.spawn(function()
        while isHarvesting and runToken == currentToken do
            -- Mencari objek tanaman di workspace yang berakhiran "_Plant" atau sesuai struktur game
            for _, obj in ipairs(workspace:GetChildren()) do
                if not isHarvesting or runToken ~= currentToken then break end
                
                if obj:IsA("Model") and string.find(obj.Name, "_Plant") then
                    -- Simulasi atau pemanggilan fungsi interaksi panen (bisa disesuaikan dengan remote game aslinya)
                    -- Contoh: Berjalan mendekati tanaman atau memanggil event hapus/panen
                    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and obj.PrimaryPart then
                        hrp.CFrame = obj.PrimaryPart.CFrame
                        task.wait(0.3)
                        
                        -- Mengubah atribut spot kembali kosong jika ditemukan relasinya
                        local spotName = string.gsub(obj.Name, "_Plant", "")
                        local spot = workspace:FindFirstChild("PlantSpots") and workspace.PlantSpots:FindFirstChild(spotName)
                        if spot then
                            spot:SetAttribute("Planted", false)
                        end
                        
                        obj:Destroy()
                        harvestCount = harvestCount + 1
                        updateCounterText()
                    end
                end
            end
            task.wait(1.5)
        end
        statusLabel.Text = "Status: Harvest Stopped"
    end)
end)

-- Tombol Stop
stopButton.MouseButton1Click:Connect(function()
    isPlanting = false
    isHarvesting = false
    runToken = runToken + 1
    statusLabel.Text = "Status: All Stopped"
end)
