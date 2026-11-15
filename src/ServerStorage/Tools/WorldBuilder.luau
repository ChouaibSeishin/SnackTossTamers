-- WorldBuilder (ModuleScript)
-- Studio location: ServerStorage > Tools > WorldBuilder
--
-- EDIT-MODE TOOL. Nothing in this module runs during gameplay. Run it from
-- Studio's Command Bar while the game is NOT being played:
--
--   require(game.ServerStorage.Tools.WorldBuilder:Clone()).Build()
--   require(game.ServerStorage.Tools.WorldBuilder:Clone()).Validate()
--   require(game.ServerStorage.Tools.WorldBuilder:Clone()).ApplyLighting()
--
-- Why ":Clone()": Studio caches a ModuleScript once the Command Bar has
-- required it, so later edits would be ignored until Studio restarts.
-- Requiring a fresh clone always runs the current code. WorldConfig is loaded
-- from a clone for the same reason.
--
-- Build():
--   * Deletes ONLY Workspace.GeneratedWorld (if present) and rebuilds it from
--     WorldConfig. Nothing else in Workspace, Lighting, or Terrain is touched.
--   * The result is saved in the place file (File > Save). The code that
--     produces it lives in Git, so the map can always be rebuilt exactly.
--   * Never hand-edit objects inside GeneratedWorld; the next Build() replaces
--     them. Put hand-made additions in Workspace.WorldDecor instead.
--
-- Validate(): checks the built map with real raycasts (gaps, zones, lane
-- clearance, markers, spawn, throwing line direction) and prints a report.
--
-- ApplyLighting(): optional. Sets a bright simulator look on Lighting and its
-- Atmosphere. This DOES change Studio-owned Lighting settings.
--
-- Keep this file free of Luau-only syntax so it can be smoke-tested outside
-- Studio with a mock engine.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local WorldBuilder = {}

WorldBuilder.WorldName = "GeneratedWorld"
WorldBuilder.LandingTag = "LandingSurface"

-- Fixed seed: decorations land in the same places on every rebuild.
local RANDOM_SEED = 20261114
-- Roblox parts can be at most 2048 studs long; long boxes are split below this.
local MAX_PART_LENGTH = 2000

local TOWARD_TOWN = Vector3.new(-1, 0, 0)
local TOWARD_FIELD = Vector3.new(1, 0, 0)

local WHITE = Color3.fromRGB(255, 255, 255)
local DARK_TEXT = Color3.fromRGB(40, 40, 52)
local OUTLINE = Color3.fromRGB(30, 30, 40)
local WOOD = Color3.fromRGB(122, 84, 52)
local STONE = Color3.fromRGB(236, 226, 200)
local GOLD = Color3.fromRGB(255, 214, 72)

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function loadWorldConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	local module = config and config:FindFirstChild("WorldConfig")
	if not module then
		error("WorldBuilder: ReplicatedStorage.Shared.Config.WorldConfig not found. Is Rojo connected and synced?")
	end
	return require(module:Clone())
end

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Lighter (factor > 1) or darker (factor < 1) version of an {R, G, B} color.
local function shade(c, factor)
	return Color3.fromRGB(
		clamp(math.floor(c[1] * factor + 0.5), 0, 255),
		clamp(math.floor(c[2] * factor + 0.5), 0, 255),
		clamp(math.floor(c[3] * factor + 0.5), 0, 255)
	)
end

-- CFrame at `position` whose front face (LookVector) points along `direction`.
local function facing(position, direction)
	return CFrame.lookAt(position, position + direction)
end

-- Cylinders run along their local X axis; this stands one upright.
local function upright(x, y, z)
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
end

local function newContainer(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- Creates one anchored part. Spec fields:
--   Parent, Name, Size, CFrame, Color, Material, Shape, Class, Transparency
--   Decor = true      -> purely visual: no collision, ignored by raycasts, no shadow
--   CastShadow = false
local function makePart(spec)
	local part = Instance.new(spec.Class or "Part")
	part.Name = spec.Name or "Part"
	part.Anchored = true
	if spec.Shape then
		part.Shape = spec.Shape
	end
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = spec.Color or WHITE
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- No part in the world needs Touched events; turning them off saves work.
	part.CanTouch = false
	if spec.Decor then
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	end
	if spec.CastShadow == false then
		part.CastShadow = false
	end
	if spec.Transparency then
		part.Transparency = spec.Transparency
	end
	part.Parent = spec.Parent
	return part
end

-- Axis-aligned box from bounds {x0, x1, y0, y1, z0, z1}. Boxes longer than
-- MAX_PART_LENGTH along X are split into several parts. Returns a list.
local function makeBoxes(spec)
	local b = spec.Bounds
	local x0, x1, y0, y1, z0, z1 = b[1], b[2], b[3], b[4], b[5], b[6]
	local pieces = math.max(1, math.ceil((x1 - x0) / MAX_PART_LENGTH))
	local pieceLength = (x1 - x0) / pieces
	local parts = {}
	for i = 1, pieces do
		local px0 = x0 + (i - 1) * pieceLength
		local px1 = (i == pieces) and x1 or (px0 + pieceLength)
		local piece = {}
		for key, value in pairs(spec) do
			piece[key] = value
		end
		piece.Size = Vector3.new(px1 - px0, y1 - y0, z1 - z0)
		piece.CFrame = CFrame.new((px0 + px1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		parts[#parts + 1] = makePart(piece)
	end
	return parts
end

local function makeBox(spec)
	return makeBoxes(spec)[1]
end

-- Text on the front face of a part (the face its LookVector points out of).
local function addLabel(part, text, textColor, strokeColor, maxDistance)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	-- 0 = always render; markers use a limit to save work on far-away text.
	gui.MaxDistance = maxDistance or 0

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = textColor
	if strokeColor then
		label.TextStrokeColor3 = strokeColor
		label.TextStrokeTransparency = 0
	else
		label.TextStrokeTransparency = 1
	end
	label.Parent = gui
	gui.Parent = part
	return gui
end

-- A board on one or two posts. Position is the ground point under the
-- board's center; the board's text faces `Facing`.
local function makeSign(spec)
	local model = newContainer("Model", spec.Name, spec.Parent)
	local board = spec.BoardSize
	local base = facing(spec.Position, spec.Facing)
	local boardPart = makePart({
		Parent = model,
		Name = "Board",
		Size = board,
		CFrame = base * CFrame.new(0, spec.PostHeight + board.Y / 2, 0),
		Color = spec.BoardColor,
	})
	addLabel(boardPart, spec.Text, spec.TextColor, spec.StrokeColor, spec.MaxDistance)

	local postHeight = spec.PostHeight + board.Y
	local postZ = board.Z / 2 + 0.5 -- just behind the board
	local postXs = spec.SinglePost and { 0 } or { -(board.X / 2 - 1), board.X / 2 - 1 }
	for _, postX in ipairs(postXs) do
		makePart({
			Parent = model,
			Name = "Post",
			Size = Vector3.new(1, postHeight, 1),
			CFrame = base * CFrame.new(postX, postHeight / 2, postZ),
			Color = spec.PostColor or WOOD,
			Material = Enum.Material.Wood,
		})
	end
	return model, boardPart
end

---------------------------------------------------------------------------
-- Reusable low-poly props. (x, z) is the ground point; `top` is ground Y.
---------------------------------------------------------------------------

local Props = {}

function Props.tree(parent, x, z, top, scale, angle, leafColor)
	local model = newContainer("Model", "Tree", parent)
	makePart({
		Parent = model, Name = "Trunk",
		Size = Vector3.new(1.6, 7, 1.6) * scale,
		CFrame = CFrame.new(x, top + 3.5 * scale, z),
		Color = WOOD, Material = Enum.Material.Wood,
	})
	makePart({
		Parent = model, Name = "Leaves",
		Size = Vector3.new(8, 6, 8) * scale,
		CFrame = CFrame.new(x, top + 9 * scale, z) * CFrame.Angles(0, angle, 0),
		Color = leafColor,
	})
	makePart({
		Parent = model, Name = "LeavesTop",
		Size = Vector3.new(5, 4, 5) * scale,
		CFrame = CFrame.new(x, top + 13 * scale, z) * CFrame.Angles(0, angle + 0.6, 0),
		Color = leafColor:Lerp(WHITE, 0.15),
	})
	return model
end

function Props.pine(parent, x, z, top, scale, angle, leafColor, snowy)
	local model = newContainer("Model", "Pine", parent)
	makePart({
		Parent = model, Name = "Trunk",
		Size = Vector3.new(1.4, 5, 1.4) * scale,
		CFrame = CFrame.new(x, top + 2.5 * scale, z),
		Color = WOOD, Material = Enum.Material.Wood,
	})
	local tiers = { { 9, 5 }, { 6.5, 8 }, { 4, 11 } }
	for i, tier in ipairs(tiers) do
		makePart({
			Parent = model, Name = "Tier",
			Size = Vector3.new(tier[1], 3, tier[1]) * scale,
			CFrame = CFrame.new(x, top + tier[2] * scale, z) * CFrame.Angles(0, angle + i * 0.35, 0),
			Color = leafColor,
		})
	end
	if snowy then
		makePart({
			Parent = model, Name = "SnowCap",
			Size = Vector3.new(2.4, 1.6, 2.4) * scale,
			CFrame = CFrame.new(x, top + 13.2 * scale, z) * CFrame.Angles(0, angle, 0),
			Color = WHITE, Material = Enum.Material.Snow,
		})
	end
	return model
end

function Props.flower(parent, x, z, top, petalColor)
	local model = newContainer("Model", "Flower", parent)
	makePart({
		Parent = model, Name = "Stem", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 0.3, 0.3),
		CFrame = upright(x, top + 1, z),
		Color = Color3.fromRGB(60, 150, 60), Decor = true,
	})
	makePart({
		Parent = model, Name = "Petals", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.8, 1.8),
		CFrame = upright(x, top + 2.1, z),
		Color = petalColor, Decor = true,
	})
	return model
end

function Props.bush(parent, x, z, top, scale, color)
	return makePart({
		Parent = parent, Name = "Bush", Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6) * scale,
		CFrame = CFrame.new(x, top + 1.8 * scale, z),
		Color = color,
	})
end

-- A big half-buried ball: hills, dunes.
function Props.mound(parent, name, x, z, top, size, color, material)
	return makePart({
		Parent = parent, Name = name, Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(x, top - size * 0.3, z),
		Color = color, Material = material,
		CastShadow = false,
	})
end

function Props.rock(parent, x, z, top, scale, rng, color, material)
	return makePart({
		Parent = parent, Name = "Rock",
		Size = Vector3.new(rng:NextNumber(4, 8), rng:NextNumber(3, 6), rng:NextNumber(4, 8)) * scale,
		CFrame = CFrame.new(x, top + 1 * scale, z)
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5)),
		Color = color, Material = material or Enum.Material.Slate,
	})
