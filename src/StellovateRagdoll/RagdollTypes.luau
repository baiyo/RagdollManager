export type R6PARTS = "Head" | "Torso" | "Left Arm" | "Right Arm" | "Left Leg" | "Right Leg" | "HumanoidRootPart"
export type R6MOTORS = "Right Shoulder" | "Left Shoulder" | "Right Hip" | "Left Hip" | "Neck" | "RootJoint"

local UP    = Vector3.new( 0,  1, 0)
local DOWN  = Vector3.new( 0, -1, 0)
local RIGHT = Vector3.new( 1,  0, 0)
local LEFT  = Vector3.new(-1,  0, 0)

export type RigBallSocketLimits = {
	read UpperAngle:       number,
	read LowerAngleTwist: number,
	read UpperAngleTwist: number,
	read FrictionTorque:   number,
	read GravityReference: number,
	read MassReference:    number,
}

export type RigBallSocket = {
	read name: string,
	read attachment_a: Attachment, 
	read attachment_b: Attachment,
	read limits: RigBallSocketLimits
}

export type Attachment = { 
	read cframe: CFrame,
	read part: R6PARTS 
}

export type Motor = {
	read limb: R6PARTS,
	read motor: R6MOTORS,
	read root: boolean
}

export type RigNoCollide = {
	read P1: R6PARTS,
	read P2: R6PARTS
}

export type Rig = {
	read motors: { Motor },
	read sockets: { RigBallSocket },
	read no_collide: { RigNoCollide },
	read additional_attachments: { { any } }, 
}

-- I referenced these values from somewhere forgot where tho
local R6_NECK_LIMITS: RigBallSocketLimits = table.freeze {
	UpperAngle       =  30,
	LowerAngleTwist = -40,
	UpperAngleTwist =  40,
	FrictionTorque   =  0.5,
	GravityReference =  196.2,
	MassReference    =  1.4,
}

local R6_SHOULDER_LIMITS: RigBallSocketLimits = table.freeze {
	UpperAngle       =  110,
	LowerAngleTwist = -85,
	UpperAngleTwist =  85,
	FrictionTorque   =  0.5,
	GravityReference =  196.2,
	MassReference    =  1.4,
}

local R6_HIP_LIMITS: RigBallSocketLimits = table.freeze {
	UpperAngle       =  40,
	LowerAngleTwist = -5,
	UpperAngleTwist =  80,
	FrictionTorque   =  0.5,
	GravityReference =  196.2,
	MassReference    =  1.4,
}

-- Attachments sourced from:
-- https://github.com/Quenty/NevermoreEngine/blob/main/src/ragdoll/src/Shared/Rigging/RagdollAdditionalAttachmentUtils.lua
local R6_ADDITIONAL_ATTACHMENTS = {
	{ "Head",      "NeckAttachment",                 CFrame.new(0, -0.5, 0) },
	{ "Torso",     "NeckAttachment",                 CFrame.new(0,  1,   0) },

	{ "Torso",     "RightShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new( 1,   0.5, 0), RIGHT, UP)   },
	{ "Right Arm", "RightShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(-0.5, 0.5, 0), DOWN,  RIGHT) },

	{ "Torso",     "LeftShoulderRagdollAttachment",  CFrame.fromMatrix(Vector3.new(-1,   0.5, 0), LEFT,  UP)   },
	{ "Left Arm",  "LeftShoulderRagdollAttachment",  CFrame.fromMatrix(Vector3.new( 0.5, 0.5, 0), DOWN,  LEFT)  },

	{ "Torso",     "RightHipAttachment",             CFrame.new( 0.5, -1, 0) },
	{ "Right Leg", "RightHipAttachment",             CFrame.new( 0,    1, 0) },

	{ "Torso",     "LeftHipAttachment",              CFrame.new(-0.5, -1, 0) },
	{ "Left Leg",  "LeftHipAttachment",              CFrame.new( 0,    1, 0) },
}

local function attachment(parent: R6PARTS, cframe: CFrame): Attachment
	return {
		cframe = cframe,
		part = parent,
	}
end

local function find_attachment(part: R6PARTS, name: string): Attachment
	for _, entry in R6_ADDITIONAL_ATTACHMENTS do
		if entry[1] == part and entry[2] == name then
			return attachment(part, entry[3])
		end
	end
	error(`No attachment "{name}" found on part "{part}"`)
end

local function socket(
	name:         string,
	attachment_a: Attachment,
	attachment_b: Attachment,
	limits:       RigBallSocketLimits
): RigBallSocket
	return table.freeze {
		name         = name,
		attachment_a = attachment_a,
		attachment_b = attachment_b,
		limits       = limits,
	}
end

local function limb(part: R6PARTS, motor: R6MOTORS, kind: "Root" | "Limb"): Motor
	return table.freeze { limb = part, motor = motor, root = kind == "Root" }
end

local function no_collide(P1 : R6PARTS, P2 : R6PARTS): RigNoCollide
	return table.freeze{
		P1 = P1,
		P2 = P2
	}
end


local R6: Rig = table.freeze {
	motors = {
		limb("HumanoidRootPart", "RootJoint",     "Root"),
		limb("Torso",            "Neck",           "Limb"),
		limb("Torso",            "Left Hip",       "Limb"),
		limb("Torso",            "Right Hip",      "Limb"),
		limb("Torso",            "Left Shoulder",  "Limb"),
		limb("Torso",            "Right Shoulder", "Limb"),
	},

	no_collide = table.freeze {
		no_collide("Left Leg", "Right Leg"),

		no_collide("Torso", "Head"),
		no_collide("Torso", "Right Leg"),
		no_collide("Torso", "Right Arm"),
		no_collide("Torso", "Left Leg"),
		no_collide("Torso", "Left Arm"),
	},

	additional_attachments = R6_ADDITIONAL_ATTACHMENTS,

	sockets = table.freeze {
		socket(
			"Neck",
			find_attachment("Torso",     "NeckAttachment"),
			find_attachment("Head",      "NeckAttachment"),
			R6_NECK_LIMITS
		),
		socket(
			"RightShoulder",
			find_attachment("Torso",     "RightShoulderRagdollAttachment"),
			find_attachment("Right Arm", "RightShoulderRagdollAttachment"),
			R6_SHOULDER_LIMITS
		),
		socket(
			"LeftShoulder",
			find_attachment("Torso",    "LeftShoulderRagdollAttachment"),
			find_attachment("Left Arm", "LeftShoulderRagdollAttachment"),
			R6_SHOULDER_LIMITS
		),
		socket(
			"RightHip",
			find_attachment("Torso",     "RightHipAttachment"),
			find_attachment("Right Leg", "RightHipAttachment"),
			R6_HIP_LIMITS
		),
		socket(
			"LeftHip",
			find_attachment("Torso",    "LeftHipAttachment"),
			find_attachment("Left Leg", "LeftHipAttachment"),
			R6_HIP_LIMITS
		),
	},
}

return table.freeze {
	R6 = R6,
}