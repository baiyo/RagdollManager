--!strict
-- @author: baiyo
-- MIT License

-- Copyright (c) 2026 baiyo

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local Ragdoll = {}
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RagdollTypes = require("@self/RagdollTypes")

type SocketResult = {
	socket: BallSocketConstraint,
	att0: Attachment,
	att1: Attachment,
}

type ActiveRig = {
	sockets: { SocketResult },
	no_collides: { NoCollisionConstraint },
	attachments: { Attachment },
	motors: { Motor6D },
	presim: RBXScriptConnection,
	can_collide: { [BasePart]: boolean },
	root_priority: number,
}

local ActiveRigs: { [Model]: ActiveRig } = {}
local game_gravity = workspace.Gravity

workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
	game_gravity = workspace.Gravity
end)

local function FindPart(Character: Model, name: string): BasePart?
	return Character:FindFirstChild(name) :: BasePart?
end

local function NoCollide(PartA: BasePart, PartB: BasePart): NoCollisionConstraint
	local c = Instance.new("NoCollisionConstraint")
	c.Name = `{PartA.Name}||{PartB.Name}`
	c.Part0 = PartA
	c.Part1 = PartB
	c.Enabled = true
	c.Parent = PartA
	return c
end

local function CreateSocket(PartA: BasePart, PartB: BasePart, socket: RagdollTypes.RigBallSocket): SocketResult

	local limits = socket.limits
	local mass = PartB:GetMass()

	local att0 = Instance.new("Attachment")
	att0.Name = socket.name .. "Attachment0"
	att0.CFrame = socket.attachment_a.cframe
	att0.Parent = PartA

	local att1 = Instance.new("Attachment")
	att1.Name = socket.name .. "Attachment1"
	att1.CFrame = socket.attachment_b.cframe
	att1.Parent = PartB

	local bs = Instance.new("BallSocketConstraint")
	bs.Name = socket.name
	bs.Enabled = true
	bs.LimitsEnabled = true
	bs.UpperAngle = limits.UpperAngle
	bs.TwistLimitsEnabled = true
	bs.TwistLowerAngle = limits.LowerAngleTwist
	bs.TwistUpperAngle = limits.UpperAngleTwist
	bs.Attachment0 = att0
	bs.Attachment1 = att1

	local massScale = limits.MassReference and (mass / limits.MassReference) or 1
	local gravityScale = game_gravity / limits.GravityReference
	bs.MaxFrictionTorque = limits.FrictionTorque * massScale * gravityScale

	bs.Parent = PartB

	return { socket = bs, att0 = att0, att1 = att1 }
end

local function CreateJoints(Character: Model, rig: RagdollTypes.Rig): ({ SocketResult }, { NoCollisionConstraint })

	local sockets: { SocketResult } = {}
	local no_collides: { NoCollisionConstraint } = {}

	for _, socketDef in rig.sockets do
		local partA = FindPart(Character, socketDef.attachment_a.part)
		local partB = FindPart(Character, socketDef.attachment_b.part)
		if not (partA and partB) then
			warn(`[Ragdoll] CreateJoints missing part for socket "{socketDef.name}"`)
			continue
		end
		table.insert(sockets, CreateSocket(partA, partB, socketDef))
	end

	for _, nc in rig.no_collide do
		local partA = FindPart(Character, nc.P1)
		local partB = FindPart(Character, nc.P2)
		if not (partA and partB) then continue end
		table.insert(no_collides, NoCollide(partA, partB))
	end

	return sockets, no_collides
end

local function DisableMotors(Character: Model, rig: RagdollTypes.Rig): { Motor6D }
	local motors: { Motor6D } = {}

	for _, motorDef in rig.motors do
		if motorDef.root then continue end

		local limbPart = FindPart(Character, motorDef.limb)
		if not limbPart then continue end

		local motor = limbPart:FindFirstChild(motorDef.motor)
		if motor and motor:IsA("Motor6D") then
			motor.Enabled = false
			table.insert(motors, motor)
		end
	end

	return motors
end

function Ragdoll:Start(Character: Model)
	if ActiveRigs[Character] then return end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then warn("[Ragdoll] no Humanoid") return end

	local rig: RagdollTypes.Rig
	if Humanoid.RigType == Enum.HumanoidRigType.R6 then
		rig = RagdollTypes.R6
	else
		warn("[Ragdoll] unsupported rig type:", Humanoid.RigType) return
	end

	local Attachments: { Attachment } = {}
	for _, entry in rig.additional_attachments do
		local part = FindPart(Character, entry[1] :: string)
		if not part then continue end
		if part:FindFirstChild(entry[2] :: string) then continue end
		local att = Instance.new("Attachment")
		att.Name = entry[2] :: string
		att.CFrame = entry[3] :: CFrame
		att.Parent = part
		table.insert(Attachments, att)
	end

	local limb_collision: { [BasePart]: boolean } = {}

	local motors = DisableMotors(Character, rig)

	local presimConnection = RunService.PreSimulation:Connect(function()
		for _, m in motors do
			m.Transform = CFrame.identity
		end
	end)

	for _, motorDef in rig.motors do
		if motorDef.root then
			local hrp = FindPart(Character, motorDef.limb)
			if hrp then
				limb_collision[hrp] = hrp.CanCollide
				hrp.CanCollide = false
			end
		else
			local limbPart = FindPart(Character, motorDef.limb)
			if limbPart then
				local motor = limbPart:FindFirstChild(motorDef.motor)
				if motor and motor:IsA("Motor6D") and motor.Part1 then
					local part1 = motor.Part1
					limb_collision[part1] = part1.CanCollide
					part1.CanCollide = true
				end
			end
		end
	end

	local sockets, no_collides = CreateJoints(Character, rig)

	local hrp = Character:FindFirstChild("HumanoidRootPart") :: BasePart
	local rootPriority = hrp.RootPriority
	hrp.RootPriority = -9999

	Humanoid.EvaluateStateMachine = false
	Humanoid.AutoRotate = false
	Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	
	hrp:ApplyImpulse(Vector3.new(0, 0, -99999999999999990))

	ActiveRigs[Character] = {
		sockets = sockets,
		no_collides = no_collides,
		attachments = Attachments,
		motors = motors,
		presim = presimConnection,
		can_collide = limb_collision,
		root_priority = rootPriority,
	}
end

function Ragdoll:Stop(Character: Model)
	local Arr = ActiveRigs[Character]
	if not Arr then return end

	Arr.presim:Disconnect()

	for _, motor in Arr.motors do
		motor.Transform = CFrame.identity
		motor.Enabled = true
	end

	for part, wasColliding in Arr.can_collide do
		part.CanCollide = wasColliding
	end

	for _, sr in Arr.sockets do
		sr.att0:Destroy()
		sr.att1:Destroy()
		sr.socket:Destroy()
	end

	for _, nc in Arr.no_collides do nc:Destroy() end
	for _, att in Arr.attachments do att:Destroy() end

	local hrp = Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if hrp then hrp.RootPriority = Arr.root_priority end

	ActiveRigs[Character] = nil

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid and Humanoid.Health > 0 then
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		Humanoid.EvaluateStateMachine = true
		Humanoid.AutoRotate = true
	end
end

return Ragdoll