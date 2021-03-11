--[[
    Author: Jxl
    Description: A builder module
]]

local Builder = {}

do
    local BLOCKS_FOLDER = game.ReplicatedStorage.Blocks
    local remotePath = game.ReplicatedStorage.rbxts_include.node_modules.net.out:FindFirstChild('_NetManaged') or game.ReplicatedStorage.Remotes.Functions
    local PLACE_BLOCK = remotePath.CLIENT_BLOCK_PLACE_REQUEST
    local EDIT_SIGN = remotePath.CLIENT_EDIT_SIGN
    local PLOW_BLOCK = remotePath.CLIENT_PLOW_BLOCK_REQUEST

    local Player = game.Players.LocalPlayer

    Builder.__index = Builder

    setmetatable(Builder, {
        __tostring = function()
            return "Builder"
        end
    })
    
    function Builder.new(Data)
        return setmetatable({
            Data = Data.Blocks,
            Size = Vector3.new(Data.Size[1], Data.Size[2], Data.Size[3]),
            Abort = false,
            Visibility = 0.5
        }, Builder)
    end

    function Builder:Round(Number) 
        if typeof(Number) == "number" then
            return math.round(Number / 3) * 3
        end
    end

    function Builder:SetupBlock(Model)
        for i, v in next, Model:GetDescendants() do
            if v:IsA("BasePart") then
                v.CanCollide = false
                if v.Transparency < 1 then
                    v.Transparency = self.Visibility
                end
            end
        end
    end

    function Builder:Init()
        local Model = Instance.new("Model")

        local Center = Instance.new("Part")
        Center.Position = Vector3.new(0, 0, 0)
        Center.Size = Vector3.new(3, 3, 3)
        Center.Transparency = 1
        Center.CanCollide = false
        Center.Anchored = true
        Center.Name = "[Center]"
        Center.Parent = Model

        Model.PrimaryPart = Center

        for Block, Array in next, self.Data do
            for i, v in next, Array do
                local Part = BLOCKS_FOLDER[Block]:Clone()

                if Part:IsA("Model") then
                    Part:SetPrimaryPartCFrame(CFrame.new(unpack(v.C)))
                    
                    if v.U and Part:FindFirstChild("bottom", true) then
                        local Bottom = Part:FindFirstChild("bottom", true)
                        Bottom.Transparency = 1

                        local Top = Part:FindFirstChild("top", true)
                        Top.Transparency = 0
                    end

                    if v.T and Part:FindFirstChild("TextBox", true) then
                        local Box = Part:FindFirstChild("TextBox", true)
                        Box.Text = v.T
                    end
                elseif Part:IsA("BasePart") then
                    Part.CFrame = CFrame.new(unpack(v.C))
                end

                Part.Parent = Model

                self:SetupBlock(Part)
            end
        end

        self.Model = Model
    end

    function Builder:SetCFrame(CF)
        if self.Model then
            self.Model:SetPrimaryPartCFrame(CF)
            self.Model.PrimaryPart.CFrame = CFrame.new(CF.Position.X, CF.Position.Y, CF.Position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        end
    end

    function Builder:SetVisibility(Value)
        self.Visibility = Value
        if self.Model then
            for i, v in next, self.Model:GetChildren() do
                self:SetupBlock(v)
            end
        end
    end

    function Builder:Render(Appear)
        if self.Model then
            self.Model.Parent = Appear and workspace or game.ReplicatedStorage
        end
    end

    function Builder:IsTaken(Position, Block)
        local Parts = workspace:FindPartsInRegion3(Region3.new(Position, Position), nil, math.huge)
        for i, v in next, Parts do
            if v.Parent and v.Parent.Name == "Blocks" and v.Name == Block then
                return true
            end
        end
        return false
    end

    function Builder:Place(Args, Listen)
        PLACE_BLOCK:InvokeServer(Args)
        if Listen then
            local Region = Region3.new(Args.cframe.Position, Args.cframe.Position)
            for i, v in next, workspace:FindPartsInRegion3(Region) do
                if v.Name == Args.blockType and v.Parent and v.Parent.Name == "Blocks" then
                    return v
                end
            end
        end
    end

    function Builder:Build(Callback)
        Callback.Start()
        for i, v in next, self.Model:GetChildren() do
            local Name = ((v.Name == "soil" or v.Name == "dirt") and "grass") or v.Name
            local Part = v.ClassName == "Model" and v.PrimaryPart or v:IsA("BasePart") and v
            if not self:IsTaken(Part.Position, v.Name) then 
                if self.Abort then
                    self.Abort = false
                    break
                else
                    if Name ~= "[Center]" then
                        Callback.Build(Part.CFrame)
                        spawn(function()
                            local TextBox = v:FindFirstChild("TextBox", true)
                            local Bottom = v:FindFirstChild("bottom", true)

                            local Block = self:Place({
                                blockType = Name;
                                cframe = Part.CFrame;
                                player_tracking_category = "join_from_web";
                                upperSlab = Bottom and Bottom.Transparency == 1;
                            }, v.Name == "soil" or TextBox)
                            
                            if Block and TextBox and TextBox.Text ~= "" then
                                EDIT_SIGN:InvokeServer({
                                    sign = Block;
                                    text = TextBox.Text
                                })
                            elseif Block and v.Name == "soil" then
                                local Tool = Player.Backpack:FindFirstChild("plow") or Player.Character:FindFirstChild("plow")
                                if Tool then
                                    Player.Character.Humanoid:EquipTool(Tool)
                                    PLOW_BLOCK:InvokeServer({
                                        block = Block
                                    })
                                end
                            end
                        end)
                        wait()
                    end
                end
            end
        end
        Callback.End()
    end

    function Builder:Abort()
        self.Abort = true
    end

    function Builder:Destroy()
        self.Model:Destroy()
        self.Model = nil
        self.Abort = true
        
        self = nil
    end
end

return Builder