end

function Props.mushroom(parent, x, z, top, scale, capColor)
	local model = newContainer("Model", "Mushroom", parent)
	makePart({
		Parent = model, Name = "Stem", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 1.4, 1.4) * scale,
		CFrame = upright(x, top + 1.5 * scale, z),
		Color = Color3.fromRGB(244, 236, 220), Decor = true,
	})
	makePart({
		Parent = model, Name = "Cap", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 5, 5) * scale,
		CFrame = upright(x, top + 3.5 * scale, z),
		Color = capColor, Decor = true,
	})
	return model
end

function Props.cactus(parent, x, z, top, scale, rng)
	local model = newContainer("Model", "Cactus", parent)
	local green = Color3.fromRGB(76, 160, 84)
	makePart({
		Parent = model, Name = "Trunk", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 2.4, 2.4) * scale,
		CFrame = upright(x, top + 5 * scale, z),
		Color = green,
	})
	local sides = (rng:NextInteger(0, 1) == 0) and { 1 } or { -1, 1 }
	for _, side in ipairs(sides) do
		local armHeight = rng:NextNumber(3.5, 5.5)
		makePart({
			Parent = model, Name = "ArmOut", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.6, 1.5, 1.5) * scale,
			CFrame = CFrame.new(x + side * 1.8 * scale, top + armHeight * scale, z),
			Color = green,
		})
		makePart({
			Parent = model, Name = "ArmUp", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.5, 1.5, 1.5) * scale,
			CFrame = upright(x + side * 3 * scale, top + (armHeight + 1.5) * scale, z),
			Color = green,
		})
	end
	return model
end

function Props.crystal(parent, x, z, top, scale, rng, color, material, transparency)
	return makePart({
		Parent = parent, Name = "Crystal",
		Size = Vector3.new(2, 8, 2) * scale,
		CFrame = CFrame.new(x, top + 3 * scale, z)
			* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, math.pi), rng:NextNumber(-0.35, 0.35)),
		Color = color, Material = material, Transparency = transparency,
	})
end

-- A low-poly peak: a tilted half-buried cube with a smaller "cap" cube
-- poking out of its highest corner.
function Props.mountain(parent, x, z, top, size, rng, rockColor, capColor, capMaterial)
	local model = newContainer("Model", "Mountain", parent)
	local cf = CFrame.new(x, top, z)
		* CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(35))
	makePart({
		Parent = model, Name = "Rock", Size = Vector3.new(size, size, size), CFrame = cf,
		Color = rockColor, Material = Enum.Material.Slate, CastShadow = false,
	})
	local tip = nil
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local corner = cf * Vector3.new(sx * size / 2, sy * size / 2, sz * size / 2)
				if tip == nil or corner.Y > tip.Y then
					tip = corner
				end
			end
		end
	end
	local capCenter = cf.Position + (tip - cf.Position) * 0.72
	makePart({
		Parent = model, Name = "Cap", Size = Vector3.new(size, size, size) * 0.42,
		CFrame = CFrame.new(capCenter) * cf.Rotation,
		Color = capColor, Material = capMaterial or Enum.Material.SmoothPlastic, CastShadow = false,
	})
	return model
end

function Props.volcano(parent, x, z, top, rockColor, lavaColor)
	local model = newContainer("Model", "VolcanoMountain", parent)
	local tiers = { 70, 54, 40, 28 }
	for i, diameter in ipairs(tiers) do
		makePart({
			Parent = model, Name = "Tier", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, diameter, diameter),
			CFrame = upright(x, top + 5 + (i - 1) * 10, z),
			Color = (i % 2 == 0) and rockColor:Lerp(WHITE, 0.08) or rockColor,
			Material = Enum.Material.Slate, CastShadow = false,
		})
	end
	local lava = makePart({
		Parent = model, Name = "Lava", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 22, 22),
		CFrame = upright(x, top + 40.2, z),
		Color = lavaColor, Material = Enum.Material.Neon, Decor = true,
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(90, 80, 80)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 8
	smoke.Size = 12
	smoke.Parent = lava
	return model
end

function Props.lamp(parent, x, z, top)
	local model = newContainer("Model", "Lamp", parent)
	makePart({
		Parent = model, Name = "Pole", Size = Vector3.new(0.8, 12, 0.8),
		CFrame = CFrame.new(x, top + 6, z), Color = Color3.fromRGB(60, 60, 72),
	})
	makePart({
		Parent = model, Name = "Light", Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(x, top + 12.6, z), Color = Color3.fromRGB(255, 232, 170),
		Material = Enum.Material.Neon,
	})
	return model
end

---------------------------------------------------------------------------
-- Town
---------------------------------------------------------------------------

-- A simple walk-in building with a doorway, roof, awning, and a sign.
-- Local frame: the doorway is on the front (-Z), which faces spec.Facing.
local function buildHouse(parent, spec)
	local model = newContainer("Model", spec.Name, parent)
	local w, d, h = spec.Width, spec.Depth, spec.Height
	local door = 10
	local base = facing(spec.Center, spec.Facing)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end

	makePart({ Parent = model, Name = "Floor", Size = Vector3.new(w, 0.4, d), CFrame = at(0, 0.2, 0),
		Color = Color3.fromRGB(196, 150, 104), Material = Enum.Material.WoodPlanks })
	makePart({ Parent = model, Name = "BackWall", Size = Vector3.new(w, h, 1), CFrame = at(0, h / 2, d / 2 - 0.5),
		Color = spec.WallColor })
	makePart({ Parent = model, Name = "SideWall", Size = Vector3.new(1, h, d - 2), CFrame = at(-w / 2 + 0.5, h / 2, 0),
		Color = spec.WallColor })
	makePart({ Parent = model, Name = "SideWall", Size = Vector3.new(1, h, d - 2), CFrame = at(w / 2 - 0.5, h / 2, 0),
		Color = spec.WallColor })
	local sideWidth = (w - door) / 2
	for _, side in ipairs({ -1, 1 }) do
		makePart({ Parent = model, Name = "FrontWall", Size = Vector3.new(sideWidth, h, 1),
			CFrame = at(side * (door / 2 + sideWidth / 2), h / 2, -d / 2 + 0.5), Color = spec.WallColor })
	end
	makePart({ Parent = model, Name = "DoorTop", Size = Vector3.new(door, h - 11, 1),
		CFrame = at(0, 11 + (h - 11) / 2, -d / 2 + 0.5), Color = spec.WallColor })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- 1 stud taller than the walls so its top ends inside the roof
			-- (equal-height overlapping top faces can flicker).
			makePart({ Parent = model, Name = "Pillar", Size = Vector3.new(2, h + 1, 2),
				CFrame = at(sx * w / 2, (h + 1) / 2, sz * d / 2), Color = spec.TrimColor })
		end
	end
	makePart({ Parent = model, Name = "Roof", Size = Vector3.new(w + 4, 1.5, d + 4), CFrame = at(0, h + 0.75, 0),
		Color = spec.RoofColor })

	-- Striped awning over the doorway, tilted down and outward.
	local awningWidth = door + 6
	local stripes = 6
	local stripeWidth = awningWidth / stripes
	for i = 1, stripes do
		makePart({
			Parent = model, Name = "Awning",
			Size = Vector3.new(stripeWidth, 0.4, 5),
			CFrame = at(-awningWidth / 2 + stripeWidth * (i - 0.5), 12, -d / 2 - 2.2) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = (i % 2 == 1) and spec.AwningColor or WHITE,
			Material = Enum.Material.Fabric,
		})
	end

	local sign = makePart({
		Parent = model, Name = "Sign", Size = Vector3.new(w * 0.75, 7, 1),
		CFrame = at(0, h + 1.5 + 3.5, -d / 2 + 1), Color = spec.SignColor,
	})
	addLabel(sign, spec.SignText, WHITE, OUTLINE)
	return model, base
end

local function buildThrowingLine(parent, Config)
	local model = newContainer("Model", "ThrowingLine", parent)
	local lx, cz, top = Config.ThrowLineX, Config.FieldCenterZ, Config.GroundY
	local half = 30

	makeBox({ Parent = model, Name = "Platform", Bounds = { lx - 14, lx, top, top + 0.4, cz - half, cz + half },
		Color = Color3.fromRGB(66, 132, 230) })
	-- The glowing stripe. Its front edge is exactly the throwing line (distance 0).
	makeBox({ Parent = model, Name = "ThrowLine", Bounds = { lx - 1.5, lx, top + 0.4, top + 0.55, cz - half, cz + half },
		Color = WHITE, Material = Enum.Material.Neon, Decor = true })

	-- Chevron arrows on the platform pointing toward the field (+X).
	for _, rowZ in ipairs({ -18, 0, 18 }) do
		for _, arrowX in ipairs({ lx - 11, lx - 7.5, lx - 4 }) do
			for _, side in ipairs({ -1, 1 }) do
				local tip = Vector3.new(arrowX + 1.25, top + 0.45, cz + rowZ)
				local tail = Vector3.new(arrowX - 1.25, top + 0.45, cz + rowZ + side * 2.5)
				local length = (tip - tail).Magnitude
				makePart({
					Parent = model, Name = "Arrow", Size = Vector3.new(0.9, 0.1, length + 0.9),
					CFrame = CFrame.lookAt((tip + tail) / 2, tip),
					Color = GOLD, Material = Enum.Material.Neon, Decor = true,
				})
			end
		end
	end

	-- Arch over the platform, label facing the Town.
	for _, side in ipairs({ -1, 1 }) do
		makeBox({ Parent = model, Name = "ArchPillar",
			Bounds = { lx - 8.5, lx - 5.5, top, top + 20, cz + side * (half + 2) - 1.5, cz + side * (half + 2) + 1.5 },
			Color = WHITE })
	end
	local beam = makePart({
		Parent = model, Name = "ArchBeam", Size = Vector3.new(2 * (half + 2) + 3, 5, 3),
		CFrame = facing(Vector3.new(lx - 7, top + 22.5, cz), TOWARD_TOWN),
		Color = Color3.fromRGB(40, 110, 220),
	})
	addLabel(beam, "THROWING LINE", WHITE, OUTLINE)

	-- Invisible marker for future throw code: where food is launched from and
	-- which way it flies (its LookVector points down the field).
	makePart({
		Parent = model, Name = "LaunchPoint", Size = Vector3.new(1, 1, 1),
		CFrame = facing(Vector3.new(lx - 1, top + 5, cz), TOWARD_FIELD),
		Transparency = 1, Decor = true,
	})
	model:SetAttribute("ThrowLineX", lx)
	model:SetAttribute("ThrowDirection", TOWARD_FIELD)
	return model
end

local function buildTown(parent, Config, rng)
	local town = newContainer("Model", "Town", parent)
	local groundFolder = newContainer("Folder", "Ground", town)
	local decor = newContainer("Folder", "Decor", town)

	local lx, cz, top = Config.ThrowLineX, Config.FieldCenterZ, Config.GroundY
	local halfW = Config.Field.Width / 2
	local outer = halfW + 100
	local back = lx - Config.Town.Length
	local bottom = top - Config.Field.GroundThickness
	local townGreen = { 112, 200, 98 }

	-- Positions below are offsets from the throwing line (x) and center line (z).
	local function P(x, y, z)
		return Vector3.new(lx + x, top + y, cz + z)
	end
	local function path(name, x0, x1, z0, z1)
		makeBox({ Parent = groundFolder, Name = name,
			Bounds = { lx + x0, lx + x1, top, top + 0.2, cz + z0, cz + z1 }, Color = STONE })
	end

	-- Ground
	makeBox({ Parent = groundFolder, Name = "TownGround", Bounds = { back, lx, bottom, top, cz - halfW, cz + halfW },
		Color = rgb(townGreen) })
	makeBox({ Parent = groundFolder, Name = "TownOuter", Bounds = { back, lx, bottom, top, cz + halfW, cz + outer },
		Color = shade(townGreen, 0.92) })
	makeBox({ Parent = groundFolder, Name = "TownOuter", Bounds = { back, lx, bottom, top, cz - outer, cz - halfW },
		Color = shade(townGreen, 0.92) })
	makeBox({ Parent = groundFolder, Name = "TownOuter", Bounds = { back - 120, back, bottom, top, cz - outer, cz + outer },
		Color = shade(townGreen, 0.92) })

	-- Paths (they never overlap each other, so no flickering faces)
	path("MainRoad", -170, -14, -10, 10)
	path("GymPath", -117, -107, 10, 59)
	path("MarketPath", -117, -107, -59, -10)
	path("ArenaPath", -45, -35, -52, -10)
	path("PlazaPath", -45, -35, 10, 54)

	-- Spawn point: on the main road, facing the field.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = facing(P(-150, 0.5, 0), TOWARD_FIELD)
	spawn.Color = GOLD
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0 -- no spawn force field
	spawn.Parent = town

	-- Welcome arch over the road, readable from the spawn.
	for _, side in ipairs({ -1, 1 }) do
		makeBox({ Parent = decor, Name = "WelcomePillar",
			Bounds = { lx - 139.5, lx - 136.5, top, top + 16, cz + side * 14 - 1.5, cz + side * 14 + 1.5 },
			Color = WHITE })
	end
	local welcome = makePart({
		Parent = decor, Name = "WelcomeBeam", Size = Vector3.new(31, 5, 3),
		CFrame = facing(P(-138, 18.5, 0), TOWARD_TOWN), Color = Color3.fromRGB(255, 120, 72),
	})
	addLabel(welcome, "SNACK TOSS TAMERS", WHITE, OUTLINE)

	-- Buildings (placeholders for future systems)
	local gym, gymBase = buildHouse(town, {
		Name = "Gym", Center = P(-112, 0, 74), Facing = Vector3.new(0, 0, -1),
		Width = 44, Depth = 30, Height = 16,
		WallColor = Color3.fromRGB(240, 96, 84), RoofColor = Color3.fromRGB(70, 70, 86),
		TrimColor = WHITE, AwningColor = Color3.fromRGB(60, 60, 76),
		SignColor = Color3.fromRGB(60, 60, 76), SignText = "GYM",
	})
	-- Giant dumbbell on the roof
	makePart({ Parent = gym, Name = "DumbbellStand", Size = Vector3.new(2, 2.7, 2),
		CFrame = gymBase * CFrame.new(0, 16 + 1.5 + 1.35, 4), Color = Color3.fromRGB(70, 70, 86) })
	makePart({ Parent = gym, Name = "DumbbellBar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(20, 1.6, 1.6),
		CFrame = gymBase * CFrame.new(0, 16 + 5, 4), Color = Color3.fromRGB(70, 70, 86), Material = Enum.Material.Metal })
	for _, side in ipairs({ -1, 1 }) do
		makePart({ Parent = gym, Name = "DumbbellWeight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 9, 9),
			CFrame = gymBase * CFrame.new(side * 9, 16 + 5, 4), Color = Color3.fromRGB(240, 96, 84) })
	end

	local market, marketBase = buildHouse(town, {
		Name = "FoodMarket", Center = P(-112, 0, -74), Facing = Vector3.new(0, 0, 1),
		Width = 44, Depth = 30, Height = 16,
		WallColor = Color3.fromRGB(255, 232, 170), RoofColor = Color3.fromRGB(86, 170, 90),
		TrimColor = Color3.fromRGB(86, 170, 90), AwningColor = Color3.fromRGB(230, 70, 70),
		SignColor = Color3.fromRGB(230, 70, 70), SignText = "FOOD MARKET",
	})
	-- Giant apple on the roof
	makePart({ Parent = market, Name = "GiantApple", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12),
		CFrame = marketBase * CFrame.new(0, 16 + 1.5 + 6, 4), Color = Color3.fromRGB(226, 52, 52) })
	makePart({ Parent = market, Name = "AppleStem", Size = Vector3.new(0.8, 3, 0.8),
		CFrame = marketBase * CFrame.new(0, 16 + 1.5 + 13, 4), Color = WOOD })
	makePart({ Parent = market, Name = "AppleLeaf", Size = Vector3.new(3, 0.4, 1.6),
		CFrame = marketBase * CFrame.new(1.6, 16 + 1.5 + 13.5, 4) * CFrame.Angles(0, 0, math.rad(20)),
		Color = Color3.fromRGB(86, 170, 90) })
	for _, side in ipairs({ -1, 1 }) do
		makePart({ Parent = market, Name = "Crate", Size = Vector3.new(4, 4, 4),
			CFrame = marketBase * CFrame.new(side * 10, 2, -15 - 4), Color = Color3.fromRGB(196, 150, 104),
			Material = Enum.Material.WoodPlanks })
	end

	-- Arena: an open octagon with the entrance facing the road.
	local arena = newContainer("Model", "Arena", town)
	local arenaBase = facing(P(-40, 0, -76), Vector3.new(0, 0, 1))
	local radius = 24
	makePart({ Parent = arena, Name = "Floor", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2 + 2, radius * 2 + 2),
		CFrame = arenaBase * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(240, 210, 150), Material = Enum.Material.Sand })
	for i = 1, 7 do -- segment 0 is left open as the entrance
		local segment = arenaBase * CFrame.Angles(0, i * math.pi / 4, 0)
		makePart({ Parent = arena, Name = "Wall", Size = Vector3.new(20.5, 8, 2),
			CFrame = segment * CFrame.new(0, 4, -radius),
			Color = (i % 2 == 0) and Color3.fromRGB(150, 90, 220) or Color3.fromRGB(120, 70, 190) })
	end
	local flagColors = { Color3.fromRGB(255, 92, 92), GOLD, Color3.fromRGB(84, 170, 236), Color3.fromRGB(110, 210, 110) }
	for k, i in ipairs({ 1, 3, 5, 7 }) do
		local corner = arenaBase * CFrame.Angles(0, i * math.pi / 4 + math.pi / 8, 0) * CFrame.new(0, 0, -(radius + 1))
		makePart({ Parent = arena, Name = "FlagPole", Size = Vector3.new(0.6, 20, 0.6),
			CFrame = corner * CFrame.new(0, 10, 0), Color = WHITE })
		makePart({ Parent = arena, Name = "Flag", Size = Vector3.new(0.3, 4, 6),
			CFrame = corner * CFrame.new(0, 18, 3), Color = flagColors[k], Material = Enum.Material.Fabric })
	end
	for _, side in ipairs({ -1, 1 }) do
		makePart({ Parent = arena, Name = "GatePillar", Size = Vector3.new(3, 14, 3),
			CFrame = arenaBase * CFrame.new(side * 8, 7, -(radius + 1)), Color = Color3.fromRGB(120, 70, 190) })
	end
	local gate = makePart({ Parent = arena, Name = "GateSign", Size = Vector3.new(20, 5, 2),
		CFrame = arenaBase * CFrame.new(0, 16, -(radius + 1)), Color = Color3.fromRGB(150, 90, 220) })
	addLabel(gate, "ARENA - SOON", WHITE, OUTLINE)

	-- Pet Plaza: future creature/inventory area (GAME_DESIGN.md section 3).
	local plaza = newContainer("Model", "PetPlaza", town)
	makeBox({ Parent = plaza, Name = "Pavement", Bounds = { lx - 60, lx - 20, top, top + 0.2, cz + 54, cz + 90 },
		Color = STONE })
	local fx, fz = lx - 40, cz + 74
	makePart({ Parent = plaza, Name = "Basin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 22, 22),
		CFrame = upright(fx, top + 1.2, fz), Color = Color3.fromRGB(200, 200, 210) })
	makePart({ Parent = plaza, Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 19, 19),
		CFrame = upright(fx, top + 2.3, fz), Color = Color3.fromRGB(90, 180, 255), Transparency = 0.2, Decor = true })
	makePart({ Parent = plaza, Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 3, 3),
		CFrame = upright(fx, top + 3.5, fz), Color = Color3.fromRGB(200, 200, 210) })
	makePart({ Parent = plaza, Name = "TopBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 8, 8),
		CFrame = upright(fx, top + 7.5, fz), Color = Color3.fromRGB(90, 180, 255), Material = Enum.Material.Neon })
	makeSign({ Parent = plaza, Name = "PlazaSign", Position = P(-40, 0, 52), Facing = Vector3.new(0, 0, -1),
		BoardSize = Vector3.new(16, 5, 1), PostHeight = 8, BoardColor = Color3.fromRGB(84, 170, 236),
		Text = "PET PLAZA", TextColor = WHITE, StrokeColor = OUTLINE })

	-- Lamps along the road
	for _, x in ipairs({ -160, -125, -85, -60, -25 }) do
		for _, side in ipairs({ -1, 1 }) do
			Props.lamp(decor, lx + x, cz + side * 13, top)
		end
	end

	-- Hedges around the Town (the field side stays open)
	local hedge = Color3.fromRGB(64, 150, 70)
	makeBox({ Parent = decor, Name = "Hedge", Bounds = { back, back + 4, top, top + 6, cz - halfW, cz + halfW }, Color = hedge })
	for _, side in ipairs({ -1, 1 }) do
		local z0 = (side > 0) and (cz + halfW - 4) or (cz - halfW)
		makeBox({ Parent = decor, Name = "Hedge", Bounds = { back, lx, top, top + 4, z0, z0 + 4 }, Color = hedge })
	end

	-- Trees around the edges of Town
	local leaf = Color3.fromRGB(80, 176, 80)
	for z = -100, 100, 25 do
		Props.tree(decor, back + 10, cz + z, top, rng:NextNumber(1.0, 1.3), rng:NextNumber(0, math.pi), leaf)
	end
	for x = -165, -20, 29 do
		for _, side in ipairs({ -1, 1 }) do
			Props.tree(decor, lx + x, cz + side * 108, top, rng:NextNumber(0.9, 1.2), rng:NextNumber(0, math.pi), leaf)
		end
	end

	buildThrowingLine(town, Config)
	return town
end

---------------------------------------------------------------------------
-- Field and zones
---------------------------------------------------------------------------

-- Decoration recipes per zone Id. ctx fields:
--   Parent, Rng, Zone, X0, X1, Top, CZ, Band = {inner, outer}, Outer = {inner, outer}
-- Band: beside the landing lane, inside the walls. Outer: scenery beyond the walls.
local function bandPoint(ctx, band)
	band = band or ctx.Band
	local rng = ctx.Rng
	local x = rng:NextNumber(ctx.X0 + 4, ctx.X1 - 4)
	local side = (rng:NextInteger(0, 1) == 0) and -1 or 1
	return x, ctx.CZ + side * rng:NextNumber(band[1], band[2])
end

local Decorators = {}

function Decorators.Meadow(ctx)
	local rng = ctx.Rng
	local petals = { { 255, 92, 120 }, { 255, 214, 72 }, { 255, 255, 255 }, { 176, 120, 255 }, { 255, 150, 60 } }
	for _ = 1, 30 do
		local x, z = bandPoint(ctx)
		Props.flower(ctx.Parent, x, z, ctx.Top, rgb(petals[rng:NextInteger(1, #petals)]))
	end
	for _ = 1, 8 do
		local x, z = bandPoint(ctx)
		Props.bush(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.8, 1.3), Color3.fromRGB(70, 170, 70))
	end
	for _ = 1, 3 do
		local x, z = bandPoint(ctx, { 140, 190 })
		Props.mound(ctx.Parent, "Hill", x, z, ctx.Top, rng:NextNumber(60, 90), shade(ctx.Zone.GroundColor, 0.95))
	end
end

function Decorators.Forest(ctx)
	local rng = ctx.Rng
	local leaves = { Color3.fromRGB(46, 130, 60), Color3.fromRGB(60, 150, 64), Color3.fromRGB(34, 112, 56) }
	for _ = 1, 22 do
		local x, z = bandPoint(ctx)
		Props.tree(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.9, 1.4), rng:NextNumber(0, math.pi),
			leaves[rng:NextInteger(1, #leaves)])
	end
	for _ = 1, 14 do
		local x, z = bandPoint(ctx, ctx.Outer)
		Props.tree(ctx.Parent, x, z, ctx.Top, rng:NextNumber(1.3, 1.9), rng:NextNumber(0, math.pi),
			leaves[rng:NextInteger(1, #leaves)])
	end
	for _ = 1, 10 do
		local x, z = bandPoint(ctx)
		local cap = (rng:NextInteger(0, 1) == 0) and Color3.fromRGB(226, 60, 60) or Color3.fromRGB(240, 150, 60)
		Props.mushroom(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.8, 1.4), cap)
	end
end

function Decorators.Desert(ctx)
	local rng = ctx.Rng
	for _ = 1, 14 do
		local x, z = bandPoint(ctx)
		Props.cactus(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.8, 1.3), rng)
	end
	for _ = 1, 10 do
		local x, z = bandPoint(ctx)
		Props.rock(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.8, 1.6), rng, Color3.fromRGB(214, 160, 100),
			Enum.Material.Sandstone)
	end
	for _ = 1, 5 do
		local x, z = bandPoint(ctx, { 140, 190 })
		Props.mound(ctx.Parent, "Dune", x, z, ctx.Top, rng:NextNumber(60, 90), shade(ctx.Zone.GroundColor, 0.96),
			Enum.Material.Sand)
	end
end

function Decorators.SnowPeaks(ctx)
	local rng = ctx.Rng
	local count = 7
	for i = 1, count do
		local x = ctx.X0 + (ctx.X1 - ctx.X0) * (i - 0.5) / count
		local side = (i % 2 == 0) and -1 or 1
		Props.mountain(ctx.Parent, x, ctx.CZ + side * rng:NextNumber(180, 200), ctx.Top, rng:NextNumber(70, 95), rng,
			Color3.fromRGB(150, 170, 196), WHITE, Enum.Material.Snow)
	end
	for _ = 1, 18 do
		local x, z = bandPoint(ctx)
		Props.pine(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.9, 1.4), rng:NextNumber(0, math.pi),
			Color3.fromRGB(40, 120, 90), true)
	end
	for _ = 1, 10 do
		local x, z = bandPoint(ctx)
		Props.crystal(ctx.Parent, x, z, ctx.Top, rng:NextNumber(0.8, 1.5), rng, Color3.fromRGB(170, 220, 255),
			Enum.Material.Ice, 0.15)
	end
end

function Decorators.Volcano(ctx)
	local rng = ctx.Rng
	local rockColor = Color3.fromRGB(58, 48, 52)
	local lavaColor = Color3.fromRGB(255, 104, 32)
	Props.volcano(ctx.Parent, ctx.X0 + 130, ctx.CZ - 165, ctx.Top, rockColor, lavaColor)
	Props.volcano(ctx.Parent, ctx.X0 + 290, ctx.CZ + 165, ctx.Top, rockColor, lavaColor)
	for _ = 1, 16 do
		local x, z = bandPoint(ctx)
		Props.rock(ctx.Parent, x, z, ctx.Top, rng:NextNumber(1, 2), rng, rockColor, Enum.Material.Slate)
	end
	for _ = 1, 10 do
		local x, z = bandPoint(ctx)
		makePart({
			Parent = ctx.Parent, Name = "LavaPool",
			Size = Vector3.new(rng:NextNumber(10, 22), 0.2, rng:NextNumber(8, 16)),
			CFrame = CFrame.new(x, ctx.Top + 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = lavaColor, Material = Enum.Material.Neon, Decor = true,
		})
	end
end

function Decorators.DragonsNest(ctx, Config)
	local rng = ctx.Rng
	local crystalColors = { Color3.fromRGB(196, 112, 255), Color3.fromRGB(255, 110, 200), Color3.fromRGB(90, 220, 230) }
	for _ = 1, 16 do
		local x, z = bandPoint(ctx)
		Props.crystal(ctx.Parent, x, z, ctx.Top, rng:NextNumber(1, 2.2), rng, crystalColors[rng:NextInteger(1, 3)],
			Enum.Material.Neon)
	end

	-- The giant nest sits beyond MaxLandingDistance so it never blocks a landing.
	local nest = newContainer("Model", "GiantNest", ctx.Parent)
	local nx = Config.ThrowLineX + Config.Field.MaxLandingDistance + 50
	local nz = ctx.CZ
	local nestRadius = 30
	makePart({ Parent = nest, Name = "NestFloor", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, nestRadius * 2, nestRadius * 2), CFrame = upright(nx, ctx.Top + 1, nz),
		Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood })
	for ring = 1, 2 do
		local count = 16
		local r = nestRadius - (ring - 1) * 1.5
		for i = 1, count do
			local angle = (i + ring * 0.5) * (2 * math.pi / count)
			local pos = Vector3.new(nx + r * math.cos(angle), ctx.Top + 1.5 + ring * 2.5, nz + r * math.sin(angle))
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			makePart({ Parent = nest, Name = "Branch",
				Size = Vector3.new(2.6, 2.6, 2 * math.pi * r / count * 1.35),
				CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, rng:NextNumber(-0.3, 0.3)),
				Color = (i % 2 == 0) and Color3.fromRGB(122, 84, 52) or Color3.fromRGB(100, 68, 44),
				Material = Enum.Material.Wood })
		end
	end
	local eggs = { { -5, -4, 7, Color3.fromRGB(255, 200, 60) }, { 5, -2, 6, Color3.fromRGB(196, 112, 255) },
		{ 0, 6, 6.5, Color3.fromRGB(90, 220, 230) } }
	for _, egg in ipairs(eggs) do
		makePart({ Parent = nest, Name = "DragonEgg", Shape = Enum.PartType.Ball,
			Size = Vector3.new(egg[3], egg[3], egg[3]),
			CFrame = CFrame.new(nx + egg[1], ctx.Top + 2 + egg[3] / 2 - 0.5, nz + egg[2]),
			Color = egg[4] })
	end

	-- Cliffs behind the end of the field
	local endX = Config.ThrowLineX + Config.Field.Length
	for i = -3, 3 do
		local height = rng:NextNumber(90, 160)
		makePart({ Parent = ctx.Parent, Name = "Cliff",
			Size = Vector3.new(rng:NextNumber(50, 70), height, rng:NextNumber(60, 75)),
			CFrame = CFrame.new(endX + 30 + rng:NextNumber(0, 25), ctx.Top + height / 2 - 10, ctx.CZ + i * 62)
				* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.08, 0.08)),
			Color = Color3.fromRGB(64, 48, 92), Material = Enum.Material.Slate, CastShadow = false })
	end

	-- Floating rocks with crystals, outside the walls
	for _ = 1, 4 do
		local x, z = bandPoint(ctx, { 150, 200 })
		local y = ctx.Top + rng:NextNumber(70, 110)
		local size = rng:NextNumber(18, 28)
		makePart({ Parent = ctx.Parent, Name = "FloatingRock", Size = Vector3.new(size, size * 0.6, size),
			CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = Color3.fromRGB(80, 60, 112), Material = Enum.Material.Slate, CastShadow = false })
		Props.crystal(ctx.Parent, x, z, y + size * 0.3, 1.8, rng, crystalColors[rng:NextInteger(1, 3)], Enum.Material.Neon)
	end
end

local function buildField(parent, boundaries, Config, rng)
	local field = newContainer("Model", "Field", parent)
	local landing = newContainer("Folder", "LandingSurfaces", field)
	local markings = newContainer("Folder", "Markings", field)
	local markersFolder = newContainer("Folder", "DistanceMarkers", field)
	local signsFolder = newContainer("Folder", "ZoneSigns", field)
	local decorFolder = newContainer("Folder", "ZoneDecor", field)
	local scenery = newContainer("Folder", "Scenery", field)

	local F = Config.Field
	local lx, cz, top = Config.ThrowLineX, Config.FieldCenterZ, Config.GroundY
	local bottom = top - F.GroundThickness
	local halfW = F.Width / 2
	local lane = F.LaneHalfWidth
	local outer = halfW + 100
	local endX = lx + F.Length

	for _, zone in ipairs(Config.Zones) do
		local x0 = lx + zone.MinDistance
		local x1 = lx + Config.getZoneEndDistance(zone)
		local material = Enum.Material[zone.GroundMaterial]

		-- Landing ground: shoulder | lane | shoulder. All tagged as landing surfaces.
		local strips = {
			{ "LeftShoulder", -halfW, -lane, zone.GroundColor },
			{ "Lane", -lane, lane, zone.LaneColor },
			{ "RightShoulder", lane, halfW, zone.GroundColor },
		}
		for _, strip in ipairs(strips) do
			local parts = makeBoxes({ Parent = landing, Name = zone.Id .. "_" .. strip[1],
				Bounds = { x0, x1, bottom, top, cz + strip[2], cz + strip[3] },
				Color = rgb(strip[4]), Material = material })
			for _, part in ipairs(parts) do
				part:SetAttribute("ZoneId", zone.Id)
				CollectionService:AddTag(part, WorldBuilder.LandingTag)
			end
		end

		-- Scenery ground beyond the walls (not a landing surface)
		for _, side in ipairs({ -1, 1 }) do
			local z0 = (side > 0) and (cz + halfW) or (cz - outer)
			makeBoxes({ Parent = scenery, Name = zone.Id .. "_Outer", Bounds = { x0, x1, bottom, top, z0, z0 + 100 },
				Color = shade(zone.GroundColor, 0.92), Material = material })
			-- Low fence along the field edge, in the zone's accent color
			local f0 = (side > 0) and (cz + halfW - 2) or (cz - halfW)
			makeBoxes({ Parent = boundaries, Name = zone.Id .. "_Fence", Bounds = { x0, x1, top, top + 3, f0, f0 + 2 },
				Color = rgb(zone.AccentColor) })
		end

		-- Glowing boundary line where this zone starts (not at the throwing line)
		if zone.MinDistance > 0 then
			makeBox({ Parent = markings, Name = "BoundaryLine_" .. zone.Id,
				Bounds = { x0 - 0.5, x0 + 0.5, top, top + 0.12, cz - halfW, cz + halfW },
				Color = rgb(zone.AccentColor), Material = Enum.Material.Neon, Decor = true })
		end

		-- Zone name signs on both sides of the lane, facing the Town
		local rangeText
		if zone.MaxDistance == math.huge then
			rangeText = tostring(zone.MinDistance) .. "+ studs"
		else
			rangeText = tostring(zone.MinDistance) .. " - " .. tostring(zone.MaxDistance) .. " studs"
		end
		for _, side in ipairs({ -1, 1 }) do
			local sign = makeSign({ Parent = signsFolder, Name = zone.Id .. "Sign",
				Position = Vector3.new(x0 + 8, top, cz + side * (lane + 22)), Facing = TOWARD_TOWN,
				BoardSize = Vector3.new(24, 10, 1), PostHeight = 10, BoardColor = rgb(zone.AccentColor),
				Text = string.upper(zone.DisplayName) .. "\n" .. rangeText, TextColor = WHITE, StrokeColor = OUTLINE })
			sign:SetAttribute("ZoneId", zone.Id)
		end

		local decorator = Decorators[zone.Id]
		if decorator then
			local zoneDecor = newContainer("Model", zone.Id, decorFolder)
			decorator({
				Parent = zoneDecor, Rng = rng, Zone = zone, X0 = x0, X1 = x1, Top = top, CZ = cz,
				Band = { lane + 40, halfW - 8 },
				Outer = { halfW + 12, outer - 20 },
			}, Config)
		end
	end

	-- End-of-field scenery ground under the cliffs
	local lastZone = Config.Zones[#Config.Zones]
	makeBox({ Parent = scenery, Name = "EndGround", Bounds = { endX, endX + 160, bottom, top, cz - outer, cz + outer },
		Color = shade(lastZone.GroundColor, 0.9), Material = Enum.Material[lastZone.GroundMaterial] })

	-- White lines along both edges of the landing lane
	for _, side in ipairs({ -1, 1 }) do
		makeBoxes({ Parent = markings, Name = "LaneEdge",
			Bounds = { lx, endX, top, top + 0.08, cz + side * lane - 0.3, cz + side * lane + 0.3 },
			Color = WHITE, Transparency = 0.3, Decor = true })
	end

	-- Distance markers every DistanceMarkerInterval studs
	local isBoundary = {}
	for _, zone in ipairs(Config.Zones) do
		isBoundary[zone.MinDistance] = true
	end
	for _, d in ipairs(Config.getMarkerDistances()) do
		local x = lx + d
		local major = (d % 100 == 0)
		local marker = newContainer("Model", "Marker_" .. tostring(d), markersFolder)
		marker:SetAttribute("Distance", d)
		-- Zone boundaries already have a glowing line, so skip the plain one there.
		if not isBoundary[d] then
			makeBox({ Parent = marker, Name = "Line", Bounds = { x - 0.3, x + 0.3, top, top + 0.1, cz - lane, cz + lane },
				Color = WHITE, Decor = true })
		end
		for _, side in ipairs({ -1, 1 }) do
			makeSign({ Parent = marker, Name = (side < 0) and "LeftSign" or "RightSign",
				-- lane + 7 keeps even the widest board (11 studs) outside the lane
				Position = Vector3.new(x, top, cz + side * (lane + 7)), Facing = TOWARD_TOWN,
				BoardSize = major and Vector3.new(11, 5.5, 0.6) or Vector3.new(8, 4, 0.6),
				PostHeight = major and 8 or 5, SinglePost = true,
				BoardColor = major and GOLD or WHITE, PostColor = WHITE,
				Text = tostring(d), TextColor = DARK_TEXT, MaxDistance = 800 })
		end
	end

	return field
end

local function buildBoundaries(boundaries, Config)
	local F = Config.Field
	local lx, cz, top = Config.ThrowLineX, Config.FieldCenterZ, Config.GroundY
	local halfW = F.Width / 2
	local back = lx - Config.Town.Length
	local endX = lx + F.Length
	local height = 80
	local function wall(name, bounds)
		makeBoxes({ Parent = boundaries, Name = name, Bounds = bounds, Transparency = 1, CastShadow = false })
	end
	wall("InvisibleWall_Left", { back - 2, endX + 2, top, top + height, cz - halfW - 2, cz - halfW })
	wall("InvisibleWall_Right", { back - 2, endX + 2, top, top + height, cz + halfW, cz + halfW + 2 })
	wall("InvisibleWall_Back", { back - 2, back, top, top + height, cz - halfW - 2, cz + halfW + 2 })
	wall("InvisibleWall_End", { endX, endX + 2, top, top + height, cz - halfW - 2, cz + halfW + 2 })
end

---------------------------------------------------------------------------
-- Checks shared by Build and Validate
---------------------------------------------------------------------------

local function findTemplateLeftovers(world)
	local issues = {}
	if Workspace:FindFirstChild("Baseplate") then
		issues[#issues + 1] = "Workspace.Baseplate (from the Baseplate template) overlaps the map at ground level. Delete it."
	end
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance:IsA("SpawnLocation") and not instance:IsDescendantOf(world) then
			issues[#issues + 1] = instance:GetFullName()
				.. " is an extra SpawnLocation. Delete it so players always spawn in Town."
		end
	end
	return issues
end

local function countParts(root)
	local count = 0
	for _, instance in ipairs(root:GetDescendants()) do
		if instance:IsA("BasePart") then
			count = count + 1
		end
	end
	return count
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function WorldBuilder.Build()
	local Config = loadWorldConfig()
	local rng = Random.new(RANDOM_SEED)

	local existing = Workspace:FindFirstChild(WorldBuilder.WorldName)
	if existing then
		existing:Destroy()
	end

	-- Build the whole tree unparented, then parent it once (faster, one update).
	local world = Instance.new("Model")
	world.Name = WorldBuilder.WorldName
	-- Small world (well under a few thousand parts): always send all of it to
	-- every player so far zones stay visible from the Throwing Line.
	world.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	world:SetAttribute("GeneratedBy", "ServerStorage.Tools.WorldBuilder")
	world:SetAttribute("Seed", RANDOM_SEED)

	local boundaries = newContainer("Folder", "Boundaries", world)
	local town = buildTown(world, Config, rng)
	local field = buildField(world, boundaries, Config, rng)
	buildBoundaries(boundaries, Config)

	world.Parent = Workspace

	print(string.format("[WorldBuilder] Built Workspace.%s: %d parts (Town %d, Field %d, Boundaries %d)",
		WorldBuilder.WorldName, countParts(world), countParts(town), countParts(field), countParts(boundaries)))
	for _, issue in ipairs(findTemplateLeftovers(world)) do
		warn("[WorldBuilder] ACTION NEEDED: " .. issue)
	end
	print("[WorldBuilder] Remember to save the place (File > Save to File, or Ctrl+S).")
	return WorldBuilder.Validate()
end

function WorldBuilder.Validate()
	local Config = loadWorldConfig()
	local F = Config.Field
	local lx, cz, top = Config.ThrowLineX, Config.FieldCenterZ, Config.GroundY
	local passed, failed = 0, 0

	local function report(ok, name, detail)
		if ok then
			passed = passed + 1
			print("[Validate] PASS  " .. name)
		else
			failed = failed + 1
			warn("[Validate] FAIL  " .. name .. (detail and (": " .. detail) or ""))
		end
	end

	local world = Workspace:FindFirstChild(WorldBuilder.WorldName)
	report(world ~= nil, "Workspace." .. WorldBuilder.WorldName .. " exists")
	if not world then
		return false
	end

	local configOk, configProblems = Config.validate()
	report(configOk, "WorldConfig is consistent", configOk and nil or table.concat(configProblems, "; "))

	local town = world:FindFirstChild("Town")
	local field = world:FindFirstChild("Field")
	local landing = field and field:FindFirstChild("LandingSurfaces")
	report(town ~= nil and field ~= nil and landing ~= nil, "Town, Field and LandingSurfaces exist")
	if not (town and field and landing) then
		return false
	end

	-- 1. Landing surface: cast rays straight down across the whole field.
	-- Samples sit between whole studs (1.25, 3.75, ...) so none lands exactly
	-- on a zone boundary.
	local onlyLanding = RaycastParams.new()
	onlyLanding.FilterType = Enum.RaycastFilterType.Include
	onlyLanding.FilterDescendantsInstances = { landing }
	local everything = RaycastParams.new()

	local halfW = F.Width / 2
	local lane = F.LaneHalfWidth
	local sampleZs = { -(lane + halfW) / 2, -lane * 0.9, 0, lane * 0.9, (lane + halfW) / 2 }
	local down = Vector3.new(0, -400, 0)
	local samples, gaps, wrongHeight, wrongZone, blocked = 0, {}, {}, {}, {}
	local distance = 1.25
	while distance < F.Length do
		local expectedZone = Config.getZoneAtDistance(distance)
		for _, z in ipairs(sampleZs) do
			samples = samples + 1
			local origin = Vector3.new(lx + distance, top + 200, cz + z)
			local hit = Workspace:Raycast(origin, down, onlyLanding)
			if not hit then
				gaps[#gaps + 1] = string.format("(%.2f, %.1f)", distance, z)
			else
				if math.abs(hit.Position.Y - top) > 0.01 then
					wrongHeight[#wrongHeight + 1] = string.format("%.2f studs: Y=%.3f", distance, hit.Position.Y)
				end
				if hit.Instance:GetAttribute("ZoneId") ~= expectedZone.Id then
					wrongZone[#wrongZone + 1] = string.format("%.2f studs: %s (expected %s)", distance,
						tostring(hit.Instance:GetAttribute("ZoneId")), expectedZone.Id)
				end
			end
			-- Inside the landing lane nothing else may intercept a landing ray.
			if math.abs(z) < lane and distance < F.MaxLandingDistance then
				local first = Workspace:Raycast(origin, down, everything)
				if not first or not first.Instance:IsDescendantOf(landing) then
					blocked[#blocked + 1] = string.format("%.2f studs: %s", distance,
						first and first.Instance:GetFullName() or "nothing")
				end
			end
		end
		distance = distance + 2.5
	end
	local function firstFew(list)
		local shown = {}
		for i = 1, math.min(3, #list) do
			shown[i] = list[i]
		end
		return string.format("%d problem(s), e.g. %s", #list, table.concat(shown, ", "))
	end
	report(#gaps == 0, string.format("no gaps in landing ground (%d rays)", samples), (#gaps > 0) and firstFew(gaps) or nil)
	report(#wrongHeight == 0, "landing ground is flat at Y = " .. tostring(top),
		(#wrongHeight > 0) and firstFew(wrongHeight) or nil)
	report(#wrongZone == 0, "every landing point matches WorldConfig zone boundaries",
		(#wrongZone > 0) and firstFew(wrongZone) or nil)
	report(#blocked == 0, "landing lane is clear of obstacles up to MaxLandingDistance",
		(#blocked > 0) and firstFew(blocked) or nil)

	-- 2. Every zone has landing ground.
	local zonesWithGround = {}
	for _, part in ipairs(landing:GetChildren()) do
		if part:IsA("BasePart") and CollectionService:HasTag(part, WorldBuilder.LandingTag) then
			zonesWithGround[part:GetAttribute("ZoneId")] = true
		end
	end
	local missingZones = {}
	for _, zone in ipairs(Config.Zones) do
		if not zonesWithGround[zone.Id] then
			missingZones[#missingZones + 1] = zone.Id
		end
	end
	report(#missingZones == 0, "all " .. #Config.Zones .. " zones have tagged landing ground",
		table.concat(missingZones, ", "))

	-- 3. Zone boundary lines and signs.
	local markings = field:FindFirstChild("Markings")
	local signs = field:FindFirstChild("ZoneSigns")
	local boundaryProblems = {}
	for _, zone in ipairs(Config.Zones) do
		if zone.MinDistance > 0 then
			local line = markings and markings:FindFirstChild("BoundaryLine_" .. zone.Id)
			if not line then
				boundaryProblems[#boundaryProblems + 1] = zone.Id .. " line missing"
			elseif math.abs(line.Position.X - (lx + zone.MinDistance)) > 0.001 then
				boundaryProblems[#boundaryProblems + 1] = zone.Id .. string.format(" line at %.3f", line.Position.X)
			end
		end
		if not (signs and signs:FindFirstChild(zone.Id .. "Sign")) then
			boundaryProblems[#boundaryProblems + 1] = zone.Id .. " sign missing"
		end
	end
	report(#boundaryProblems == 0, "zone boundary lines and signs match WorldConfig", table.concat(boundaryProblems, "; "))

	-- 4. Distance markers.
	local markersFolder = field:FindFirstChild("DistanceMarkers")
	local expected = Config.getMarkerDistances()
	local markerProblems = {}
	for _, d in ipairs(expected) do
		local marker = markersFolder and markersFolder:FindFirstChild("Marker_" .. tostring(d))
		if not marker then
			markerProblems[#markerProblems + 1] = tostring(d) .. " missing"
		else
			for _, child in ipairs(marker:GetDescendants()) do
				if child:IsA("BasePart") and (child.Name == "Line" or child.Name == "Board")
					and math.abs(child.Position.X - (lx + d)) > 0.001 then
					markerProblems[#markerProblems + 1] = string.format("%d %s at X=%.3f", d, child.Name, child.Position.X)
				end
			end
		end
	end
	local markerCount = markersFolder and #markersFolder:GetChildren() or 0
	if markerCount ~= #expected then
		markerProblems[#markerProblems + 1] = string.format("%d markers found, %d expected", markerCount, #expected)
	end
	report(#markerProblems == 0, string.format("%d distance markers at exact distances", #expected),
		table.concat(markerProblems, "; "))

	-- 5. Spawn.
	local spawns = {}
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance:IsA("SpawnLocation") and instance.Enabled then
			spawns[#spawns + 1] = instance
		end
	end
	local townSpawn = town:FindFirstChild("TownSpawn")
	report(#spawns == 1 and spawns[1] == townSpawn, "exactly one enabled SpawnLocation, the Town spawn",
		string.format("%d enabled SpawnLocation(s) found", #spawns))
	if townSpawn then
		local x = townSpawn.Position.X
		report(x < lx and x > lx - Config.Town.Length, "spawn is inside the Town (behind the throwing line)",
			string.format("spawn X = %.1f", x))
	end

	-- 6. Throwing line position and direction.
	local throwingLine = town:FindFirstChild("ThrowingLine")
	local stripe = throwingLine and throwingLine:FindFirstChild("ThrowLine")
	local launch = throwingLine and throwingLine:FindFirstChild("LaunchPoint")
	report(stripe ~= nil and math.abs(stripe.Position.X + stripe.Size.X / 2 - lx) < 0.001,
		"throwing line front edge is at X = " .. tostring(lx))
	report(launch ~= nil and launch.CFrame.LookVector:Dot(Vector3.new(1, 0, 0)) > 0.999,
		"LaunchPoint faces down the field (+X)")

	-- 7. Every part is anchored; no template leftovers.
	local loose = 0
	for _, instance in ipairs(world:GetDescendants()) do
		if instance:IsA("BasePart") and not instance.Anchored then
			loose = loose + 1
		end
	end
	report(loose == 0, "all parts are anchored", tostring(loose) .. " unanchored part(s)")
	local leftovers = findTemplateLeftovers(world)
	report(#leftovers == 0, "no Baseplate-template leftovers in Workspace", table.concat(leftovers, " | "))

	local total = passed + failed
	if failed == 0 then
		print(string.format("[Validate] ALL %d CHECKS PASSED (%d parts in %s)", total, countParts(world),
			WorldBuilder.WorldName))
	else
		warn(string.format("[Validate] %d of %d checks FAILED - see the lines above", failed, total))
	end
	return failed == 0
end

-- Optional: a bright, clear simulator look. Changes Studio-owned Lighting.
function WorldBuilder.ApplyLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	-- Light haze for depth, but thin enough to see Dragon's Nest from the line.
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(198, 222, 255)
	atmosphere.Decay = Color3.fromRGB(120, 140, 170)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.8
	print("[WorldBuilder] Lighting applied. Save the place to keep it.")
end

return WorldBuilder
