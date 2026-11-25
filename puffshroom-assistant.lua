-- Atlas+ Puffshroom Assistant
-- Standalone Bee Swarm Simulator utility using the Atlas+ GUI.

if _G.puffshroomAssistantLoading then
	return
end
_G.puffshroomAssistantLoading = true

local isTestHarness = _G.__PUFF_ASSISTANT_TEST__ == true

if not isTestHarness and (not getthreadidentity or getthreadidentity() < 8) then
	local starterGui = cloneref and cloneref(game:GetService("StarterGui")) or game:GetService("StarterGui")
	pcall(function()
		starterGui:SetCore("SendNotification", {
			Title = "Warning",
			Text = "Your executor is not supported.",
			Duration = 10,
		})
	end)
	_G.puffshroomAssistantLoading = nil
	return
end

local function getService(serviceName)
	local service = game:GetService(serviceName)
	return cloneref and cloneref(service) or service
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")
local RunService = getService("RunService")
local TweenService = getService("TweenService")
local UserInputService = getService("UserInputService")
local HttpService = getService("HttpService")
local StarterGui = getService("StarterGui")
local TextService = getService("TextService")
local Lighting = getService("Lighting")

if not isTestHarness and game.PlaceId ~= 1537690962 then
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Warning",
			Text = "You're not in Bee Swarm Simulator.",
			Duration = 5,
		})
	end)
	_G.puffshroomAssistantLoading = nil
	return
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

if not isTestHarness and localPlayer then
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 10)
	if playerGui then
		local lsg = playerGui:FindFirstChild("LoadingScreenGui")
		while lsg and lsg.Parent and lsg:FindFirstChild("LoadingMessage") and lsg.LoadingMessage.Visible do
			RunService.Heartbeat:Wait()
		end
	end
end

if _G.puffshroomAssistant and type(_G.puffshroomAssistant.Destroy) == "function" then
	pcall(_G.puffshroomAssistant.Destroy)
end

local CONFIG_DIR = "puffshroom-assistant"
local CONFIG_PATH = "puffshroom-assistant/config.json"

local defaultCfg = {
	movement = {
		walkspeedenabled = false,
		walkdynamic = false,
		walkspeed = 90,
		walkspeed2 = 1.5,
	},
	tokens = {
		hideHoney = false,
		hideSoftWax = false,
		hideBitterberry = false,
		hideTreat = false,
		hideRoyalJelly = false,
	},
	highlights = {
		turpentine = true,
		causticWax = true,
		swirledWax = true,
		beam = true,
		label = true,
		notify = true,
	},
	puffshrooms = {
		transparencyEnabled = true,
		commonTransparency = 0,
		rareTransparency = 0,
		epicTransparency = 0,
		fadeGui = false,
	},
	monitor = {
		enabled = true,
		notifyOnMythic = true,
	},
	decorations = {
		hide = false,
	},
	perf = {
		lowGraphics = false,
		hideBees = false,
		filterParticles = false,
		keepSporeTrails = true,
		hidePlayers = false,
		hideFlowers = false,
		hideBalloons = false,
	},
	flames = {
		enabled = false,
		shiftLockCompat = true,
		refreshPriority = true,
		onlyRefreshReady = false,
		smartAutoDig = false,
		refreshAge = 3.0,
		maxRange = 30,
	},
	misc = {
		mobiletoggle = false,
	},
}

local function deepCopy(source)
	local copy = {}
	for k, v in pairs(source) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function mergeConfig(target, source)
	if type(source) ~= "table" then
		return
	end
	for k, v in pairs(target) do
		if type(v) == "table" and type(source[k]) == "table" then
			mergeConfig(v, source[k])
		elseif type(v) ~= "table" and type(source[k]) == type(v) then
			target[k] = source[k]
		end
	end
end

local cfg = deepCopy(defaultCfg)

local function loadConfig()
	if isfolder and isfile and readfile then
		pcall(function()
			if isfile(CONFIG_PATH) then
				local decoded = HttpService:JSONDecode(readfile(CONFIG_PATH))
				mergeConfig(cfg, decoded)
			end
		end)
	end
	cfg.movement.walkspeed = math.clamp(cfg.movement.walkspeed, 30, 90)
	cfg.movement.walkspeed2 = math.clamp(math.round(cfg.movement.walkspeed2 * 10) / 10, 1, 2)
	cfg.flames.refreshAge = math.clamp(math.round(cfg.flames.refreshAge * 10) / 10, 1.5, 4.5)
	cfg.flames.maxRange = math.clamp(math.floor(cfg.flames.maxRange), 15, 45)
	cfg.puffshrooms.commonTransparency = math.clamp(cfg.puffshrooms.commonTransparency, 0, 1)
	cfg.puffshrooms.rareTransparency = math.clamp(cfg.puffshrooms.rareTransparency, 0, 1)
	cfg.puffshrooms.epicTransparency = math.clamp(cfg.puffshrooms.epicTransparency, 0, 1)
end

local function saveConfig()
	if not (writefile and HttpService) then
		return
	end
	pcall(function()
		if isfolder and makefolder and not isfolder(CONFIG_DIR) then
			makefolder(CONFIG_DIR)
		end
		writefile(CONFIG_PATH, HttpService:JSONEncode(cfg))
	end)
end

loadConfig()

-- Thread and connection lifecycle managers
local threads = { list = {}, closed = false }
local connections = { list = {} }

function threads:Add(id, callback)
	if self.closed then
		return nil
	end
	self:Cancel(id)
	local thread
	thread = coroutine.create(function()
		local ok, err = xpcall(callback, debug.traceback)
		if self.list[id] == thread then
			self.list[id] = nil
		end
		if not ok and err and not string.find(tostring(err), "thread cancelled", 1, true) then
			warn("[Puffshroom Assistant] " .. tostring(err))
		end
	end)
	self.list[id] = thread
	task.spawn(thread)
	return thread
end

function threads:Get(id)
	return self.list[id]
end

function threads:Cancel(id)
	local thread = self.list[id]
	if thread then
		self.list[id] = nil
		pcall(function()
			task.cancel(thread)
		end)
	end
end

function threads:CancelAll()
	self.closed = true
	for id in pairs(self.list) do
		self:Cancel(id)
	end
end

function connections:Add(id, conn)
	self:Cancel(id)
	self.list[id] = conn
	return conn
end

function connections:Get(id)
	return self.list[id]
end

function connections:Cancel(id)
	local conn = self.list[id]
	if conn then
		self.list[id] = nil
		pcall(function()
			conn:Disconnect()
		end)
	end
end

function connections:CancelAll()
	for id in pairs(self.list) do
		self:Cancel(id)
	end
end

-- Secure call helper (matches Atlas+ identity handling for ClientStatCache & EggTypes)
local secureCall
do
	local function callWithIdentity(fn, ...)
		if setthreadidentity and getthreadidentity then
			local prev = getthreadidentity()
			setthreadidentity(5)
			local packed = table.pack(pcall(fn, ...))
			setthreadidentity(prev)
			if not packed[1] then
				error(packed[2], 0)
			end
			return table.unpack(packed, 2, packed.n)
		end
		return fn(...)
	end

	if newcclosure then
		secureCall = newcclosure(callWithIdentity)
	else
		secureCall = callWithIdentity
	end
end

local gameApi = {}
do
	local statMod = ReplicatedStorage:FindFirstChild("ClientStatCache")
	if statMod then
		local ok, mod = pcall(require, statMod)
		if ok and type(mod) == "table" and type(mod.Get) == "function" then
			gameApi.ClientStatCache = mod
		end
	end

	local eggMod = ReplicatedStorage:FindFirstChild("EggTypes")
	if eggMod then
		local ok, mod = pcall(require, eggMod)
		if ok and type(mod) == "table" and type(mod.GetTypes) == "function" then
			gameApi.EggTypes = mod.GetTypes
		end
	end

	local collectors = ReplicatedStorage:FindFirstChild("Collectors")
	local localCollectMod = collectors and collectors:FindFirstChild("LocalCollect")
	if localCollectMod then
		local ok, mod = pcall(require, localCollectMod)
		if ok and type(mod) == "table" and type(mod.Run) == "function" then
			gameApi.LocalCollect = mod.Run
		end
	end

	local localFxMod = ReplicatedStorage:FindFirstChild("LocalFX")
	if localFxMod then
		local ok, mod = pcall(require, localFxMod)
		if ok and type(mod) == "table" and type(mod.ClientRun) == "function" then
			gameApi.LocalFX = mod
		end
	end

	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	local playerSettingsEv = eventsFolder and eventsFolder:FindFirstChild("PlayerSettingsEvent")
	if playerSettingsEv and playerSettingsEv.FireServer then
		gameApi.PlayerSettingsEvent = playerSettingsEv
	end
end

function gameApi:Cache(...)
	if not self.ClientStatCache then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return secureCall(self.ClientStatCache.Get, nil, table.unpack(args, 1, args.n))
	end)
	return ok and result or nil
end

-- Helper to get character Humanoid & RootPart safely
local function getHumanoid()
	local char = localPlayer and localPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart()
	local char = localPlayer and localPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

-- Field resolver for puffshrooms
local fieldRaycastParams, fieldRaycastFolder
local function getFieldAt(point)
	if typeof(point) ~= "Vector3" then
		return nil
	end
	local zones = workspace:FindFirstChild("FlowerZones")
	if not zones then
		return nil
	end
	if not fieldRaycastParams or fieldRaycastFolder ~= zones then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { zones }
		params.FilterType = Enum.RaycastFilterType.Include
		fieldRaycastParams = params
		fieldRaycastFolder = zones
	end
	local ok, hit = pcall(function()
		return workspace:Raycast(point + Vector3.new(0, 8, 0), Vector3.new(0, -128, 0), fieldRaycastParams)
	end)
	if ok and hit and hit.Instance and hit.Instance.Parent == zones then
		return hit.Instance
	end
	for _, field in ipairs(zones:GetChildren()) do
		if field:IsA("BasePart") and field.CFrame then
			local offset = field.CFrame:PointToObjectSpace(point)
			if math.abs(offset.X) <= field.Size.X / 2 + 2 and math.abs(offset.Z) <= field.Size.Z / 2 + 2 then
				return field
			end
		end
	end
	return nil
end

local function getInstancePosition(inst)
	if not inst then
		return nil
	end
	local okPos, pos = pcall(function()
		return inst.Position
	end)
	if okPos and typeof(pos) == "Vector3" then
		return pos
	end
	if inst:IsA("Model") then
		local okPrim, prim = pcall(function()
			return inst.PrimaryPart
		end)
		if okPrim and prim then
			local okP, pPos = pcall(function()
				return prim.Position
			end)
			if okP and typeof(pPos) == "Vector3" then
				return pPos
			end
		end
		local okPivot, pivot = pcall(function()
			return inst:GetPivot()
		end)
		if okPivot and pivot then
			return pivot.Position
		end
	end
	return nil
end

-- Atlas+ WalkSpeed controller (capped at 90)
local walkSpeedController = {
	lastAppliedSpeed = nil,
	originalSpeed = nil,
	trackedHumanoid = nil,
}

function walkSpeedController:Step()
	if not cfg.movement.walkspeedenabled then
		return
	end
	local h = getHumanoid()
	if not h or not h.Parent or h.Health <= 0 then
		return
	end
	if self.trackedHumanoid ~= h then
		self.trackedHumanoid = h
		self.originalSpeed = h.WalkSpeed
		self.lastAppliedSpeed = nil
	end

	local maxCap = math.clamp(tonumber(cfg.movement.walkspeed) or 90, 30, 90)
	local targetSpeed = nil

	if not cfg.movement.walkdynamic then
		targetSpeed = maxCap
	else
		local modifiers = gameApi:Cache({ "ModifierCaches", "Value" })
		if type(modifiers) == "table" and type(modifiers.PlayerMovespeed) == "table" and type(modifiers.PlayerMovespeed._) == "number" then
			targetSpeed = math.min(maxCap, modifiers.PlayerMovespeed._ * (tonumber(cfg.movement.walkspeed2) or 1.5))
		end
	end

	if not targetSpeed then
		return
	end

	local currentSpeed = h.WalkSpeed
	local wasSetByUs = self.lastAppliedSpeed ~= nil and math.abs(currentSpeed - self.lastAppliedSpeed) < 0.05
	if currentSpeed < targetSpeed or (wasSetByUs and currentSpeed > targetSpeed) then
		h.WalkSpeed = targetSpeed
		self.lastAppliedSpeed = targetSpeed
	end
end

function walkSpeedController:Restore()
	local h = self.trackedHumanoid or getHumanoid()
	if h and h.Parent and self.lastAppliedSpeed ~= nil then
		local restoreTo = self.originalSpeed
		local modifiers = gameApi:Cache({ "ModifierCaches", "Value" })
		if type(modifiers) == "table" and type(modifiers.PlayerMovespeed) == "table" and type(modifiers.PlayerMovespeed._) == "number" then
			restoreTo = modifiers.PlayerMovespeed._
		end
		if type(restoreTo) == "number" and math.abs(h.WalkSpeed - self.lastAppliedSpeed) < 0.05 then
			h.WalkSpeed = restoreTo
		end
	end
	self.lastAppliedSpeed = nil
	self.originalSpeed = nil
	self.trackedHumanoid = nil
end

function walkSpeedController:SetEnabled(enabled)
	threads:Cancel("walkspeed")
	if not enabled then
		self:Restore()
		return
	end
	self:Step()
	threads:Add("walkspeed", function()
		while cfg.movement.walkspeedenabled and not threads.closed do
			self:Step()
			task.wait(0.1)
		end
	end)
end

-- Reversible Hide Decorations (exact targets from fullscript.txt)
local WORKSPACE_DECO_NAMES = {
	"Amulets",
	"Shell Amulets",
	"Stickbug Amulets",
	"BallArrowFolder",
	"BoostBalls",
	"Campsite",
	"ClassicMinigame",
	"Cubs",
	"Faces",
	"FieldDecos",
	"Frame",
	"Frogs",
	"Goo",
	"Paths",
	"Invisible Walls",
	"Leaderboards",
	"Territories",
	"TheGamesEvent",
	"TheGames_WideBanners",
	"Bee Bear Hive",
	"Noob Bear",
	"OnettNPC",
	"Pro Bear",
	"Top Bear",
	"BuckoAtHQ",
	"RileyAtHQ",
	"Honey",
	"Lion",
}

local HIVE_DECO_NAMES = {
	"HiveModels",
	"StickerCanvases",
}

local DECORATION_CHILD_NAMES = {
	"35ZoneCave",
	"BubbleWandChimney",
	"TreatBooth",
	"Coconut Field",
	"Pepper Patch",
	"Pine Tree",
	"SpiderCave",
	"Petal Shop",
	"JumpGames",
	"PEggMaze",
}

local decorationsController = {
	detached = {},
	detachedSet = {},
	savedPlatforms = {},
	hidden = false,
}

function decorationsController:Detach(inst)
	if not inst or self.detachedSet[inst] then
		return
	end
	local okParent, origParent = pcall(function()
		return inst.Parent
	end)
	if not okParent or not origParent then
		return
	end
	self.detachedSet[inst] = true
	table.insert(self.detached, { inst = inst, parent = origParent })
	pcall(function()
		inst.Parent = nil
	end)
end

function decorationsController:Hide()
	for _, name in ipairs(WORKSPACE_DECO_NAMES) do
		self:Detach(workspace:FindFirstChild(name))
	end

	local map = workspace:FindFirstChild("Map")
	if map then
		self:Detach(map:FindFirstChild("Fences"))
	end

	local hiveDeco = workspace:FindFirstChild("HiveDeco")
	if hiveDeco then
		for _, name in ipairs(HIVE_DECO_NAMES) do
			self:Detach(hiveDeco:FindFirstChild(name))
		end
	end

	local hivePlatforms = workspace:FindFirstChild("HivePlatforms")
	if hivePlatforms then
		for _, slot in ipairs(hivePlatforms:GetChildren()) do
			for _, item in ipairs(slot:GetChildren()) do
				if item.Name == "Platform" then
					if self.savedPlatforms[item] == nil then
						local okCol, origCol = pcall(function()
							return item.CanCollide
						end)
						if okCol then
							self.savedPlatforms[item] = origCol
						end
					end
					pcall(function()
						item.CanCollide = false
					end)
				elseif item.Name ~= "Hive" and item.Name ~= "PlayerRef" then
					self:Detach(item)
				end
			end
		end
	end

	local decorations = workspace:FindFirstChild("Decorations")
	if decorations then
		local misc = decorations:FindFirstChild("Misc")
		if misc then
			for _, child in ipairs(misc:GetChildren()) do
				local n = child.Name
				if string.find(n, "Blue Flower") or n == "Bamboo" or n == "Bush" or n == "Mushroom" then
					self:Detach(child)
				end
			end
		end

		for _, name in ipairs(DECORATION_CHILD_NAMES) do
			self:Detach(decorations:FindFirstChild(name))
		end

		for _, child in ipairs(decorations:GetChildren()) do
			local n = child.Name
			if string.find(n, "Dandelion") or string.find(n, "Clover") or string.find(n, "Rose") or string.find(n, "Sign") or string.find(n, "Glider") or n == "ShopWord" then
				self:Detach(child)
			end
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		local okMatch, isBarrier = pcall(function()
			return child.ClassName == "Part" and child.CollisionGroup == "BoostBallBarrier"
		end)
		if okMatch and isBarrier then
			self:Detach(child)
		end
	end

	self.hidden = true
end

function decorationsController:Restore()
	for i = #self.detached, 1, -1 do
		local entry = self.detached[i]
		if entry.inst and entry.parent then
			pcall(function()
				entry.inst.Parent = entry.parent
			end)
		end
	end
	table.clear(self.detached)
	table.clear(self.detachedSet)

	for plat, origCol in pairs(self.savedPlatforms) do
		pcall(function()
			plat.CanCollide = origCol
		end)
	end
	table.clear(self.savedPlatforms)
	self.hidden = false
end

function decorationsController:SetEnabled(enabled)
	if enabled then
		self:Hide()
	else
		self:Restore()
	end
end

-- Reversible FPS Optimizer (No destructive :Destroy() on user world instances)
local BLOCKED_LOCAL_FX = {
	AquaWave = true,
	BeamShot = true,
	BeesmasLightsFallingStar = true,
	BubbleBloatCollect = true,
	CCRocket = true,
	CCRocketCrosshairs = true,
	CCRocketCrosshairsOld = true,
	DiamondDrain = true,
	EggShield = true,
	FallingCoal = true,
	FallingSnowflake = true,
	FieldRectPulses = true,
	GoldenRake = true,
	GummyStar = true,
	Gummyball = true,
	HoneyHammer = true,
	MechsquitoShot = true,
	MythicMeteor = true,
	OrbExplode = true,
	PartyPopper = true,
	PetalShuriken = true,
	PluckedPetal = true,
	PopStar = true,
	PorcelainDipperAbility = true,
	PuffshroomSporeThrow = true,
	RectPulse = true,
	RingPulse = true,
	SnowballThrow = true,
	SnowflakeBreeze = true,
	SpotlightBeam = true,
	StarSaw = true,
	StarShowerGuide = true,
	StickerTokenBeam = true,
	SweepArch = true,
	Triangulate = true,
	WaterRipple = true,
}

local LOW_GFX_SKIP_FOLDERS = {
	Collectibles = true,
	PlayerFlames = true,
	Particles = true,
	Happenings = true,
	PuffAssistantTokenHighlights = true,
	RbcHelperSmileyHighlights = true,
}

local function extractLocalFxName(arg1, arg2)
	if type(arg1) == "string" then
		return arg1
	end
	if type(arg2) == "string" then
		return arg2
	end
	return nil
end

local function isDescendantOf(inst, ancestor)
	local p = inst
	while p do
		if p == ancestor then
			return true
		end
		p = p.Parent
	end
	return false
end

local function isProtectedHighlightPart(inst)
	local p = inst and inst.Parent
	while p and p ~= workspace do
		if p.Name == "PuffAssistantTokenHighlights" or p.Name == "RbcHelperSmileyHighlights" then
			return true
		end
		p = p.Parent
	end
	local n = inst and inst.Name
	return n == "TokenBeacon" or n == "SmileyDropBeam" or n == "SmileyBeacon"
end

local fpsOptimizer = {
	savedLighting = nil,
	savedLightingIBL = nil,
	savedLightingEffects = {},
	savedAtmospheres = {},
	savedTerrain = nil,
	savedQualityLevel = nil,
	savedPollenPopUpSetting = nil,
	pollenPopUpChanged = false,
	savedPartVisuals = {},
	lowGfxActive = false,

	detachedBees = {},
	detachedBeeSet = {},
	hideBeesActive = false,

	savedParticles = {},
	filterParticlesActive = false,
	installedFxWrapper = nil,
	origFxClientRun = nil,

	savedPlayers = {},
	playerCharWatched = {},
	hidePlayersActive = false,

	detachedFlowers = nil,
	hideFlowersActive = false,

	detachedBalloons = nil,
	hideBalloonsActive = false,
}

function fpsOptimizer:ApplyLowGraphicsPart(desc)
	if not self.lowGfxActive or not desc or not desc.Parent or self.savedPartVisuals[desc] then
		return
	end
	if not desc:IsA("BasePart") or isProtectedHighlightPart(desc) then
		return
	end
	local char = localPlayer and localPlayer.Character
	if char and isDescendantOf(desc, char) then
		return
	end
	local okCheck, skip = pcall(function()
		local mat = desc.Material
		return mat == Enum.Material.Neon or mat == Enum.Material.ForceField or mat == Enum.Material.Glass
	end)
	if okCheck and skip then
		return
	end
	local okRead, origMat, origShadow, origRefl = pcall(function()
		return desc.Material, desc.CastShadow, desc.Reflectance
	end)
	if not okRead then
		return
	end
	self.savedPartVisuals[desc] = {
		Material = origMat,
		CastShadow = origShadow,
		Reflectance = origRefl,
	}
	pcall(function()
		desc.CastShadow = false
		desc.Reflectance = 0
		desc.Material = Enum.Material.SmoothPlastic
	end)
end

function fpsOptimizer:RestoreLowGraphics()
	self.lowGfxActive = false
	connections:Cancel("fpsLowGfxLighting")
	connections:Cancel("fpsLowGfxDescAdded")
	for inst, props in pairs(self.savedPartVisuals) do
		if inst and inst.Parent then
			pcall(function()
				inst.Material = props.Material
				inst.CastShadow = props.CastShadow
				inst.Reflectance = props.Reflectance
			end)
		end
	end
	table.clear(self.savedPartVisuals)

	if self.savedLighting and Lighting then
		local l = self.savedLighting
		self.savedLighting = nil
		pcall(function()
			Lighting.GlobalShadows = l.GlobalShadows
			Lighting.FogEnd = l.FogEnd
			Lighting.FogStart = l.FogStart
		end)
	end

	if self.savedLightingIBL and Lighting then
		local ibl = self.savedLightingIBL
		self.savedLightingIBL = nil
		if ibl.EnvironmentSpecularScale ~= nil then
			pcall(function()
				Lighting.EnvironmentSpecularScale = ibl.EnvironmentSpecularScale
			end)
		end
		if ibl.EnvironmentDiffuseScale ~= nil then
			pcall(function()
				Lighting.EnvironmentDiffuseScale = ibl.EnvironmentDiffuseScale
			end)
		end
		if ibl.ShadowSoftness ~= nil then
			pcall(function()
				Lighting.ShadowSoftness = ibl.ShadowSoftness
			end)
		end
	else
		self.savedLightingIBL = nil
	end

	for eff, origEnabled in pairs(self.savedLightingEffects) do
		if eff and eff.Parent then
			pcall(function()
				eff.Enabled = origEnabled
			end)
		end
	end
	table.clear(self.savedLightingEffects)

	for atmo, origDensity in pairs(self.savedAtmospheres) do
		if atmo and atmo.Parent then
			pcall(function()
				atmo.Density = origDensity
			end)
		end
	end
	table.clear(self.savedAtmospheres)

	if self.savedTerrain then
		local t = self.savedTerrain
		self.savedTerrain = nil
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			pcall(function()
				terrain.WaterWaveSize = t.WaterWaveSize
				terrain.WaterWaveSpeed = t.WaterWaveSpeed
				terrain.WaterReflectance = t.WaterReflectance
				terrain.WaterTransparency = t.WaterTransparency
				terrain.Decoration = t.Decoration
			end)
		end
	end

	if self.savedQualityLevel ~= nil and type(settings) == "function" then
		local origQ = self.savedQualityLevel
		self.savedQualityLevel = nil
		pcall(function()
			settings().Rendering.QualityLevel = origQ
		end)
	else
		self.savedQualityLevel = nil
	end

	if self.pollenPopUpChanged then
		local restoreVal = self.savedPollenPopUpSetting ~= false
		self.pollenPopUpChanged = false
		self.savedPollenPopUpSetting = nil
		if gameApi.PlayerSettingsEvent then
			pcall(secureCall, gameApi.PlayerSettingsEvent.FireServer, gameApi.PlayerSettingsEvent, "PollenPopUps", restoreVal)
		end
	end
end

function fpsOptimizer:SetLowGraphics(enabled)
	if not enabled then
		self:RestoreLowGraphics()
		return
	end
	if self.lowGfxActive then
		return
	end
	self.lowGfxActive = true

	if Lighting and not self.savedLighting then
		local okL, gs, fe, fs = pcall(function()
			return Lighting.GlobalShadows, Lighting.FogEnd, Lighting.FogStart
		end)
		if okL then
			self.savedLighting = { GlobalShadows = gs, FogEnd = fe, FogStart = fs }
		end
		pcall(function()
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 1e9
			Lighting.FogStart = 1e9
		end)
		if not self.savedLightingIBL then
			local ibl = {}
			local okSpec, spec = pcall(function()
				return Lighting.EnvironmentSpecularScale
			end)
			if okSpec and type(spec) == "number" then
				ibl.EnvironmentSpecularScale = spec
				pcall(function()
					Lighting.EnvironmentSpecularScale = 0
				end)
			end
			local okDiff, diff = pcall(function()
				return Lighting.EnvironmentDiffuseScale
			end)
			if okDiff and type(diff) == "number" then
				ibl.EnvironmentDiffuseScale = diff
				pcall(function()
					Lighting.EnvironmentDiffuseScale = 0
				end)
			end
			local okSoft, soft = pcall(function()
				return Lighting.ShadowSoftness
			end)
			if okSoft and type(soft) == "number" then
				ibl.ShadowSoftness = soft
				pcall(function()
					Lighting.ShadowSoftness = 0
				end)
			end
			self.savedLightingIBL = ibl
		end
		for _, eff in ipairs(Lighting:GetChildren()) do
			if eff:IsA("PostEffect") then
				local okE, wasOn = pcall(function()
					return eff.Enabled
				end)
				if okE then
					self.savedLightingEffects[eff] = wasOn
					pcall(function()
						eff.Enabled = false
					end)
				end
			elseif eff:IsA("Atmosphere") then
				local okD, origD = pcall(function()
					return eff.Density
				end)
				if okD and type(origD) == "number" then
					self.savedAtmospheres[eff] = origD
					pcall(function()
						eff.Density = 0
					end)
				end
			end
		end
		if Lighting.Changed then
			connections:Cancel("fpsLowGfxLighting")
			connections:Add("fpsLowGfxLighting", Lighting.Changed:Connect(function()
				if not self.lowGfxActive then
					return
				end
				pcall(function()
					if Lighting.GlobalShadows ~= false then
						Lighting.GlobalShadows = false
					end
					if Lighting.FogEnd < 1e8 then
						Lighting.FogEnd = 1e9
					end
					if Lighting.FogStart < 1e8 then
						Lighting.FogStart = 1e9
					end
					if self.savedLightingIBL then
						if self.savedLightingIBL.EnvironmentSpecularScale ~= nil and Lighting.EnvironmentSpecularScale ~= 0 then
							Lighting.EnvironmentSpecularScale = 0
						end
						if self.savedLightingIBL.EnvironmentDiffuseScale ~= nil and Lighting.EnvironmentDiffuseScale ~= 0 then
							Lighting.EnvironmentDiffuseScale = 0
						end
					end
				end)
			end))
		end
	end

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not self.savedTerrain then
		local okT, ws, wsp, wr, wt, dec = pcall(function()
			return terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance, terrain.WaterTransparency, terrain.Decoration
		end)
		if okT then
			self.savedTerrain = {
				WaterWaveSize = ws,
				WaterWaveSpeed = wsp,
				WaterReflectance = wr,
				WaterTransparency = wt,
				Decoration = dec,
			}
		end
		pcall(function()
			terrain.WaterWaveSize = 0
			terrain.WaterWaveSpeed = 0
			terrain.WaterReflectance = 0
			terrain.WaterTransparency = 0
			terrain.Decoration = false
		end)
	end

	if self.savedQualityLevel == nil and type(settings) == "function" then
		local okQ, qVal = pcall(function()
			local renderSettings = settings().Rendering
			local orig = renderSettings.QualityLevel
			renderSettings.QualityLevel = Enum.QualityLevel.Level01
			return orig
		end)
		if okQ then
			self.savedQualityLevel = qVal
		end
	end

	if not self.pollenPopUpChanged and gameApi.PlayerSettingsEvent then
		local curPopUp = gameApi:Cache({ "Settings", "PollenPopUps" })
		if curPopUp ~= false then
			self.savedPollenPopUpSetting = curPopUp == nil and true or curPopUp
			self.pollenPopUpChanged = true
			pcall(secureCall, gameApi.PlayerSettingsEvent.FireServer, gameApi.PlayerSettingsEvent, "PollenPopUps", false)
		end
	end

	for _, topChild in ipairs(workspace:GetChildren()) do
		if not LOW_GFX_SKIP_FOLDERS[topChild.Name] then
			if topChild:IsA("BasePart") then
				self:ApplyLowGraphicsPart(topChild)
			else
				for _, desc in ipairs(topChild:GetDescendants()) do
					if desc:IsA("BasePart") then
						self:ApplyLowGraphicsPart(desc)
					end
				end
			end
		end
	end

	connections:Cancel("fpsLowGfxDescAdded")
	if workspace.DescendantAdded then
		connections:Add("fpsLowGfxDescAdded", workspace.DescendantAdded:Connect(function(desc)
			if not self.lowGfxActive or not desc:IsA("BasePart") then
				return
			end
			local p = desc.Parent
			while p and p ~= workspace do
				if LOW_GFX_SKIP_FOLDERS[p.Name] then
					return
				end
				p = p.Parent
			end
			self:ApplyLowGraphicsPart(desc)
		end))
	end
end

function fpsOptimizer:DetachBee(bee)
	if not self.hideBeesActive or not bee or self.detachedBeeSet[bee] then
		return
	end
	local okParent, origParent = pcall(function()
		return bee.Parent
	end)
	if not okParent or not origParent then
		return
	end
	self.detachedBeeSet[bee] = true
	table.insert(self.detachedBees, { inst = bee, parent = origParent })
	pcall(function()
		bee.Parent = nil
	end)
end

function fpsOptimizer:RestoreBees()
	self.hideBeesActive = false
	connections:Cancel("fpsBeesAdded")
	for i = #self.detachedBees, 1, -1 do
		local entry = self.detachedBees[i]
		if entry.inst and entry.parent and entry.parent.Parent then
			pcall(function()
				entry.inst.Parent = entry.parent
			end)
		end
	end
	table.clear(self.detachedBees)
	table.clear(self.detachedBeeSet)
end

function fpsOptimizer:SetHideBees(enabled)
	if not enabled then
		self:RestoreBees()
		return
	end
	self.hideBeesActive = true
	local bees = workspace:FindFirstChild("Bees")
	if bees then
		for _, child in ipairs(bees:GetChildren()) do
			self:DetachBee(child)
		end
		if not connections:Get("fpsBeesAdded") then
			connections:Add("fpsBeesAdded", bees.ChildAdded:Connect(function(child)
				if task and task.defer then
					task.defer(function()
						if self.hideBeesActive then
							self:DetachBee(child)
						end
					end)
				else
					self:DetachBee(child)
				end
			end))
		end
	end
end

function fpsOptimizer:SyncParticlesInstance(inst)
	if not inst or not inst.Parent then
		return
	end
	if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
		if inst.Name == "PuffshroomSpores" and cfg.perf.keepSporeTrails then
			local orig = self.savedParticles[inst]
			if orig ~= nil then
				self.savedParticles[inst] = nil
				pcall(function()
					inst.Enabled = orig
				end)
			end
			return
		end
		if self.savedParticles[inst] == nil then
			local ok, wasOn = pcall(function()
				return inst.Enabled
			end)
			self.savedParticles[inst] = ok and wasOn or true
		end
		pcall(function()
			inst.Enabled = false
		end)
	end
end

function fpsOptimizer:RestoreParticles()
	self.filterParticlesActive = false
	_G.__puffAssistantLocalFxFilter = nil
	connections:Cancel("fpsParticlesDescAdded")
	connections:Cancel("fpsParticlesRemoved")
	for inst, origEnabled in pairs(self.savedParticles) do
		if inst and inst.Parent then
			pcall(function()
				inst.Enabled = origEnabled
			end)
		end
	end
	table.clear(self.savedParticles)
end

function fpsOptimizer:EnsureLocalFxHook()
	if not gameApi.LocalFX or type(gameApi.LocalFX.ClientRun) ~= "function" then
		return
	end
	if _G.__puffAssistantLocalFxHooked then
		return
	end
	if type(hookfunction) == "function" then
		local okHook = pcall(function()
			local origFn
			local hookFn = function(...)
				local filterFn = _G.__puffAssistantLocalFxFilter
				if filterFn then
					local okKeep, keep = pcall(filterFn, ...)
					if okKeep and keep == false then
						return nil
					end
				end
				return origFn(...)
			end
			if newcclosure then
				hookFn = newcclosure(hookFn)
			end
			origFn = hookfunction(gameApi.LocalFX.ClientRun, hookFn)
		end)
		if okHook then
			_G.__puffAssistantLocalFxHooked = true
			_G.__puffAssistantLocalFxHookMethod = "hookfunction"
			self.installedFxWrapper = true
			return
		end
	end
	if not _G.__puffAssistantLocalFxOrig then
		_G.__puffAssistantLocalFxOrig = gameApi.LocalFX.ClientRun
	end
	local origFn = _G.__puffAssistantLocalFxOrig
	local wrapper = function(...)
		local filterFn = _G.__puffAssistantLocalFxFilter
		if filterFn then
			local okKeep, keep = pcall(filterFn, ...)
			if okKeep and keep == false then
				return nil
			end
		end
		return origFn(...)
	end
	_G.__puffAssistantLocalFxHooked = wrapper
	_G.__puffAssistantLocalFxHookMethod = "table"
	gameApi.LocalFX.ClientRun = wrapper
	self.installedFxWrapper = wrapper
	self.origFxClientRun = origFn
end

function fpsOptimizer:UnhookLocalFx()
	_G.__puffAssistantLocalFxFilter = nil
	if _G.__puffAssistantLocalFxHookMethod == "table" then
		if gameApi.LocalFX and _G.__puffAssistantLocalFxOrig and gameApi.LocalFX.ClientRun == _G.__puffAssistantLocalFxHooked then
			gameApi.LocalFX.ClientRun = _G.__puffAssistantLocalFxOrig
		end
		_G.__puffAssistantLocalFxHooked = nil
		_G.__puffAssistantLocalFxOrig = nil
		_G.__puffAssistantLocalFxHookMethod = nil
	end
	self.installedFxWrapper = nil
	self.origFxClientRun = nil
end

function fpsOptimizer:ApplyParticlesFolder()
	local folder = workspace:FindFirstChild("Particles")
	if not folder then
		return
	end
	self:SyncParticlesInstance(folder)
	for _, desc in ipairs(folder:GetDescendants()) do
		self:SyncParticlesInstance(desc)
	end
	if not connections:Get("fpsParticlesDescAdded") and folder.DescendantAdded then
		connections:Add("fpsParticlesDescAdded", folder.DescendantAdded:Connect(function(desc)
			if self.filterParticlesActive then
				self:SyncParticlesInstance(desc)
			end
		end))
	end
	if not connections:Get("fpsParticlesRemoved") then
		connections:Add("fpsParticlesRemoved", folder.ChildRemoved:Connect(function(child)
			self.savedParticles[child] = nil
			for inst in pairs(self.savedParticles) do
				if not inst.Parent then
					self.savedParticles[inst] = nil
				end
			end
		end))
	end
end

function fpsOptimizer:SetFilterParticles(enabled)
	if not enabled then
		self:RestoreParticles()
		return
	end
	self.filterParticlesActive = true
	self:EnsureLocalFxHook()
	_G.__puffAssistantLocalFxFilter = function(arg1, arg2)
		local fxName = extractLocalFxName(arg1, arg2)
		if not fxName then
			return true
		end
		if fxName == "PuffshroomSporeThrow" and cfg.perf.keepSporeTrails then
			return true
		end
		if BLOCKED_LOCAL_FX[fxName] then
			return false
		end
		return true
	end
	self:ApplyParticlesFolder()
end

function fpsOptimizer:SetKeepSporeTrails(_enabled)
	if not self.filterParticlesActive then
		return
	end
	local folder = workspace:FindFirstChild("Particles")
	if folder then
		for _, desc in ipairs(folder:GetDescendants()) do
			self:SyncParticlesInstance(desc)
		end
	end
end

function fpsOptimizer:HideCharacterVisuals(char)
	if not self.hidePlayersActive or not char or not char.Parent then
		return
	end
	local record = self.savedPlayers[char]
	if not record then
		record = {}
		self.savedPlayers[char] = record
	end
	local function hideInst(inst)
		if inst:IsA("BasePart") then
			if not record[inst] then
				local ok, origMod, origShadow = pcall(function()
					return inst.LocalTransparencyModifier, inst.CastShadow
				end)
				if ok then
					record[inst] = { LocalTransparencyModifier = origMod, CastShadow = origShadow }
				end
			end
			pcall(function()
				inst.LocalTransparencyModifier = 1
				inst.CastShadow = false
			end)
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			if not record[inst] then
				local ok, origT = pcall(function()
					return inst.Transparency
				end)
				if ok then
					record[inst] = { Transparency = origT }
				end
			end
			pcall(function()
				inst.Transparency = 1
			end)
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
			if not record[inst] then
				local ok, origEn = pcall(function()
					return inst.Enabled
				end)
				if ok then
					record[inst] = { Enabled = origEn }
				end
			end
			pcall(function()
				inst.Enabled = false
			end)
		end
	end
	for _, desc in ipairs(char:GetDescendants()) do
		hideInst(desc)
	end
	local connKey = "fpsPlayerDesc:" .. tostring(char)
	if not connections:Get(connKey) and char.DescendantAdded then
		connections:Add(connKey, char.DescendantAdded:Connect(function(desc)
			if self.hidePlayersActive then
				hideInst(desc)
			end
		end))
	end
end

function fpsOptimizer:RestoreCharacterVisuals(char)
	connections:Cancel("fpsPlayerDesc:" .. tostring(char))
	local record = self.savedPlayers[char]
	if not record then
		return
	end
	self.savedPlayers[char] = nil
	if char and char.Parent then
		for inst, props in pairs(record) do
			if inst and inst.Parent then
				for prop, origVal in pairs(props) do
					pcall(function()
						inst[prop] = origVal
					end)
				end
			end
		end
	end
end

function fpsOptimizer:WatchOtherPlayer(player)
	if not player or player == localPlayer or self.playerCharWatched[player] then
		return
	end
	self.playerCharWatched[player] = true
	if player.Character then
		self:HideCharacterVisuals(player.Character)
	end
	if player.CharacterAdded then
		connections:Add("fpsPlayerCharAdded:" .. tostring(player), player.CharacterAdded:Connect(function(char)
			if self.hidePlayersActive then
				self:HideCharacterVisuals(char)
			end
		end))
	end
	if player.CharacterRemoving then
		connections:Add("fpsPlayerCharRem:" .. tostring(player), player.CharacterRemoving:Connect(function(char)
			self:RestoreCharacterVisuals(char)
		end))
	end
end

function fpsOptimizer:RestorePlayers()
	self.hidePlayersActive = false
	connections:Cancel("fpsPlayerAdded")
	connections:Cancel("fpsPlayerRemoving")
	for player in pairs(self.playerCharWatched) do
		connections:Cancel("fpsPlayerCharAdded:" .. tostring(player))
		connections:Cancel("fpsPlayerCharRem:" .. tostring(player))
	end
	table.clear(self.playerCharWatched)
	local chars = {}
	for char in pairs(self.savedPlayers) do
		table.insert(chars, char)
	end
	for _, char in ipairs(chars) do
		self:RestoreCharacterVisuals(char)
	end
end

function fpsOptimizer:SetHidePlayers(enabled)
	if not enabled then
		self:RestorePlayers()
		return
	end
	self.hidePlayersActive = true
	for _, player in ipairs(Players:GetPlayers()) do
		self:WatchOtherPlayer(player)
	end
	if not connections:Get("fpsPlayerAdded") and Players.PlayerAdded then
		connections:Add("fpsPlayerAdded", Players.PlayerAdded:Connect(function(player)
			if self.hidePlayersActive then
				self:WatchOtherPlayer(player)
			end
		end))
	end
	if not connections:Get("fpsPlayerRemoving") and Players.PlayerRemoving then
		connections:Add("fpsPlayerRemoving", Players.PlayerRemoving:Connect(function(player)
			connections:Cancel("fpsPlayerCharAdded:" .. tostring(player))
			connections:Cancel("fpsPlayerCharRem:" .. tostring(player))
			self.playerCharWatched[player] = nil
			if player.Character then
				self:RestoreCharacterVisuals(player.Character)
			end
		end))
	end
end

function fpsOptimizer:RestoreFlowers()
	self.hideFlowersActive = false
	local entry = self.detachedFlowers
	self.detachedFlowers = nil
	if entry and entry.inst and entry.parent then
		pcall(function()
			entry.inst.Parent = entry.parent
		end)
	end
end

function fpsOptimizer:SetHideFlowers(enabled)
	if not enabled then
		self:RestoreFlowers()
		return
	end
	self.hideFlowersActive = true
	local flowers = workspace:FindFirstChild("Flowers")
	if flowers and not self.detachedFlowers then
		local okParent, origParent = pcall(function()
			return flowers.Parent
		end)
		if okParent and origParent then
			self.detachedFlowers = { inst = flowers, parent = origParent }
			pcall(function()
				flowers.Parent = nil
			end)
		end
	end
end

function fpsOptimizer:RestoreBalloons()
	self.hideBalloonsActive = false
	local entry = self.detachedBalloons
	self.detachedBalloons = nil
	if entry and entry.inst and entry.parent and entry.parent.Parent then
		pcall(function()
			entry.inst.Parent = entry.parent
		end)
	end
end

function fpsOptimizer:SetHideBalloons(enabled)
	if not enabled then
		self:RestoreBalloons()
		return
	end
	self.hideBalloonsActive = true
	local balloons = workspace:FindFirstChild("Balloons")
	local fieldBalloons = balloons and balloons:FindFirstChild("FieldBalloons")
	if fieldBalloons and not self.detachedBalloons then
		local okParent, origParent = pcall(function()
			return fieldBalloons.Parent
		end)
		if okParent and origParent then
			self.detachedBalloons = { inst = fieldBalloons, parent = origParent }
			pcall(function()
				fieldBalloons.Parent = nil
			end)
		end
	end
end

function fpsOptimizer:RestoreAll()
	self:RestoreLowGraphics()
	self:RestoreBees()
	self:RestoreParticles()
	self:UnhookLocalFx()
	self:RestorePlayers()
	self:RestoreFlowers()
	self:RestoreBalloons()
end

-- Standalone BodyGyro Auto-Face Flames & Refresh (Shift Lock compatible)
local FLAME_RENDER_STEP_NAME = "PuffAssistantFlameFace"

local function isShiftLockActive()
	local ok, active = pcall(function()
		return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			or UserInputService.MouseIcon == "rbxasset://textures/MouseLockedCursor.png"
	end)
	return ok and active == true
end

local function isClimbing(hum)
	if not hum then
		return false
	end
	local ok, state = pcall(function()
		return hum:GetState() == Enum.HumanoidStateType.Climbing
	end)
	return ok and state == true
end

local flameController = {
	tracked = {},
	gyro = nil,
	managedHumanoid = nil,
	savedAutoRotate = nil,
	renderBound = false,
	stopDig = false,
	statusLabel = nil,
	lastStatusText = nil,
	cachedField = nil,
	cachedFieldPos = nil,
	cachedFieldTime = 0,
	currentTarget = nil,
	lastScanTime = 0,
	cachedStopDig = false,
	cachedModeLabel = "idle",
}

function flameController:InvalidateTarget()
	self.currentTarget = nil
	self.lastScanTime = 0
end

function flameController:GetCachedField(rootPos, now)
	if self.cachedField and self.cachedField.Parent and self.cachedFieldPos and (now - self.cachedFieldTime) < 0.1 then
		local dx = rootPos.X - self.cachedFieldPos.X
		local dy = rootPos.Y - self.cachedFieldPos.Y
		local dz = rootPos.Z - self.cachedFieldPos.Z
		if dx * dx + dy * dy + dz * dz < 9 then
			return self.cachedField
		end
	end
	local field = getFieldAt(rootPos)
	self.cachedField = field
	self.cachedFieldPos = rootPos
	self.cachedFieldTime = now
	return field
end

function flameController:SuppressAutoRotate(hum)
	if not hum then
		return
	end
	if self.managedHumanoid and self.managedHumanoid ~= hum then
		self:RestoreAutoRotate()
	end
	if self.managedHumanoid ~= hum then
		local okRead, orig = pcall(function()
			return hum.AutoRotate
		end)
		self.savedAutoRotate = (okRead and type(orig) == "boolean") and orig or true
		self.managedHumanoid = hum
	end
	pcall(function()
		hum.AutoRotate = false
	end)
end

function flameController:RestoreAutoRotate()
	local hum = self.managedHumanoid
	local saved = self.savedAutoRotate
	self.managedHumanoid = nil
	self.savedAutoRotate = nil
	if hum and hum.Parent and saved ~= nil then
		pcall(function()
			hum.AutoRotate = saved
		end)
	end
end

function flameController:UnbindRenderStep()
	connections:Cancel("flameFace")
	if self.renderBound and RunService.UnbindFromRenderStep then
		pcall(function()
			RunService:UnbindFromRenderStep(FLAME_RENDER_STEP_NAME)
		end)
		self.renderBound = false
	end
end

local function inspectFlame(flameObj, record, now)
	if not flameObj or not flameObj.Parent then
		return nil
	end
	if type(record) ~= "table" then
		record = { spawnTime = record }
	end
	local pos = getInstancePosition(flameObj)
	if not pos then
		return nil
	end
	local pf = record.pf
	if not (pf and pf.Parent) then
		pf = flameObj:FindFirstChild("PF")
		record.pf = pf
	end
	if not pf then
		return nil
	end
	local okValid, sizeVal = pcall(function()
		local s = pf.Size.Keypoints[1].Value
		local g = pf.Color.Keypoints[1].Value.G
		if s <= 1.4 or g <= 0.2 then
			return nil
		end
		return s
	end)
	if not okValid or not sizeVal then
		return nil
	end

	if not record.fieldPos or math.abs(pos.X - record.fieldPos.X) > 2 or math.abs(pos.Z - record.fieldPos.Z) > 2 or (record.field and not record.field.Parent) then
		record.field = getFieldAt(pos)
		record.fieldPos = pos
	end

	local age
	if type(record.spawnTime) == "number" then
		age = math.max(0, now - record.spawnTime)
	else
		local estRem = 1 + math.clamp((sizeVal - 1.4) / 0.35, 0, 1) * 5
		age = math.max(0, 6 - estRem)
	end
	return pos, age, record.field
end

function flameController:SetStatusText(text)
	if self.lastStatusText == text then
		return
	end
	self.lastStatusText = text
	if self.statusLabel then
		self.statusLabel.Text = text
	end
end

function flameController:EnsureGyro(rootPart)
	if self.gyro and self.gyro.Parent ~= rootPart then
		pcall(function()
			self.gyro:Destroy()
		end)
		self.gyro = nil
	end
	if not self.gyro and rootPart then
		local okGyro, created = pcall(function()
			local g = Instance.new("BodyGyro")
			g.Name = "PuffFlameGyro"
			g.P = 20000
			g.D = 400
			g.MaxTorque = Vector3.new(0, 0, 0)
			g.Parent = rootPart
			return g
		end)
		if okGyro then
			self.gyro = created
		end
	end
	return self.gyro
end

function flameController:ReleaseGyro()
	self:RestoreAutoRotate()
	if self.gyro then
		pcall(function()
			self.gyro.MaxTorque = Vector3.new(0, 0, 0)
			self.gyro:Destroy()
		end)
		self.gyro = nil
	end
end

function flameController:ZeroTorque()
	self:RestoreAutoRotate()
	if self.gyro then
		pcall(function()
			self.gyro.MaxTorque = Vector3.new(0, 0, 0)
		end)
	end
end

function flameController:BindFolder(folder)
	connections:Cancel("flamesAdded")
	connections:Cancel("flamesRemoved")
	self:InvalidateTarget()
	if not folder then
		table.clear(self.tracked)
		return
	end
	connections:Add("flamesAdded", folder.ChildAdded:Connect(function(child)
		self.tracked[child] = { spawnTime = os.clock() }
	end))
	connections:Add("flamesRemoved", folder.ChildRemoved:Connect(function(child)
		if self.currentTarget and self.currentTarget.obj == child then
			self:InvalidateTarget()
		end
		self.tracked[child] = nil
	end))
	for _, child in ipairs(folder:GetChildren()) do
		if self.tracked[child] == nil then
			self.tracked[child] = { spawnTime = false }
		end
	end
end

function flameController:SelectTarget(rootPos, field, now)
	if not rootPos or not field then
		return nil, false, "idle"
	end
	local maxRange = math.clamp(tonumber(cfg.flames.maxRange) or 30, 15, 45)
	local refreshAge = math.clamp(tonumber(cfg.flames.refreshAge) or 3.0, 1.5, 4.5)
	local hasFreshInRange = false
	local bestReady = nil
	local bestFallback = nil
	local stale = nil

	for flameObj, record in pairs(self.tracked) do
		if not flameObj or not flameObj.Parent then
			stale = stale or {}
			table.insert(stale, flameObj)
		else
			if type(record) ~= "table" then
				record = { spawnTime = record }
				self.tracked[flameObj] = record
			end
			local pos, age, flameField = inspectFlame(flameObj, record, now)
			if pos then
				local dx = pos.X - rootPos.X
				local dz = pos.Z - rootPos.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < maxRange and flameField == field then
					if age < refreshAge then
						hasFreshInRange = true
					end
					if dist > 4 then
						if age >= refreshAge then
							if not bestReady or age > bestReady.age + 0.15 or (math.abs(age - bestReady.age) <= 0.15 and dist < bestReady.dist) then
								bestReady = { obj = flameObj, pos = pos, age = age, dist = dist }
							end
						end
						if not bestFallback or dist < bestFallback.dist then
							bestFallback = { obj = flameObj, pos = pos, age = age, dist = dist }
						end
					end
				end
			end
		end
	end

	if stale then
		for _, obj in ipairs(stale) do
			self.tracked[obj] = nil
		end
	end

	if cfg.flames.refreshPriority then
		if bestReady then
			return bestReady, false, "refresh"
		elseif cfg.flames.onlyRefreshReady then
			return nil, hasFreshInRange, "waiting"
		else
			return bestFallback, hasFreshInRange, bestFallback and "face" or "idle"
		end
	end
	return bestFallback, false, bestFallback and "face" or "idle"
end

function flameController:Step(now)
	if not cfg.flames.enabled then
		self:ReleaseGyro()
		self:InvalidateTarget()
		self.stopDig = false
		self:SetStatusText("Target: Disabled")
		return
	end

	local rootPart = getRootPart()
	local hum = getHumanoid()
	if not rootPart or not hum or not hum.Parent or hum.Health <= 0 then
		self:ZeroTorque()
		self:InvalidateTarget()
		self.stopDig = false
		self:SetStatusText("Target: Waiting for character")
		return
	end

	local rootPos = getInstancePosition(rootPart)
	local currentClock = now or os.clock()
	local field = rootPos and self:GetCachedField(rootPos, currentClock) or nil
	if not field then
		self:ZeroTorque()
		self:InvalidateTarget()
		self.stopDig = false
		self:SetStatusText("Target: Not in a field")
		return
	end

	local targetEntry = self.currentTarget
	local stopDig = self.cachedStopDig
	local modeLabel = self.cachedModeLabel
	local useCached = false

	if targetEntry and targetEntry.obj and targetEntry.obj.Parent and (currentClock - self.lastScanTime) < 0.05 then
		local rec = self.tracked[targetEntry.obj]
		if rec then
			local pos, age, flameField = inspectFlame(targetEntry.obj, rec, currentClock)
			if pos and flameField == field then
				local maxRange = math.clamp(tonumber(cfg.flames.maxRange) or 30, 15, 45)
				local refreshAge = math.clamp(tonumber(cfg.flames.refreshAge) or 3.0, 1.5, 4.5)
				local dx = pos.X - rootPos.X
				local dz = pos.Z - rootPos.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < maxRange and (not cfg.flames.onlyRefreshReady or not cfg.flames.refreshPriority or age >= refreshAge) then
					targetEntry.pos = pos
					targetEntry.age = age
					targetEntry.dist = dist
					useCached = true
				end
			end
		end
	end

	if not useCached then
		targetEntry, stopDig, modeLabel = self:SelectTarget(rootPos, field, currentClock)
		self.currentTarget = targetEntry
		self.cachedStopDig = stopDig
		self.cachedModeLabel = modeLabel
		self.lastScanTime = currentClock
	end

	self.stopDig = stopDig

	if not targetEntry then
		self:ZeroTorque()
		self:SetStatusText(modeLabel == "waiting" and "Target: Holding for refresh" or ("Target: Idle in " .. field.Name))
		return
	end

	local dx = targetEntry.pos.X - rootPos.X
	local dz = targetEntry.pos.Z - rootPos.Z
	if dx * dx + dz * dz <= 0.01 then
		self:ZeroTorque()
		self:SetStatusText("Target: On flame")
		return
	end

	if cfg.flames.shiftLockCompat then
		self:SuppressAutoRotate(hum)
	else
		self:RestoreAutoRotate()
	end

	local flatTarget = Vector3.new(targetEntry.pos.X, rootPos.Y, targetEntry.pos.Z)
	local lookCf = CFrame.lookAt and CFrame.lookAt(rootPos, flatTarget) or CFrame.new(rootPos, flatTarget)
	local gyro = self:EnsureGyro(rootPart)
	if gyro then
		pcall(function()
			gyro.MaxTorque = Vector3.new(0, math.huge, 0)
			gyro.CFrame = lookCf
		end)
	end
	if cfg.flames.shiftLockCompat and isShiftLockActive() and not isClimbing(hum) then
		pcall(function()
			rootPart.CFrame = lookCf
		end)
	end

	self:SetStatusText(string.format("Target: %s (%.1fs, %.0fst)", modeLabel == "refresh" and "Refreshing" or "Facing", targetEntry.age, targetEntry.dist))
end

function flameController:SetEnabled(enabled)
	self:UnbindRenderStep()
	self:InvalidateTarget()
	if not enabled then
		self:ReleaseGyro()
		self.stopDig = false
		self:SetStatusText("Target: Disabled")
		return
	end
	local pf = workspace:FindFirstChild("PlayerFlames")
	if pf and not connections:Get("flamesAdded") then
		self:BindFolder(pf)
	elseif pf then
		for _, child in ipairs(pf:GetChildren()) do
			if self.tracked[child] == nil then
				self.tracked[child] = { spawnTime = false }
			end
		end
	end
	self:Step(os.clock())
	if RunService.BindToRenderStep then
		local okPrio, camPrio = pcall(function()
			return Enum.RenderPriority.Camera.Value
		end)
		local priority = (okPrio and type(camPrio) == "number") and (camPrio + 1) or 201
		local okBind = pcall(function()
			RunService:BindToRenderStep(FLAME_RENDER_STEP_NAME, priority, function()
				self:Step(os.clock())
			end)
		end)
		if okBind then
			self.renderBound = true
			return
		end
	end
	local sig = RunService.RenderStepped or RunService.Heartbeat
	if sig then
		connections:Add("flameFace", sig:Connect(function()
			self:Step(os.clock())
		end))
	end
end

local function syncSmartAutoDig()
	threads:Cancel("smartAutoDig")
	if not cfg.flames.smartAutoDig then
		return
	end
	threads:Add("smartAutoDig", function()
		while cfg.flames.smartAutoDig and not threads.closed do
			if not (cfg.flames.enabled and flameController.stopDig) and gameApi.LocalCollect then
				pcall(secureCall, gameApi.LocalCollect)
			end
			task.wait(0.1)
		end
	end)
end

-- Token IDs (Hide Tokens & 3D Rare Highlights)
local tokenIds = {
	honey = {
		["1472135114"] = true, -- Honey Token
		["1952683491"] = true, -- Honey Icon
	},
	softWax = {
		["8277778300"] = true, -- Soft Wax
	},
	bitterberry = {
		["4483236276"] = true, -- Bitterberry
		["6087985073"] = true, -- Bitterberry alt
	},
	treat = {
		["2028574353"] = true, -- Treat
	},
	royalJelly = {
		["1471882621"] = true, -- Royal Jelly
	},
	swirledWax = {
		["8277783113"] = true, -- Swirled Wax
	},
	causticWax = {
		["8277781666"] = true, -- Caustic Wax
	},
	turpentine = {
		["8310376128"] = true, -- Turpentine
	},
}

-- Enrich token IDs directly from EggTypes if available in game
do
	local function addIconFromInfo(bucket, info)
		if type(info) ~= "table" then
			return
		end
		for _, field in ipairs({ "Icon", "IconImage", "Texture", "DecalID", "Picture" }) do
			local val = info[field]
			if val ~= nil then
				local id = string.match(tostring(val), "%d+")
				if id and #id >= 6 then
					bucket[id] = true
				end
			end
		end
	end

	if gameApi.EggTypes then
		local ok, types = pcall(function()
			return secureCall(gameApi.EggTypes)
		end)
		if ok and type(types) == "table" then
			for key, info in pairs(types) do
				local normKey = string.lower(tostring(key))
				local disp = type(info) == "table" and info.DisplayName and string.lower(tostring(info.DisplayName)) or ""
				if normKey == "softwax" or disp == "soft wax" then
					addIconFromInfo(tokenIds.softWax, info)
				elseif normKey == "bitterberry" or disp == "bitterberry" then
					addIconFromInfo(tokenIds.bitterberry, info)
				elseif normKey == "honey" or disp == "honey" then
					addIconFromInfo(tokenIds.honey, info)
				elseif normKey == "treat" or disp == "treat" then
					addIconFromInfo(tokenIds.treat, info)
				elseif normKey == "royaljelly" or disp == "royal jelly" then
					addIconFromInfo(tokenIds.royalJelly, info)
				elseif normKey == "swirledwax" or disp == "swirled wax" then
					addIconFromInfo(tokenIds.swirledWax, info)
				elseif normKey == "causticwax" or disp == "caustic wax" then
					addIconFromInfo(tokenIds.causticWax, info)
				elseif normKey == "turpentine" or disp == "turpentine" then
					addIconFromInfo(tokenIds.turpentine, info)
				end
			end
		end
	end
end

local tokenHighlighter

local tokenHider = {
	ids = tokenIds,
	saved = {},
	watchers = {},
	descCache = {},
}

local function extractTokenIconId(token)
	if not token then
		return nil
	end
	local front = token:FindFirstChild("FrontDecal")
	if front and front.Texture then
		local id = string.match(tostring(front.Texture), "%d+")
		if id then
			return id
		end
	end
	local back = token:FindFirstChild("BackDecal")
	if back and back.Texture then
		local id = string.match(tostring(back.Texture), "%d+")
		if id then
			return id
		end
	end
	for _, child in ipairs(token:GetChildren()) do
		if child:IsA("Decal") and child.Texture then
			local id = string.match(tostring(child.Texture), "%d+")
			if id then
				return id
			end
		end
	end
	return nil
end

function tokenHider:ShouldHide(token)
	local iconId = extractTokenIconId(token)
	if not iconId then
		return false
	end
	if cfg.tokens.hideHoney and self.ids.honey[iconId] then
		return true
	end
	if cfg.tokens.hideSoftWax and self.ids.softWax[iconId] then
		return true
	end
	if cfg.tokens.hideBitterberry and self.ids.bitterberry[iconId] then
		return true
	end
	if cfg.tokens.hideTreat and self.ids.treat[iconId] then
		return true
	end
	if cfg.tokens.hideRoyalJelly and self.ids.royalJelly[iconId] then
		return true
	end
	return false
end

local function saveAndSet(record, inst, prop, newVal)
	local ok, current = pcall(function()
		return inst[prop]
	end)
	if not ok then
		return
	end
	local props = record[inst]
	if not props then
		props = {}
		record[inst] = props
	end
	if props[prop] == nil then
		props[prop] = current
	end
	pcall(function()
		inst[prop] = newVal
	end)
end

function tokenHider:Hide(token)
	if not token or not token.Parent then
		return
	end
	local record = self.saved[token]
	if not record then
		record = {}
		self.saved[token] = record
	end
	local cache = self.descCache[token]
	if not cache then
		cache = { parts = {}, decals = {}, emitters = {} }
		self.descCache[token] = cache
		if token:IsA("BasePart") then
			table.insert(cache.parts, token)
		end
		for _, desc in ipairs(token:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(cache.parts, desc)
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				table.insert(cache.decals, desc)
			elseif desc:IsA("ParticleEmitter") or desc:IsA("Sparkles") or desc:IsA("Light") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
				table.insert(cache.emitters, desc)
			end
		end
	end
	for _, part in ipairs(cache.parts) do
		saveAndSet(record, part, "LocalTransparencyModifier", 1)
		saveAndSet(record, part, "Transparency", 1)
		saveAndSet(record, part, "CastShadow", false)
	end
	for _, decal in ipairs(cache.decals) do
		saveAndSet(record, decal, "Transparency", 1)
	end
	for _, emitter in ipairs(cache.emitters) do
		saveAndSet(record, emitter, "Enabled", false)
	end
end

function tokenHider:Restore(token)
	local record = self.saved[token]
	if not record then
		return
	end
	self.saved[token] = nil
	for inst, props in pairs(record) do
		if inst and inst.Parent then
			for prop, origVal in pairs(props) do
				pcall(function()
					inst[prop] = origVal
				end)
			end
		end
	end
end

function tokenHider:Evaluate(token)
	if not token or not token.Parent then
		return
	end
	if self:ShouldHide(token) then
		self:Hide(token)
	else
		self:Restore(token)
	end
end

function tokenHider:Unwatch(token)
	local conns = self.watchers[token]
	if conns then
		self.watchers[token] = nil
		for _, conn in ipairs(conns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	self.saved[token] = nil
end

function tokenHider:Watch(token)
	if not token or self.watchers[token] then
		return
	end
	local conns = {}
	self.watchers[token] = conns

	local function bindDecal(obj)
		if (obj:IsA("Decal") or obj:IsA("Texture")) and obj.GetPropertyChangedSignal then
			table.insert(conns, obj:GetPropertyChangedSignal("Texture"):Connect(function()
				self:Evaluate(token)
				if tokenHighlighter then
					tokenHighlighter:Evaluate(token)
				end
			end))
		end
	end

	for _, desc in ipairs(token:GetDescendants()) do
		bindDecal(desc)
	end

	if token.DescendantAdded then
		table.insert(conns, token.DescendantAdded:Connect(function(desc)
			bindDecal(desc)
			self:Evaluate(token)
			if tokenHighlighter then
				tokenHighlighter:Evaluate(token)
			end
		end))
	end

	self:Evaluate(token)
end

function tokenHider:RefreshAll()
	local folder = workspace:FindFirstChild("Collectibles")
	if not folder then
		for token in pairs(self.saved) do
			self:Restore(token)
		end
		return
	end
	for _, token in ipairs(folder:GetChildren()) do
		self:Watch(token)
		self:Evaluate(token)
	end
end

function tokenHider:Maintain()
	for token in pairs(self.saved) do
		if not token.Parent or not self:ShouldHide(token) then
			self.descCache[token] = nil
			if token.Parent then
				self:Restore(token)
			else
				self:Unwatch(token)
			end
		else
			local cache = self.descCache[token]
			if cache then
				for _, part in ipairs(cache.parts) do
					if part.Parent then
						pcall(function()
							part.LocalTransparencyModifier = 1
							part.Transparency = 1
							part.CastShadow = false
						end)
					end
				end
				for _, decal in ipairs(cache.decals) do
					if decal.Parent then
						pcall(function()
							decal.Transparency = 1
						end)
					end
				end
			end
		end
	end
	for token in pairs(self.descCache) do
		if not self.saved[token] then
			self.descCache[token] = nil
		end
	end
end

function tokenHider:RestoreAll()
	for token in pairs(self.saved) do
		self:Restore(token)
	end
	for token in pairs(self.watchers) do
		self:Unwatch(token)
	end
	table.clear(self.descCache)
end

-- 3D Token Highlighter (Swirled Wax Yellow, Caustic Wax Green, Turpentine Red)
local HIGHLIGHT_FOLDER_NAME = "PuffAssistantTokenHighlights"
local HIGHLIGHT_STYLES = {
	turpentine = {
		key = "turpentine",
		label = "TURPENTINE",
		notifyTitle = "Turpentine Token!",
		color = Color3.fromRGB(255, 64, 78),
		outline = Color3.fromRGB(255, 220, 224),
		beamHeight = 26,
		beamWidth = 0.34,
	},
	causticWax = {
		key = "causticWax",
		label = "CAUSTIC WAX",
		notifyTitle = "Caustic Wax Token!",
		color = Color3.fromRGB(52, 235, 110),
		outline = Color3.fromRGB(215, 255, 225),
		beamHeight = 20,
		beamWidth = 0.28,
	},
	swirledWax = {
		key = "swirledWax",
		label = "SWIRLED WAX",
		notifyTitle = "Swirled Wax Token!",
		color = Color3.fromRGB(255, 218, 55),
		outline = Color3.fromRGB(255, 250, 205),
		beamHeight = 20,
		beamWidth = 0.28,
	},
}

local function makeVerticalCylinderCFrame(x, y, z)
	if CFrame.Angles then
		local ok, cf = pcall(function()
			return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
		end)
		if ok and cf then
			return cf
		end
	end
	return CFrame.new(x, y, z)
end

tokenHighlighter = {
	ids = tokenIds,
	active = {},
	notified = {},
	rootFolder = nil,
	notifyFn = nil,
	lastBeaconTick = 0,
}

local function getTokenPosition(token)
	if not token then
		return nil
	end
	local okPos, pos = pcall(function()
		return token.Position
	end)
	if okPos and typeof(pos) == "Vector3" then
		return pos
	end
	if token:IsA("Model") then
		local okPivot, pivot = pcall(function()
			return token:GetPivot()
		end)
		if okPivot and pivot then
			return pivot.Position
		end
	end
	return nil
end

function tokenHighlighter:GetRootFolder()
	if self.rootFolder and self.rootFolder.Parent then
		return self.rootFolder
	end
	local old = workspace:FindFirstChild(HIGHLIGHT_FOLDER_NAME)
	if old then
		pcall(function()
			old:Destroy()
		end)
	end
	local folder = Instance.new("Folder")
	folder.Name = HIGHLIGHT_FOLDER_NAME
	folder.Parent = workspace
	self.rootFolder = folder
	return folder
end

function tokenHighlighter:GetHighlightStyle(token)
	local iconId = extractTokenIconId(token)
	if not iconId then
		return nil
	end
	if cfg.highlights.turpentine and self.ids.turpentine[iconId] then
		return HIGHLIGHT_STYLES.turpentine
	end
	if cfg.highlights.causticWax and self.ids.causticWax[iconId] then
		return HIGHLIGHT_STYLES.causticWax
	end
	if cfg.highlights.swirledWax and self.ids.swirledWax[iconId] then
		return HIGHLIGHT_STYLES.swirledWax
	end
	return nil
end

function tokenHighlighter:SyncFollowConnection()
	if next(self.active) ~= nil then
		if not connections:Get("highlightFollow") then
			local sig = RunService.Heartbeat or RunService.RenderStepped
			if sig then
				connections:Add("highlightFollow", sig:Connect(function()
					self:UpdateBeacons(false)
				end))
			end
		end
	else
		connections:Cancel("highlightFollow")
	end
end

function tokenHighlighter:UpdateBeacons(force)
	local now = os.clock()
	if not force and (now - self.lastBeaconTick) < 0.05 then
		return
	end
	self.lastBeaconTick = now
	local stale
	for token, entry in pairs(self.active) do
		if not token or not token.Parent then
			stale = stale or {}
			table.insert(stale, token)
		elseif entry.beaconPart then
			local pos = getTokenPosition(token)
			if pos then
				local last = entry.lastPos
				if not last or (pos.X - last.X) ^ 2 + (pos.Y - last.Y) ^ 2 + (pos.Z - last.Z) ^ 2 >= 0.0025 then
					entry.lastPos = pos
					pcall(function()
						entry.beaconPart.CFrame = makeVerticalCylinderCFrame(pos.X, pos.Y + entry.beamHeight * 0.5, pos.Z)
					end)
				end
			end
		end
	end
	if stale then
		for _, token in ipairs(stale) do
			self:Remove(token)
		end
	end
end

function tokenHighlighter:UpdateEntryVisuals(entry)
	if not entry then
		return
	end
	if entry.beaconPart then
		pcall(function()
			entry.beaconPart.Transparency = cfg.highlights.beam and 0.30 or 1
		end)
	end
	if entry.beaconAdornment then
		pcall(function()
			entry.beaconAdornment.Visible = cfg.highlights.beam
		end)
	end
	if entry.billboard then
		pcall(function()
			entry.billboard.Enabled = cfg.highlights.label
		end)
	end
end

function tokenHighlighter:Apply(token, style)
	if not token or not token.Parent or not style then
		return
	end
	local existing = self.active[token]
	if existing then
		if existing.kind == style.key then
			self:UpdateEntryVisuals(existing)
			return
		end
		self:Remove(token)
	end

	local root = self:GetRootFolder()
	local entryFolder = Instance.new("Folder")
	entryFolder.Name = style.key
	entryFolder.Parent = root

	local pos = getTokenPosition(token)

	pcall(function()
		local hl = Instance.new("Highlight")
		hl.Name = "TokenHighlight"
		hl.Adornee = token
		hl.FillColor = style.color
		hl.FillTransparency = 0.58
		hl.OutlineColor = style.outline
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = entryFolder
	end)

	local beaconPart, beaconAdornment
	local okBeacon, createdPart, createdAdorn = pcall(function()
		local part = Instance.new("Part")
		part.Name = "TokenBeacon"
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = style.color
		part.Size = Vector3.new(style.beamHeight, style.beamWidth, style.beamWidth)
		part.Transparency = cfg.highlights.beam and 0.30 or 1
		if pos then
			part.CFrame = makeVerticalCylinderCFrame(pos.X, pos.Y + style.beamHeight * 0.5, pos.Z)
		end
		part.Parent = entryFolder

		local cylAdorn = Instance.new("CylinderHandleAdornment")
		cylAdorn.Name = "TokenBeaconXRay"
		cylAdorn.Adornee = part
		cylAdorn.AlwaysOnTop = true
		cylAdorn.ZIndex = 5
		cylAdorn.Color3 = style.color
		cylAdorn.Radius = style.beamWidth * 0.34
		cylAdorn.Height = style.beamHeight
		cylAdorn.Transparency = 0.62
		cylAdorn.Visible = cfg.highlights.beam
		if CFrame.Angles then
			pcall(function()
				cylAdorn.CFrame = CFrame.Angles(0, math.rad(90), 0)
			end)
		end
		cylAdorn.Parent = part

		return part, cylAdorn
	end)
	if okBeacon then
		beaconPart = createdPart
		beaconAdornment = createdAdorn
	end

	local billboard
	local okGui, createdGui = pcall(function()
		local gui = Instance.new("BillboardGui")
		gui.Name = "TokenLabel"
		gui.Adornee = token
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 360
		gui.Size = UDim2.new(0, 118, 0, 22)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.0, 0)
		gui.Enabled = cfg.highlights.label
		gui.Parent = entryFolder

		local frame = Instance.new("Frame")
		frame.Name = "TagFrame"
		frame.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
		frame.BackgroundTransparency = 0.14
		frame.BorderSizePixel = 0
		frame.ClipsDescendants = true
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.2
		stroke.Color = style.color
		stroke.Transparency = 0.25
		stroke.Parent = frame

		local accent = Instance.new("Frame")
		accent.Name = "AccentBar"
		accent.BackgroundColor3 = style.color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 3, 1, 0)
		accent.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Label"
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Size = UDim2.new(1, -12, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.Text = style.label
		lbl.TextColor3 = style.color
		lbl.TextSize = 11.5
		lbl.Parent = frame

		return gui
	end)
	if okGui then
		billboard = createdGui
	end

	self.active[token] = {
		kind = style.key,
		beamHeight = style.beamHeight,
		folder = entryFolder,
		beaconPart = beaconPart,
		beaconAdornment = beaconAdornment,
		billboard = billboard,
		lastPos = pos,
	}

	if cfg.highlights.notify and not self.notified[token] and self.notifyFn then
		self.notified[token] = true
		local field = pos and getFieldAt(pos) or nil
		local fieldName = field and field.Name or "Unknown Field"
		self.notifyFn(style.notifyTitle, fieldName)
	end

	self:SyncFollowConnection()
end

function tokenHighlighter:Remove(token)
	if not token then
		return
	end
	local entry = self.active[token]
	if not entry then
		return
	end
	self.active[token] = nil
	if entry.folder then
		pcall(function()
			entry.folder:Destroy()
		end)
	end
	self:SyncFollowConnection()
end

function tokenHighlighter:Evaluate(token)
	if not token or not token.Parent then
		self:Remove(token)
		return
	end
	local style = self:GetHighlightStyle(token)
	if style then
		self:Apply(token, style)
	else
		self:Remove(token)
	end
end

function tokenHighlighter:RefreshAll()
	local folder = workspace:FindFirstChild("Collectibles")
	if not folder then
		local existing = {}
		for token in pairs(self.active) do
			table.insert(existing, token)
		end
		for _, token in ipairs(existing) do
			self:Remove(token)
		end
		return
	end
	local toRemove = {}
	for token in pairs(self.active) do
		if token.Parent ~= folder then
			table.insert(toRemove, token)
		end
	end
	for _, token in ipairs(toRemove) do
		self:Remove(token)
	end
	for _, token in ipairs(folder:GetChildren()) do
		self:Evaluate(token)
	end
end

function tokenHighlighter:Maintain()
	local existing = {}
	for token, entry in pairs(self.active) do
		table.insert(existing, { token = token, entry = entry })
	end
	for _, item in ipairs(existing) do
		local token = item.token
		local entry = item.entry
		if not token or not token.Parent then
			self:Remove(token)
		else
			local style = self:GetHighlightStyle(token)
			if not style then
				self:Remove(token)
			elseif style.key ~= entry.kind then
				self:Apply(token, style)
			else
				self:UpdateEntryVisuals(entry)
			end
		end
	end
end

function tokenHighlighter:ClearAll()
	connections:Cancel("highlightFollow")
	local existing = {}
	for token in pairs(self.active) do
		table.insert(existing, token)
	end
	for _, token in ipairs(existing) do
		self:Remove(token)
	end
	table.clear(self.notified)
	if self.rootFolder then
		pcall(function()
			self.rootFolder:Destroy()
		end)
		self.rootFolder = nil
	end
	local stray = workspace:FindFirstChild(HIGHLIGHT_FOLDER_NAME)
	if stray then
		pcall(function()
			stray:Destroy()
		end)
	end
end

-- Puffshroom parsing & transparency manager
local puffMetaCache = {}

local function extractRemainingTime(gui, cachedNumLabel)
	local numLabel = cachedNumLabel
	if not (numLabel and numLabel.Parent) and gui then
		for _, child in ipairs(gui:GetChildren()) do
			if child.Name == "BarRow" then
				local bar = child:FindFirstChild("Bar")
				local candidate = bar and bar:FindFirstChild("NumberLabel")
				if candidate and candidate.Text ~= nil then
					numLabel = candidate
					break
				end
			end
		end
	end

	local remainingSeconds = 0
	local timeText = "?"
	if numLabel and numLabel.Text ~= nil then
		local rawTime = tostring(numLabel.Text)
		timeText = rawTime
		local _, colonCount = string.gsub(rawTime, ":", "")
		if colonCount > 0 or string.find(rawTime, "s") then
			local minutesPart, secondsPart
			if colonCount == 1 then
				minutesPart, secondsPart = string.match(rawTime, "(%d+):(%d+)")
			else
				secondsPart = string.match(rawTime, "%d+")
			end
			if minutesPart then
				remainingSeconds += (tonumber(minutesPart) or 0) * 60
			end
			if secondsPart then
				remainingSeconds += tonumber(secondsPart) or 0
			end
		end
	end
	return remainingSeconds, timeText, numLabel
end

local function parsePuffshroom(puff)
	if not puff or not puff.Parent then
		puffMetaCache[puff] = nil
		return nil
	end
	local top = puff:FindFirstChild("Puffball Top")
	if not top then
		return nil
	end

	local cached = puffMetaCache[puff]
	if cached then
		local remainingSeconds, timeText, updatedNumLabel = extractRemainingTime(cached.gui, cached.numLabel)
		cached.numLabel = updatedNumLabel
		return {
			instance = puff,
			rarity = cached.rarity,
			level = cached.level,
			timeText = timeText,
			remainingSeconds = remainingSeconds,
			fieldName = cached.fieldName,
		}
	end

	local attachment = top:FindFirstChild("Attachment")
	local gui = attachment and attachment:FindFirstChild("Gui")
	local nameRow = gui and gui:FindFirstChild("NameRow")
	local textLabel = nameRow and nameRow:FindFirstChild("TextLabel")
	local titleText = textLabel and tostring(textLabel.Text or "") or ""

	local rawRarity = string.match(titleText, "(%a*)%s+Puffshroom")
	local rarity = (rawRarity and rawRarity ~= "") and rawRarity or "Common"
	local level = tonumber(string.match(titleText, "Lvl (%d+)")) or 1

	local remainingSeconds, timeText, numLabel = extractRemainingTime(gui, nil)

	local stem = puff:FindFirstChild("Puffball Stem")
	local pos = (stem and stem.Position) or top.Position
	local field = pos and getFieldAt(pos) or nil
	local fieldName = field and field.Name or "Unknown Field"

	if titleText ~= "" and field ~= nil then
		puffMetaCache[puff] = {
			rarity = rarity,
			level = level,
			fieldName = fieldName,
			gui = gui,
			numLabel = numLabel,
		}
	end

	return {
		instance = puff,
		rarity = rarity,
		level = level,
		timeText = timeText,
		remainingSeconds = remainingSeconds,
		fieldName = fieldName,
	}
end

local puffVisuals = {
	saved = {},
	appliedAlpha = {},
	appliedFadeGui = {},
	appliedHideParticles = {},
	appliedKeepSpores = {},
	descCache = {},
}

local function getTargetTransparency(rarity)
	if not cfg.puffshrooms.transparencyEnabled then
		return 0
	end
	if rarity == "Common" then
		return math.clamp(tonumber(cfg.puffshrooms.commonTransparency) or 0, 0, 1)
	elseif rarity == "Rare" then
		return math.clamp(tonumber(cfg.puffshrooms.rareTransparency) or 0, 0, 1)
	elseif rarity == "Epic" then
		return math.clamp(tonumber(cfg.puffshrooms.epicTransparency) or 0, 0, 1)
	end
	-- Legendary and Mythic puffshrooms always remain 100% visible
	return 0
end

local function restoreGuiRecord(record)
	for inst, props in pairs(record) do
		local isGuiBillboard = inst and inst:IsA("BillboardGui")
		for _, prop in ipairs({ "TextTransparency", "BackgroundTransparency", "ImageTransparency" }) do
			local origVal = props[prop]
			if origVal ~= nil then
				props[prop] = nil
				if inst and inst.Parent then
					pcall(function()
						inst[prop] = origVal
					end)
				end
			end
		end
		if isGuiBillboard and props.Enabled ~= nil then
			local origEnabled = props.Enabled
			props.Enabled = nil
			if inst and inst.Parent then
				pcall(function()
					inst.Enabled = origEnabled
				end)
			end
		end
	end
end

function puffVisuals:GetDescCache(puff)
	local cache = self.descCache[puff]
	if cache then
		return cache
	end
	cache = {
		parts = {},
		decals = {},
		emitters = {},
		billboards = {},
		textObjs = {},
		images = {},
		frames = {},
	}
	local targets = puff:GetDescendants()
	table.insert(targets, puff)
	for _, inst in ipairs(targets) do
		if inst:IsA("BasePart") then
			table.insert(cache.parts, inst)
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			table.insert(cache.decals, inst)
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
			table.insert(cache.emitters, inst)
		elseif inst:IsA("BillboardGui") then
			table.insert(cache.billboards, inst)
		elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
			table.insert(cache.textObjs, inst)
		elseif inst:IsA("ImageLabel") then
			table.insert(cache.images, inst)
		elseif inst:IsA("Frame") then
			table.insert(cache.frames, inst)
		end
	end
	self.descCache[puff] = cache
	return cache
end

function puffVisuals:Restore(puff)
	local record = self.saved[puff]
	self.appliedAlpha[puff] = nil
	self.appliedFadeGui[puff] = nil
	self.appliedHideParticles[puff] = nil
	self.appliedKeepSpores[puff] = nil
	self.descCache[puff] = nil
	if not record then
		return
	end
	self.saved[puff] = nil
	for inst, props in pairs(record) do
		if inst and inst.Parent then
			for prop, origVal in pairs(props) do
				pcall(function()
					inst[prop] = origVal
				end)
			end
		end
	end
end

function puffVisuals:Apply(puff, rarity)
	if not puff or not puff.Parent then
		self.saved[puff] = nil
		self.appliedAlpha[puff] = nil
		self.appliedFadeGui[puff] = nil
		self.appliedHideParticles[puff] = nil
		self.appliedKeepSpores[puff] = nil
		self.descCache[puff] = nil
		return
	end
	local alpha = getTargetTransparency(rarity)
	local fadeGui = alpha > 0 and cfg.puffshrooms.fadeGui == true
	local hideParticles = cfg.perf.filterParticles == true
	local keepSpores = cfg.perf.keepSporeTrails == true

	if alpha <= 0 and not hideParticles then
		self:Restore(puff)
		return
	end

	if self.appliedAlpha[puff] == alpha
		and self.appliedFadeGui[puff] == fadeGui
		and self.appliedHideParticles[puff] == hideParticles
		and self.appliedKeepSpores[puff] == keepSpores then
		return
	end

	local record = self.saved[puff]
	if not record then
		record = {}
		self.saved[puff] = record
	elseif self.appliedFadeGui[puff] and not fadeGui then
		restoreGuiRecord(record)
	end

	self.appliedAlpha[puff] = alpha
	self.appliedFadeGui[puff] = fadeGui
	self.appliedHideParticles[puff] = hideParticles
	self.appliedKeepSpores[puff] = keepSpores

	local cache = self:GetDescCache(puff)

	for _, inst in ipairs(cache.parts) do
		local origMod = record[inst] and record[inst].LocalTransparencyModifier
		if origMod == nil then
			local ok, val = pcall(function() return inst.LocalTransparencyModifier end)
			origMod = ok and val or 0
			record[inst] = record[inst] or {}
			record[inst].LocalTransparencyModifier = origMod
		end
		pcall(function()
			inst.LocalTransparencyModifier = math.clamp(origMod + alpha * (1 - origMod), 0, 1)
		end)
	end

	for _, inst in ipairs(cache.decals) do
		local orig = record[inst] and record[inst].Transparency
		if orig == nil then
			local ok, val = pcall(function() return inst.Transparency end)
			orig = ok and val or 0
			record[inst] = record[inst] or {}
			record[inst].Transparency = orig
		end
		pcall(function()
			inst.Transparency = math.clamp(orig + alpha * (1 - orig), 0, 1)
		end)
	end

	for _, inst in ipairs(cache.emitters) do
		local orig = record[inst] and record[inst].Enabled
		if orig == nil then
			local ok, val = pcall(function() return inst.Enabled end)
			orig = ok and val or true
			record[inst] = record[inst] or {}
			record[inst].Enabled = orig
		end
		local disableForParticleFilter = hideParticles and not (inst.Name == "PuffshroomSpores" and keepSpores)
		pcall(function()
			inst.Enabled = (alpha < 0.95 and not disableForParticleFilter) and orig or false
		end)
	end

	if fadeGui then
		for _, inst in ipairs(cache.billboards) do
			local orig = record[inst] and record[inst].Enabled
			if orig == nil then
				local ok, val = pcall(function() return inst.Enabled end)
				orig = ok and val or true
				record[inst] = record[inst] or {}
				record[inst].Enabled = orig
			end
			pcall(function()
				inst.Enabled = alpha < 1 and orig or false
			end)
		end
		for _, inst in ipairs(cache.textObjs) do
			local orig = record[inst] and record[inst].TextTransparency
			if orig == nil then
				local ok, val = pcall(function() return inst.TextTransparency end)
				orig = ok and val or 0
				record[inst] = record[inst] or {}
				record[inst].TextTransparency = orig
			end
			pcall(function()
				inst.TextTransparency = math.clamp(orig + alpha * (1 - orig), 0, 1)
			end)
		end
		for _, inst in ipairs(cache.images) do
			local origImg = record[inst] and record[inst].ImageTransparency
			if origImg == nil then
				local ok, val = pcall(function() return inst.ImageTransparency end)
				origImg = ok and val or 0
				record[inst] = record[inst] or {}
				record[inst].ImageTransparency = origImg
			end
			pcall(function()
				inst.ImageTransparency = math.clamp(origImg + alpha * (1 - origImg), 0, 1)
			end)
		end
		for _, inst in ipairs(cache.frames) do
			local origBg = record[inst] and record[inst].BackgroundTransparency
			if origBg == nil then
				local ok, val = pcall(function() return inst.BackgroundTransparency end)
				origBg = ok and val or 1
				record[inst] = record[inst] or {}
				record[inst].BackgroundTransparency = origBg
			end
			if origBg < 1 then
				pcall(function()
					inst.BackgroundTransparency = math.clamp(origBg + alpha * (1 - origBg), 0, 1)
				end)
			end
		end
	end
end

function puffVisuals:RestoreAll()
	for puff in pairs(self.saved) do
		self:Restore(puff)
	end
end

-- Atlas+ GUI Construction
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AtlasPuffshroomAssistant"
ScreenGui.ScreenInsets = Enum.ScreenInsets.None
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = gethui and gethui() or getService("CoreGui")

local ui = {}
local uiParts = {}
local controls = {}
local monitorState = {
	counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 },
	total = 0,
	mythics = {},
	notified = {},
}

local color_ = Color3.fromRGB(16, 18, 24)
local color_2 = Color3.fromRGB(22, 25, 33)
local color_3 = Color3.fromRGB(30, 34, 45)
local color_4 = Color3.fromRGB(38, 43, 56)
local color_5 = Color3.fromRGB(58, 66, 86)
local uicolor = _G.uicolor or Color3.fromRGB(59, 130, 246)
local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local mythicPurple = Color3.fromRGB(168, 85, 247)
local mythicTextColor = Color3.fromRGB(233, 213, 255)
local mythicDotColor = Color3.fromRGB(192, 132, 252)

local viewportSize = Vector2.new(1280, 720)
pcall(function()
	if ScreenGui.AbsoluteSize and ScreenGui.AbsoluteSize.X > 0 then
		viewportSize = ScreenGui.AbsoluteSize
	elseif workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X > 0 then
		viewportSize = workspace.CurrentCamera.ViewportSize
	end
end)
local isDesktop = _G.desktop ~= nil and _G.desktop or (viewportSize.X >= 850 and viewportSize.Y >= 500)

local minWindowSize = isDesktop and Vector2.new(620, 360) or Vector2.new(440, 280)
local windowSize = minWindowSize
local dragState = nil

connections:Add("drag", UserInputService.InputChanged:Connect(function(inputObj)
	if dragState and (inputObj.UserInputType == Enum.UserInputType.MouseMovement or inputObj.UserInputType == Enum.UserInputType.Touch) then
		for target, stateVal in pairs(dragState) do
			if stateVal == "resize" then
				local w = math.max(minWindowSize.X, inputObj.Position.X - target.AbsolutePosition.X)
				local h = math.max(minWindowSize.Y, inputObj.Position.Y - target.AbsolutePosition.Y)
				target.Size = UDim2.new(0, w, 0, h)
				windowSize = Vector2.new(w, h)
			elseif stateVal == "slider" then
				target(inputObj)
			else
				local startPos = stateVal[2]
				local delta = inputObj.Position - stateVal[1]
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end
	end
end))

connections:Add("stopdrag", UserInputService.InputEnded:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		dragState = nil
	end
end))

-- Main Atlas+ Window
local window = _G.background and Instance.new("ImageLabel") or Instance.new("Frame")
window.Name = "Window"
window.Active = true
window.BackgroundColor3 = color_
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Position = UDim2.new(0, 20, 0, 95)
window.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
if _G.background then
	window.Image = _G.background
end
window.Parent = ScreenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 8)
windowCorner.Parent = window

local windowStroke = Instance.new("UIStroke")
windowStroke.Thickness = 1
windowStroke.Color = Color3.fromRGB(54, 62, 82)
windowStroke.Transparency = 0.35
windowStroke.Parent = window

-- Shared Atlas+ UI Templates
do
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = uicolor
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, 25)
	uiParts.bar = bar

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar

	local barTitle = Instance.new("TextLabel")
	barTitle.Name = "Title"
	barTitle.BackgroundTransparency = 1
	barTitle.Font = Enum.Font.GothamBold
	barTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	barTitle.TextSize = 13.5
	barTitle.TextXAlignment = Enum.TextXAlignment.Left
	barTitle.Position = UDim2.new(0, 10, 0, 0)
	barTitle.Size = UDim2.new(0.8, -10, 0, 25)
	barTitle.Parent = bar

	local barIndicator = Instance.new("TextButton")
	barIndicator.Name = "Indicator"
	barIndicator.AutoButtonColor = false
	barIndicator.BackgroundTransparency = 1
	barIndicator.Font = Enum.Font.GothamBold
	barIndicator.Text = "▾"
	barIndicator.TextColor3 = Color3.new(1, 1, 1)
	barIndicator.TextSize = 14
	barIndicator.Position = UDim2.new(1, -26, 0, 2)
	barIndicator.Size = UDim2.new(0, 20, 0, 20)
	barIndicator.Parent = bar

	local barBottom = Instance.new("Frame")
	barBottom.Name = "Frame"
	barBottom.BackgroundColor3 = uicolor
	barBottom.BorderSizePixel = 0
	barBottom.Position = UDim2.new(0, 0, 0.85, 0)
	barBottom.Size = UDim2.new(1, 0, 0, 4)
	barBottom.Parent = bar

	local tabBtn = Instance.new("TextButton")
	tabBtn.AutoButtonColor = false
	tabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabBtn.BackgroundTransparency = 0.96
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextColor3 = Color3.fromRGB(237, 237, 237)
	tabBtn.TextSize = 11.5
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left
	tabBtn.Size = UDim2.new(1, 0, 0, 23)
	uiParts.tabbutton = tabBtn

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 5)
	tabCorner.Parent = tabBtn

	local tabIcon = Instance.new("ImageLabel")
	tabIcon.Name = "TabIcon"
	tabIcon.BackgroundTransparency = 1
	tabIcon.Position = UDim2.new(0, 5, 0, 5)
	tabIcon.Size = UDim2.new(0, 12, 0, 12)
	tabIcon.Parent = tabBtn

	local tabContainer = Instance.new("Frame")
	tabContainer.BackgroundTransparency = 1
	tabContainer.BorderSizePixel = 0
	tabContainer.Size = UDim2.new(1, -5, 1, 0)
	uiParts.tab = tabContainer

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabContainer

	local folder = Instance.new("Frame")
	folder.Name = "Folder"
	folder.BackgroundTransparency = 1
	folder.BorderSizePixel = 0
	folder.Size = UDim2.new(1, 0, 0, 23)
	uiParts.folder = folder

	local folderBtn = Instance.new("TextButton")
	folderBtn.Name = "TextButton"
	folderBtn.AutoButtonColor = false
	folderBtn.BackgroundColor3 = color_3
	folderBtn.BorderSizePixel = 0
	folderBtn.Font = Enum.Font.GothamBold
	folderBtn.TextColor3 = Color3.fromRGB(228, 232, 240)
	folderBtn.TextSize = 12.5
	folderBtn.TextXAlignment = Enum.TextXAlignment.Left
	folderBtn.Size = UDim2.new(1, 0, 0, 23)
	folderBtn.Parent = folder

	local folderCorner = Instance.new("UICorner")
	folderCorner.Name = "UICorner"
	folderCorner.CornerRadius = UDim.new(0, 5)
	folderCorner.Parent = folderBtn

	local folderIndicator = Instance.new("TextLabel")
	folderIndicator.Name = "Indicator"
	folderIndicator.BackgroundTransparency = 1
	folderIndicator.Font = Enum.Font.GothamBold
	folderIndicator.Text = "▸"
	folderIndicator.TextColor3 = Color3.fromRGB(180, 190, 210)
	folderIndicator.TextSize = 12
	folderIndicator.Position = UDim2.new(1, -24, 0, 1)
	folderIndicator.Size = UDim2.new(0, 20, 0, 20)
	folderIndicator.Parent = folderBtn

	local folderBox = Instance.new("Frame")
	folderBox.Name = "Box"
	folderBox.BackgroundColor3 = color_2
	folderBox.BackgroundTransparency = 1
	folderBox.BorderSizePixel = 0
	folderBox.ClipsDescendants = true
	folderBox.Position = UDim2.new(0, 0, 0, 21)
	folderBox.Size = UDim2.new(1, 0, 1, -21)
	folderBox.Parent = folder

	local boxCorner = Instance.new("UICorner")
	boxCorner.Name = "UICorner"
	boxCorner.CornerRadius = UDim.new(0, 5)
	boxCorner.Parent = folderBox

	local boxLayout = Instance.new("UIListLayout")
	boxLayout.SortOrder = Enum.SortOrder.LayoutOrder
	boxLayout.Padding = UDim.new(0, 4)
	boxLayout.Parent = folderBox

	local boxPadding = Instance.new("UIPadding")
	boxPadding.Name = "UIPadding"
	boxPadding.PaddingTop = UDim.new(0, 12)
	boxPadding.PaddingLeft = UDim.new(0, 10)
	boxPadding.Parent = folderBox

	local folderBridge = Instance.new("Frame")
	folderBridge.Name = "Frame"
	folderBridge.BackgroundColor3 = color_3
	folderBridge.BorderSizePixel = 0
	folderBridge.Position = UDim2.new(0, 0, 0, 18)
	folderBridge.Size = UDim2.new(1, 0, 0, 5)
	folderBridge.Visible = false
	folderBridge.Parent = folder

	local btnTemplate = Instance.new("TextButton")
	btnTemplate.Name = "Button"
	btnTemplate.AutoButtonColor = false
	btnTemplate.BackgroundColor3 = uicolor
	btnTemplate.BorderSizePixel = 0
	btnTemplate.ClipsDescendants = true
	btnTemplate.Font = Enum.Font.GothamBold
	btnTemplate.TextColor3 = Color3.new(1, 1, 1)
	btnTemplate.TextSize = 12.5
	btnTemplate.Size = UDim2.new(0, 130, 0, 20)
	uiParts.button = btnTemplate

	local btnCorner = Instance.new("UICorner")
	btnCorner.Name = "UICorner"
	btnCorner.CornerRadius = UDim.new(0, 5)
	btnCorner.Parent = btnTemplate

	local labelTemplate = Instance.new("TextLabel")
	labelTemplate.Name = "Label"
	labelTemplate.BackgroundTransparency = 1
	labelTemplate.Font = Enum.Font.GothamSemibold
	labelTemplate.TextColor3 = Color3.fromRGB(225, 230, 240)
	labelTemplate.TextSize = 12
	labelTemplate.TextXAlignment = Enum.TextXAlignment.Left
	labelTemplate.TextTruncate = Enum.TextTruncate.AtEnd
	uiParts.label = labelTemplate

	local switchTemplate = Instance.new("TextButton")
	switchTemplate.Name = "Switch"
	switchTemplate.AutoButtonColor = false
	switchTemplate.BackgroundTransparency = 1
	switchTemplate.BorderSizePixel = 0
	switchTemplate.Text = ""
	switchTemplate.Size = UDim2.new(1, -20, 0, 20)
	uiParts.switch = switchTemplate

	local switchTrack = Instance.new("Frame")
	switchTrack.Name = "Switch"
	switchTrack.BackgroundColor3 = color_4
	switchTrack.BackgroundTransparency = 0
	switchTrack.BorderSizePixel = 0
	switchTrack.Position = UDim2.new(0, 0, 0.5, -8)
	switchTrack.Size = UDim2.new(0, 32, 0, 16)
	switchTrack.Parent = switchTemplate

	local switchCorner = Instance.new("UICorner")
	switchCorner.Name = "UICorner"
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = switchTrack

	local switchKnob = Instance.new("Frame")
	switchKnob.Name = "Knob"
	switchKnob.BackgroundColor3 = Color3.fromRGB(235, 240, 248)
	switchKnob.BorderSizePixel = 0
	switchKnob.Position = UDim2.new(0, 2, 0.5, -6)
	switchKnob.Size = UDim2.new(0, 12, 0, 12)
	switchKnob.Parent = switchTrack

	local knobCorner = Instance.new("UICorner")
	knobCorner.Name = "UICorner"
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = switchKnob

	local switchTitle = Instance.new("TextLabel")
	switchTitle.Name = "Title"
	switchTitle.BackgroundTransparency = 1
	switchTitle.Position = UDim2.new(0, 42, 0, 0)
	switchTitle.Size = UDim2.new(1, -42, 0, 20)
	switchTitle.Font = Enum.Font.GothamSemibold
	switchTitle.TextColor3 = Color3.fromRGB(205, 212, 224)
	switchTitle.TextSize = 12.5
	switchTitle.TextXAlignment = Enum.TextXAlignment.Left
	switchTitle.TextTruncate = Enum.TextTruncate.AtEnd
	switchTitle.Parent = switchTemplate

	local sliderTemplate = Instance.new("Frame")
	sliderTemplate.Name = "Slider"
	sliderTemplate.BackgroundColor3 = color_4
	sliderTemplate.BorderSizePixel = 0
	sliderTemplate.ClipsDescendants = true
	sliderTemplate.Size = UDim2.new(1, -15, 0, 20)
	uiParts.slider = sliderTemplate

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.Name = "UICorner"
	sliderCorner.CornerRadius = UDim.new(0, 5)
	sliderCorner.Parent = sliderTemplate

	local sliderStroke = Instance.new("UIStroke")
	sliderStroke.Thickness = 1
	sliderStroke.Color = color_5
	sliderStroke.Transparency = 0.35
	sliderStroke.Parent = sliderTemplate

	local sliderHitbox = Instance.new("TextButton")
	sliderHitbox.Name = "Button"
	sliderHitbox.BackgroundTransparency = 1
	sliderHitbox.Text = ""
	sliderHitbox.Size = UDim2.new(1, 0, 1, 0)
	sliderHitbox.ZIndex = 2
	sliderHitbox.Parent = sliderTemplate

	local sliderIndicator = Instance.new("Frame")
	sliderIndicator.Name = "Indicator"
	sliderIndicator.BackgroundColor3 = uicolor
	sliderIndicator.BackgroundTransparency = 0.18
	sliderIndicator.BorderSizePixel = 0
	sliderIndicator.Size = UDim2.new(0, 0, 1, 0)
	sliderIndicator.Parent = sliderTemplate

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.Name = "UICorner"
	indicatorCorner.CornerRadius = UDim.new(0, 5)
	indicatorCorner.Parent = sliderIndicator

	local sliderTitle = Instance.new("TextLabel")
	sliderTitle.Name = "Title"
	sliderTitle.BackgroundTransparency = 1
	sliderTitle.Font = Enum.Font.GothamBold
	sliderTitle.TextColor3 = Color3.fromRGB(232, 236, 244)
	sliderTitle.TextSize = 12.5
	sliderTitle.TextXAlignment = Enum.TextXAlignment.Center
	sliderTitle.Position = UDim2.new(0.5, 0, 0.5, -10)
	sliderTitle.Size = UDim2.new(0, 0, 0, 20)
	sliderTitle.ZIndex = 3
	sliderTitle.Parent = sliderTemplate

	local sliderValue = Instance.new("TextLabel")
	sliderValue.Name = "Value"
	sliderValue.BackgroundTransparency = 1
	sliderValue.Font = Enum.Font.GothamBold
	sliderValue.Text = "0"
	sliderValue.TextColor3 = Color3.fromRGB(232, 236, 244)
	sliderValue.TextSize = 12.5
	sliderValue.Position = UDim2.new(1, -45, 0.5, -10)
	sliderValue.Size = UDim2.new(0, 40, 0, 20)
	sliderValue.TextXAlignment = Enum.TextXAlignment.Right
	sliderValue.ZIndex = 3
	sliderValue.Parent = sliderTemplate
end

-- Top bar for main window
local tabButtonsHolder = nil
local activeTabFrame = nil
local activeTabFrame2 = nil
local activeTabButton = nil
local windowVisible = true
do
	local bar = uiParts.bar:Clone()
	local indicator = bar.Indicator
	bar.Title.Text = "Atlas+ Puffshroom Assistant"
	bar.Parent = window

	bar.InputBegan:Connect(function(inputObj)
		if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
			if not dragState then
				dragState = {}
			end
			dragState[window] = { inputObj.Position, window.Position }
		end
	end)

	indicator.MouseButton1Click:Connect(function()
		windowVisible = not windowVisible
		bar.Frame.Visible = windowVisible
		indicator.Text = windowVisible and "▾" or "▸"
		TweenService:Create(window, TWEEN_FAST, {
			Size = windowVisible and UDim2.new(0, windowSize.X, 0, windowSize.Y) or UDim2.new(0, windowSize.X, 0, 25),
		}):Play()
		tabButtonsHolder.Visible = windowVisible
		if activeTabFrame then
			activeTabFrame.Visible = windowVisible
		end
		if activeTabFrame2 then
			activeTabFrame2.Visible = windowVisible
		end
	end)
end

-- Mobile Toggle Button
local mobileBtn = Instance.new("ImageButton")
mobileBtn.Name = "Button"
mobileBtn.BackgroundTransparency = 1
mobileBtn.Image = "rbxasset://textures/ui/TopBar/iconBase.png"
mobileBtn.Position = UDim2.new(0.5, -22, 0, 56)
mobileBtn.Size = UDim2.new(0, 44, 0, 44)
mobileBtn.Visible = cfg.misc.mobiletoggle
mobileBtn.Parent = ScreenGui

local mobileCorner = Instance.new("UICorner")
mobileCorner.CornerRadius = UDim.new(0, 6)
mobileCorner.Parent = mobileBtn

local mobileIcon = Instance.new("ImageLabel")
mobileIcon.Name = "Image"
mobileIcon.BackgroundTransparency = 1
mobileIcon.Image = "rbxassetid://120901539385431"
mobileIcon.Position = UDim2.new(0, 8, 0, 8)
mobileIcon.Size = UDim2.new(0, 28, 0, 28)
mobileIcon.Parent = mobileBtn

mobileBtn.InputBegan:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		if not dragState then
			dragState = {}
		end
		dragState[mobileBtn] = { inputObj.Position, mobileBtn.Position }
	end
end)

mobileBtn.MouseButton1Click:Connect(function()
	window.Visible = not window.Visible
end)

-- Sidebar & Tab Area
tabButtonsHolder = Instance.new("Frame")
tabButtonsHolder.Name = "TabButtons"
tabButtonsHolder.BackgroundColor3 = color_2
tabButtonsHolder.BackgroundTransparency = isDesktop and 0 or 1
tabButtonsHolder.BorderSizePixel = 0
tabButtonsHolder.Position = UDim2.new(0, 0, 0, 25)
tabButtonsHolder.Size = UDim2.new(0, 90, 1, -25)
tabButtonsHolder.Parent = window

if isDesktop then
	local sideCorner = Instance.new("UICorner")
	sideCorner.CornerRadius = UDim.new(0, 5)
	sideCorner.Parent = tabButtonsHolder
end
if _G.background then
	tabButtonsHolder.BackgroundTransparency = 0.5
end

local tabListScroll = Instance.new("ScrollingFrame")
tabListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabListScroll.BackgroundTransparency = 1
tabListScroll.BorderSizePixel = 0
tabListScroll.CanvasSize = UDim2.new()
tabListScroll.ScrollBarThickness = 0
tabListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
tabListScroll.Position = UDim2.new(0, 5, 0, 5)
tabListScroll.Size = UDim2.new(1, -10, 1, -10)
tabListScroll.Parent = tabButtonsHolder

local tabListLayout = Instance.new("UIListLayout")
tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabListLayout.Padding = UDim.new(0, 4)
tabListLayout.Parent = tabListScroll

local resizeHandle = Instance.new("Frame")
resizeHandle.Name = "Resize"
resizeHandle.BackgroundTransparency = 1
resizeHandle.BorderSizePixel = 0
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.ZIndex = 2
resizeHandle.Parent = window

resizeHandle.InputBegan:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		if not dragState then
			dragState = {}
		end
		dragState[window] = "resize"
	end
end)

local searchBoxFrame = Instance.new("Frame")
searchBoxFrame.Name = "SearchBox"
searchBoxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
searchBoxFrame.BackgroundTransparency = 0.96
searchBoxFrame.BorderSizePixel = 0
searchBoxFrame.Size = UDim2.new(1, 0, 0, 23)
searchBoxFrame.Parent = tabListScroll

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 4)
searchCorner.Parent = searchBoxFrame

local searchBox = Instance.new("TextBox")
searchBox.BackgroundTransparency = 1
searchBox.Font = Enum.Font.GothamBold
searchBox.PlaceholderText = "Search"
searchBox.PlaceholderColor3 = Color3.fromRGB(237, 237, 237)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(237, 237, 237)
searchBox.TextSize = 11.5
searchBox.Position = UDim2.new(0, 18, 0, 0)
searchBox.Size = UDim2.new(1, -18, 0, 23)
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.Parent = searchBoxFrame

local searchIcon = Instance.new("ImageLabel")
searchIcon.Name = "SearchIcon"
searchIcon.BackgroundTransparency = 1
searchIcon.Image = "rbxassetid://10734943674"
searchIcon.Position = UDim2.new(0, 5, 0, 5)
searchIcon.Size = UDim2.new(0, 12, 0, 12)
searchIcon.Parent = searchBoxFrame

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, 0, 0, 2)
divider.Parent = tabListScroll

activeTabFrame = nil
activeTabFrame2 = nil
activeTabButton = nil
local searchableItems = {}

searchBox.Changed:Connect(function()
	local q = string.lower(searchBox.Text)
	if #q > 0 then
		for _, child in ipairs(tabListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child.Visible = string.find(string.lower(child.Text), q, 1, true) ~= nil
			end
		end
		for _, entry in ipairs(searchableItems) do
			if string.find(string.lower(entry[1]), q, 1, true) then
				entry[2].Visible = true
			end
		end
	else
		for _, child in ipairs(tabListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child.Visible = true
			end
		end
	end
end)

ui.Notify = function(title, description)
	local existing = ScreenGui:FindFirstChild("Tooltip")
	if existing then
		existing:Destroy()
	end
	local _, newlineCount = string.gsub(tostring(description), "\n", " ")
	local toast = Instance.new("Frame")
	toast.Name = "Tooltip"
	toast.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	toast.BackgroundTransparency = 0.06
	toast.BorderSizePixel = 0
	toast.ClipsDescendants = true
	toast.AnchorPoint = Vector2.new(1, 1)
	toast.Position = UDim2.new(1, -8, 1, -8)
	toast.Size = UDim2.new(0, newlineCount == 2 and 272 or 262, 0, newlineCount == 2 and 78 or 58)
	toast.Parent = ScreenGui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 7)
	toastCorner.Parent = toast

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Thickness = 1.2
	toastStroke.Color = uicolor
	toastStroke.Transparency = 0.25
	toastStroke.Parent = toast

	local toastAccent = Instance.new("Frame")
	toastAccent.Name = "Accent"
	toastAccent.BackgroundColor3 = uicolor
	toastAccent.BorderSizePixel = 0
	toastAccent.Size = UDim2.new(0, 3, 1, 0)
	toastAccent.Parent = toast

	local tTitle = Instance.new("TextLabel")
	tTitle.Name = "Title"
	tTitle.BackgroundTransparency = 1
	tTitle.Font = Enum.Font.GothamBold
	tTitle.Text = tostring(title)
	tTitle.TextColor3 = Color3.new(1, 1, 1)
	tTitle.TextSize = 13.5
	tTitle.TextXAlignment = Enum.TextXAlignment.Left
	tTitle.Position = UDim2.new(0, 14, 0, newlineCount > 0 and 8 or 9)
	tTitle.Size = UDim2.new(1, -22, 0, 19)
	tTitle.Parent = toast

	local tDesc = Instance.new("TextLabel")
	tDesc.Name = "Description"
	tDesc.BackgroundTransparency = 1
	tDesc.Font = Enum.Font.GothamSemibold
	tDesc.Text = tostring(description)
	tDesc.TextColor3 = Color3.fromRGB(205, 212, 224)
	tDesc.TextSize = 12.5
	tDesc.TextXAlignment = Enum.TextXAlignment.Left
	tDesc.TextTruncate = Enum.TextTruncate.AtEnd
	tDesc.Position = UDim2.new(0, 14, 0, newlineCount == 2 and 37 or 29)
	tDesc.Size = UDim2.new(1, -22, 0, 19)
	tDesc.Parent = toast

	threads:Add("Tooltip", function()
		task.wait(4)
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
end

tokenHighlighter.notifyFn = ui.Notify

ui.AddTab = function(tabName, image, twoColumn, startActive)
	local tabBtn = uiParts.tabbutton:Clone()
	tabBtn.Name = "TabButton_" .. tabName
	tabBtn.Text = "        " .. tabName
	tabBtn.TabIcon.Image = image
	tabBtn.Parent = tabListScroll

	local scrollLeft = Instance.new("ScrollingFrame")
	scrollLeft.Name = "Tab"
	scrollLeft.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollLeft.BackgroundTransparency = 1
	scrollLeft.BorderSizePixel = 0
	scrollLeft.CanvasSize = UDim2.new()
	scrollLeft.ScrollBarThickness = 5
	scrollLeft.ScrollBarImageTransparency = 1
	scrollLeft.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollLeft.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scrollLeft.Position = UDim2.new(0, 95, 0, 30)
	scrollLeft.Size = UDim2.new(1, -95, 1, -30)

	local padLeft = Instance.new("UIPadding")
	padLeft.PaddingBottom = UDim.new(0, 5)
	padLeft.Parent = scrollLeft

	local colLeft = uiParts.tab:Clone()
	colLeft.Parent = scrollLeft

	local scrollRight, colRight
	if isDesktop and twoColumn then
		scrollRight = Instance.new("ScrollingFrame")
		scrollRight.Name = "Tab2"
		scrollRight.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollRight.BackgroundTransparency = 1
		scrollRight.BorderSizePixel = 0
		scrollRight.CanvasSize = UDim2.new()
		scrollRight.ScrollBarThickness = 5
		scrollRight.ScrollBarImageTransparency = 1
		scrollRight.ScrollingDirection = Enum.ScrollingDirection.Y
		scrollRight.VerticalScrollBarInset = Enum.ScrollBarInset.None
		scrollRight.Position = UDim2.new(0.5, 47.5, 0, 30)
		scrollLeft.Size = UDim2.new(0.5, -47.5, 1, -30)
		scrollRight.Size = scrollLeft.Size

		local padRight = Instance.new("UIPadding")
		padRight.PaddingBottom = UDim.new(0, 5)
		padRight.Parent = scrollRight

		colRight = uiParts.tab:Clone()
		colRight.Parent = scrollRight
	end

	tabBtn.MouseEnter:Connect(function()
		if activeTabButton ~= tabBtn then
			TweenService:Create(tabBtn, TWEEN_FAST, { BackgroundTransparency = 0.93 }):Play()
		end
	end)

	tabBtn.MouseLeave:Connect(function()
		if activeTabButton ~= tabBtn then
			TweenService:Create(tabBtn, TWEEN_FAST, { BackgroundTransparency = 0.96 }):Play()
		end
	end)

	tabBtn.MouseButton1Click:Connect(function()
		if activeTabFrame and activeTabButton ~= tabBtn then
			activeTabFrame.Parent = nil
			if activeTabFrame2 then
				activeTabFrame2.Parent = nil
			end
			TweenService:Create(activeTabButton, TWEEN_FAST, { BackgroundTransparency = 0.96 }):Play()
			TweenService:Create(tabBtn, TWEEN_FAST, { BackgroundTransparency = 0.85 }):Play()
			scrollLeft.Visible = windowVisible
			scrollLeft.Parent = window
			activeTabButton = tabBtn
			activeTabFrame = scrollLeft
			activeTabFrame2 = scrollRight
			if scrollRight then
				scrollRight.Visible = windowVisible
				scrollRight.Parent = window
			end
		end
	end)

	if startActive then
		tabBtn.BackgroundTransparency = 0.85
		scrollLeft.Visible = windowVisible
		scrollLeft.Parent = window
		activeTabButton = tabBtn
		activeTabFrame = scrollLeft
		if scrollRight then
			scrollRight.Visible = windowVisible
			scrollRight.Parent = window
			activeTabFrame2 = scrollRight
		end
	end

	local tabApi = {}
	tabApi.AddFolder = function(folderName, useRightColumn)
		local folderApi = {}
		local isOpen = false
		local measuredOnce = nil
		local folderFrame = uiParts.folder:Clone()
		local headerBtn = folderFrame.TextButton
		local box = folderFrame.Box

		if _G.background then
			folderFrame.BackgroundColor3 = color_2
			folderFrame.BackgroundTransparency = 0.4
			if _G.uicolor then
				folderFrame.Frame.BackgroundColor3 = _G.uicolor
				headerBtn.BackgroundColor3 = _G.uicolor
			end
		end

		headerBtn.Text = "   " .. folderName
		folderFrame.Parent = (isDesktop and useRightColumn and colRight) or colLeft

		folderApi.AddLabel = function(text)
			local lbl = uiParts.label:Clone()
			lbl.Text = text
			lbl.Size = UDim2.new(1, -10, 0, 17)
			lbl.Parent = box
			table.insert(searchableItems, { text, tabBtn })
			return lbl
		end

		folderApi.AddButton = function(text, callback, width)
			table.insert(searchableItems, { text, tabBtn })
			local btn = uiParts.button:Clone()
			if width then
				btn.Size = UDim2.new(0, width, 0, 20)
			end
			btn.Text = text
			btn.Parent = box
			btn.MouseButton1Click:Connect(function()
				if callback then
					callback()
				end
			end)
			return btn
		end

		folderApi.AddSwitch = function(text, callback, configSource, configKey)
			local switchApi = {}
			local row = uiParts.switch:Clone()
			local track = row.Switch
			local knob = track.Knob
			local titleLabel = row.Title
			titleLabel.Text = text
			row.Parent = box

			local function renderSwitch(state, instant)
				local targetColor = state and uicolor or color_4
				local targetPos = state and UDim2.new(0, 18, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
				local targetTitleColor = state and Color3.fromRGB(235, 240, 248) or Color3.fromRGB(205, 212, 224)
				titleLabel.TextColor3 = targetTitleColor
				if instant then
					track.BackgroundColor3 = targetColor
					knob.Position = targetPos
				else
					TweenService:Create(track, TWEEN_FAST, { BackgroundColor3 = targetColor }):Play()
					TweenService:Create(knob, TWEEN_FAST, { Position = targetPos }):Play()
				end
			end

			local isOn = false
			local configTable = (configSource and type(configSource) == "string" and cfg[configSource]) or configSource
			if configTable and configTable[configKey] then
				isOn = true
				renderSwitch(true, true)
				if callback then
					callback(true)
				end
			else
				renderSwitch(false, true)
			end

			row.MouseButton1Click:Connect(function()
				isOn = not isOn
				renderSwitch(isOn, false)
				if configTable then
					configTable[configKey] = isOn
					saveConfig()
				end
				if callback then
					callback(isOn)
				end
			end)

			switchApi.Set = function(newState, skipCallback)
				isOn = newState == true
				renderSwitch(isOn, true)
				if configTable then
					configTable[configKey] = isOn
					saveConfig()
				end
				if callback and not skipCallback then
					callback(isOn)
				end
			end

			switchApi.SetVisible = function(v)
				row.Visible = v
			end

			table.insert(searchableItems, { text, tabBtn })
			return switchApi
		end

		folderApi.AddSlider = function(sliderTitle, callback, minValue, maxValue, configSource, configKey, options)
			table.insert(searchableItems, { sliderTitle, tabBtn })
			local sliderApi = {}
			local sliderRow = uiParts.slider:Clone()
			sliderRow.Parent = box
			local hitbox = sliderRow.Button
			local indicator = sliderRow.Indicator
			local valueLabel = sliderRow.Value
			local left = options and options.Left
			local decimal = options and options.Decimal
			local configTable = (configSource and type(configSource) == "string" and cfg[configSource]) or configSource
			local titleLabel = sliderRow.Title
			titleLabel.Text = left and ("   " .. sliderTitle) or sliderTitle
			if left then
				titleLabel.TextXAlignment = Enum.TextXAlignment.Left
				titleLabel.Position = UDim2.new(0, 0, 0.5, -10)
			end

			local lastValue = nil
			local function formatSliderVal(raw)
				local clamped = math.clamp(raw, minValue, maxValue)
				return decimal and (math.round(clamped * 10) / 10) or math.floor(clamped)
			end

			local function updateFromInput(inputObj)
				local width = sliderRow.AbsoluteSize.X
				if width <= 0 then
					return
				end
				local px = math.clamp(inputObj.Position.X - sliderRow.AbsolutePosition.X, 0, width)
				local ratio = px / width
				local val = formatSliderVal(minValue + ratio * (maxValue - minValue))
				local fillRatio = (maxValue > minValue) and math.clamp((val - minValue) / (maxValue - minValue), 0, 1) or 0
				indicator.Size = UDim2.new(fillRatio, 0, 1, 0)
				valueLabel.Text = tostring(val)
				if configTable then
					configTable[configKey] = val
					saveConfig()
				end
				local prev = lastValue
				lastValue = val
				if callback and prev ~= val then
					callback(val)
				end
			end

			hitbox.InputBegan:Connect(function(inputObj)
				if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
					if not dragState then
						dragState = {}
					end
					dragState[updateFromInput] = "slider"
					updateFromInput(inputObj)
				end
			end)

			sliderApi.Set = function(newValue, skipCallback)
				local val = formatSliderVal(tonumber(newValue) or minValue)
				local fillRatio = (maxValue > minValue) and math.clamp((val - minValue) / (maxValue - minValue), 0, 1) or 0
				indicator.Size = UDim2.new(fillRatio, 0, 1, 0)
				valueLabel.Text = tostring(val)
				if configTable then
					configTable[configKey] = val
					saveConfig()
				end
				local prev = lastValue
				lastValue = val
				if callback and not skipCallback and prev ~= nil and prev ~= val then
					callback(val)
				end
			end

			sliderApi.SetVisible = function(v)
				sliderRow.Visible = v
			end

			sliderApi.SetTitle = function(newTitle)
				titleLabel.Text = left and ("   " .. newTitle) or newTitle
			end

			if configTable and configTable[configKey] ~= nil then
				sliderApi.Set(configTable[configKey], true)
			else
				sliderApi.Set(minValue, true)
			end

			return sliderApi
		end

		folderApi.Toggle = function(openState, desktopOnly)
			if desktopOnly and not isDesktop then
				return
			end
			local measuredHeight = 37
			for _, child in ipairs(box:GetChildren()) do
				if child.ClassName ~= "UIPadding" and child.ClassName ~= "UIListLayout" and child.ClassName ~= "UICorner" and child.Visible then
					measuredHeight += child.Size.Y.Offset + 4
				end
			end
			if not measuredOnce then
				measuredOnce = measuredHeight
			end
			folderFrame.Frame.Visible = openState
			box.BackgroundTransparency = openState and 0.25 or 1
			box.ClipsDescendants = not openState
			isOpen = openState
			headerBtn.Indicator.Text = openState and "▾" or "▸"
			TweenService:Create(folderFrame, TWEEN_FAST, {
				Size = openState and UDim2.new(1, 0, 0, measuredHeight) or UDim2.new(1, 0, 0, 23),
			}):Play()
		end

		folderApi.Refresh = function()
			if measuredOnce then
				local measuredHeight = 37
				for _, child in ipairs(box:GetChildren()) do
					if child.ClassName ~= "UIPadding" and child.ClassName ~= "UIListLayout" and child.ClassName ~= "UICorner" and child.Visible then
						measuredHeight += child.Size.Y.Offset + 4
					end
				end
				measuredOnce = measuredHeight
				folderFrame.Size = isOpen and UDim2.new(1, 0, 0, measuredHeight) or UDim2.new(1, 0, 0, 23)
			end
		end

		headerBtn.MouseButton1Click:Connect(function()
			folderApi.Toggle(not isOpen)
		end)

		table.insert(searchableItems, { folderName, tabBtn })
		return folderApi
	end

	return tabApi
end

-- Top-of-Screen Mythic Puffshroom Monitor HUD
local monitorFrame = Instance.new("Frame")
monitorFrame.Name = "MythicMonitor"
monitorFrame.Active = true
monitorFrame.AnchorPoint = Vector2.new(0.5, 0)
monitorFrame.BackgroundColor3 = color_
monitorFrame.BackgroundTransparency = 0.06
monitorFrame.BorderSizePixel = 0
monitorFrame.ClipsDescendants = true
monitorFrame.Position = UDim2.new(0.5, 0, 0, 10)
monitorFrame.Size = UDim2.new(0, 440, 0, 34)
monitorFrame.ZIndex = 10
monitorFrame.Visible = cfg.monitor.enabled
monitorFrame.Parent = ScreenGui

local monitorCorner = Instance.new("UICorner")
monitorCorner.CornerRadius = UDim.new(0, 8)
monitorCorner.Parent = monitorFrame

local monitorStroke = Instance.new("UIStroke")
monitorStroke.Thickness = 1.2
monitorStroke.Color = uicolor
monitorStroke.Transparency = 0.2
monitorStroke.Parent = monitorFrame

local monitorAccent = Instance.new("Frame")
monitorAccent.Name = "Accent"
monitorAccent.BackgroundColor3 = uicolor
monitorAccent.BorderSizePixel = 0
monitorAccent.Size = UDim2.new(1, 0, 0, 2)
monitorAccent.ZIndex = 11
monitorAccent.Parent = monitorFrame

local monitorDotHalo = Instance.new("Frame")
monitorDotHalo.Name = "DotHalo"
monitorDotHalo.BackgroundColor3 = Color3.fromRGB(115, 130, 155)
monitorDotHalo.BackgroundTransparency = 0.72
monitorDotHalo.BorderSizePixel = 0
monitorDotHalo.Position = UDim2.new(0, 10, 0.5, -6)
monitorDotHalo.Size = UDim2.new(0, 14, 0, 14)
monitorDotHalo.ZIndex = 11
monitorDotHalo.Parent = monitorFrame

local monitorDotHaloCorner = Instance.new("UICorner")
monitorDotHaloCorner.CornerRadius = UDim.new(1, 0)
monitorDotHaloCorner.Parent = monitorDotHalo

local monitorDot = Instance.new("Frame")
monitorDot.Name = "Dot"
monitorDot.BackgroundColor3 = Color3.fromRGB(115, 130, 155)
monitorDot.BorderSizePixel = 0
monitorDot.Position = UDim2.new(0, 13, 0.5, -3)
monitorDot.Size = UDim2.new(0, 8, 0, 8)
monitorDot.ZIndex = 12
monitorDot.Parent = monitorFrame

local monitorDotCorner = Instance.new("UICorner")
monitorDotCorner.CornerRadius = UDim.new(1, 0)
monitorDotCorner.Parent = monitorDot

local monitorMainText = Instance.new("TextLabel")
monitorMainText.Name = "StatusText"
monitorMainText.BackgroundTransparency = 1
monitorMainText.Font = Enum.Font.GothamBold
monitorMainText.Text = "MYTHIC MONITOR  |  None on map"
monitorMainText.TextColor3 = Color3.fromRGB(220, 226, 236)
monitorMainText.TextSize = 12.5
monitorMainText.TextXAlignment = Enum.TextXAlignment.Left
monitorMainText.TextTruncate = Enum.TextTruncate.AtEnd
monitorMainText.Position = UDim2.new(0, 32, 0, 2)
monitorMainText.Size = UDim2.new(1, -122, 1, -2)
monitorMainText.ZIndex = 11
monitorMainText.Parent = monitorFrame

local monitorBadge = Instance.new("TextLabel")
monitorBadge.Name = "Badge"
monitorBadge.BackgroundColor3 = color_4
monitorBadge.BorderSizePixel = 0
monitorBadge.Font = Enum.Font.GothamBold
monitorBadge.Text = "Puffs: 0"
monitorBadge.TextColor3 = Color3.fromRGB(220, 225, 235)
monitorBadge.TextSize = 11
monitorBadge.AnchorPoint = Vector2.new(1, 0.5)
monitorBadge.Position = UDim2.new(1, -10, 0.5, 1)
monitorBadge.Size = UDim2.new(0, 74, 0, 20)
monitorBadge.ZIndex = 11
monitorBadge.Parent = monitorFrame

local monitorBadgeCorner = Instance.new("UICorner")
monitorBadgeCorner.CornerRadius = UDim.new(1, 0)
monitorBadgeCorner.Parent = monitorBadge

monitorFrame.InputBegan:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		if not dragState then
			dragState = {}
		end
		dragState[monitorFrame] = { inputObj.Position, monitorFrame.Position }
	end
end)

-- Tabs & Controls
local assistantTab = ui.AddTab("Assistant", "rbxassetid://10723415903", true, true)
local settingsTab = ui.AddTab("Settings", "rbxassetid://10734950309", false, false)

-- Left Column: Mythic Monitor + Movement
local monitorFolder = assistantTab.AddFolder("Mythic Monitor")
local monitorStatusLabel = monitorFolder.AddLabel("Status: No Mythic on map")
local puffCountsLabel = monitorFolder.AddLabel("Active Puffs: 0 (0C / 0R / 0E / 0L / 0M)")

controls.showMonitor = monitorFolder.AddSwitch("Show Top Mythic Monitor", function(enabled)
	monitorFrame.Visible = enabled
end, "monitor", "enabled")

controls.notifyMythic = monitorFolder.AddSwitch("Notify On Mythic Spawn", nil, "monitor", "notifyOnMythic")

monitorFolder.AddButton("Reset Monitor Position", function()
	monitorFrame.Position = UDim2.new(0.5, 0, 0, 10)
end, 165)

monitorFolder.Toggle(true, true)

local movementFolder = assistantTab.AddFolder("Movement")
local walkSpeedSlider, multiplierSlider

controls.walkspeedenabled = movementFolder.AddSwitch("Enable Walk Speed", function(enabled)
	walkSpeedController:SetEnabled(enabled)
end, "movement", "walkspeedenabled")

controls.walkdynamic = movementFolder.AddSwitch("Dynamic Walk Speed", function(enabled)
	if walkSpeedSlider then
		walkSpeedSlider.SetTitle(enabled and "Maximum Walk Speed" or "Walk Speed")
	end
	if multiplierSlider then
		multiplierSlider.SetVisible(enabled)
	end
	movementFolder.Refresh()
	walkSpeedController:Step()
end, "movement", "walkdynamic")

walkSpeedSlider = movementFolder.AddSlider("Walk Speed", function()
	walkSpeedController:Step()
end, 30, 90, "movement", "walkspeed", { Left = true })

multiplierSlider = movementFolder.AddSlider("Walk Speed Multiplier", function()
	walkSpeedController:Step()
end, 1, 2, "movement", "walkspeed2", { Left = true, Decimal = true })

controls.walkspeed = walkSpeedSlider
controls.walkspeed2 = multiplierSlider

if walkSpeedSlider then
	walkSpeedSlider.SetTitle(cfg.movement.walkdynamic and "Maximum Walk Speed" or "Walk Speed")
end
if multiplierSlider then
	multiplierSlider.SetVisible(cfg.movement.walkdynamic)
end

movementFolder.Toggle(true, true)

local highlightFolder = assistantTab.AddFolder("Highlight Tokens (3D)")

local function onHighlightToggleChanged()
	tokenHighlighter:RefreshAll()
end

controls.highlightTurpentine = highlightFolder.AddSwitch("Highlight Turpentine (Red)", onHighlightToggleChanged, "highlights", "turpentine")
controls.highlightCausticWax = highlightFolder.AddSwitch("Highlight Caustic Wax (Green)", onHighlightToggleChanged, "highlights", "causticWax")
controls.highlightSwirledWax = highlightFolder.AddSwitch("Highlight Swirled Wax (Yellow)", onHighlightToggleChanged, "highlights", "swirledWax")
controls.highlightBeam = highlightFolder.AddSwitch("3D Beacon Beam", onHighlightToggleChanged, "highlights", "beam")
controls.highlightLabel = highlightFolder.AddSwitch("Floating Token Label", onHighlightToggleChanged, "highlights", "label")
controls.highlightNotify = highlightFolder.AddSwitch("Notify On Rare Token", nil, "highlights", "notify")

highlightFolder.Toggle(true, true)

local stepMonitor -- forward declared

local function onPuffVisualsChanged()
	if stepMonitor then
		stepMonitor(true)
	end
end

local worldFolder = assistantTab.AddFolder("World / Performance")

controls.hideDecorations = worldFolder.AddSwitch("Hide Decorations", function(enabled)
	decorationsController:SetEnabled(enabled)
end, "decorations", "hide")

controls.lowGraphics = worldFolder.AddSwitch("Low Graphics / Anti-Lag", function(enabled)
	fpsOptimizer:SetLowGraphics(enabled)
end, "perf", "lowGraphics")

controls.hideBees = worldFolder.AddSwitch("Hide Bees", function(enabled)
	fpsOptimizer:SetHideBees(enabled)
end, "perf", "hideBees")

controls.filterParticles = worldFolder.AddSwitch("Filter Particles (Keep Key FX)", function(enabled)
	fpsOptimizer:SetFilterParticles(enabled)
	onPuffVisualsChanged()
end, "perf", "filterParticles")

controls.keepSporeTrails = worldFolder.AddSwitch("Keep Spore Trails", function(enabled)
	fpsOptimizer:SetKeepSporeTrails(enabled)
	onPuffVisualsChanged()
end, "perf", "keepSporeTrails")

controls.hidePlayers = worldFolder.AddSwitch("Hide Other Players", function(enabled)
	fpsOptimizer:SetHidePlayers(enabled)
end, "perf", "hidePlayers")

controls.hideFlowers = worldFolder.AddSwitch("Hide Flowers", function(enabled)
	fpsOptimizer:SetHideFlowers(enabled)
end, "perf", "hideFlowers")

controls.hideBalloons = worldFolder.AddSwitch("Hide Field Balloons", function(enabled)
	fpsOptimizer:SetHideBalloons(enabled)
end, "perf", "hideBalloons")

worldFolder.Toggle(true, true)

-- Right Column: Hide Tokens + Puffshroom Transparency + Auto Face Flames (BodyGyro)
local tokensFolder = assistantTab.AddFolder("Hide Tokens", true)

local function onTokenToggleChanged()
	tokenHider:RefreshAll()
end

controls.hideHoney = tokensFolder.AddSwitch("Hide Honey Tokens", onTokenToggleChanged, "tokens", "hideHoney")
controls.hideSoftWax = tokensFolder.AddSwitch("Hide Soft Waxes", onTokenToggleChanged, "tokens", "hideSoftWax")
controls.hideBitterberry = tokensFolder.AddSwitch("Hide Bitterberries", onTokenToggleChanged, "tokens", "hideBitterberry")
controls.hideTreat = tokensFolder.AddSwitch("Hide Treats", onTokenToggleChanged, "tokens", "hideTreat")
controls.hideRoyalJelly = tokensFolder.AddSwitch("Hide Royal Jellies", onTokenToggleChanged, "tokens", "hideRoyalJelly")

tokensFolder.Toggle(true, true)

local puffFolder = assistantTab.AddFolder("Puffshroom Transparency", true)

controls.transparencyEnabled = puffFolder.AddSwitch("Enable Transparency", onPuffVisualsChanged, "puffshrooms", "transparencyEnabled")
controls.commonTransparency = puffFolder.AddSlider("Common Transparency", onPuffVisualsChanged, 0, 1, "puffshrooms", "commonTransparency", { Left = true, Decimal = true })
controls.rareTransparency = puffFolder.AddSlider("Rare Transparency", onPuffVisualsChanged, 0, 1, "puffshrooms", "rareTransparency", { Left = true, Decimal = true })
controls.epicTransparency = puffFolder.AddSlider("Epic Transparency", onPuffVisualsChanged, 0, 1, "puffshrooms", "epicTransparency", { Left = true, Decimal = true })
controls.fadeGui = puffFolder.AddSwitch("Fade Overhead Labels", onPuffVisualsChanged, "puffshrooms", "fadeGui")
puffFolder.AddLabel("Legendary & Mythic always stay 100% visible")

puffFolder.Toggle(true, true)

local flameFolder = assistantTab.AddFolder("Auto Face Flames (BodyGyro)", true)
local flameStatusLabel = flameFolder.AddLabel("Target: Disabled")
flameController.statusLabel = flameStatusLabel

controls.flamesEnabled = flameFolder.AddSwitch("Enable Flame Auto-Face", function(enabled)
	flameController:SetEnabled(enabled)
end, "flames", "enabled")

controls.flamesShiftLockCompat = flameFolder.AddSwitch("Shift Lock Compatible", nil, "flames", "shiftLockCompat")
controls.flamesRefreshPriority = flameFolder.AddSwitch("Prioritize Expiring Flames", nil, "flames", "refreshPriority")
controls.flamesOnlyReady = flameFolder.AddSwitch("Only Face When Ready", nil, "flames", "onlyRefreshReady")

controls.flamesSmartDig = flameFolder.AddSwitch("Smart Auto Dig (Refresh Sync)", function()
	syncSmartAutoDig()
end, "flames", "smartAutoDig")

controls.flamesRefreshAge = flameFolder.AddSlider("Refresh Age (secs)", nil, 1.5, 4.5, "flames", "refreshAge", { Left = true, Decimal = true })
controls.flamesMaxRange = flameFolder.AddSlider("Flame Range (studs)", nil, 15, 45, "flames", "maxRange", { Left = true })

flameFolder.Toggle(true, true)

-- Settings Tab
local settingsFolder = settingsTab.AddFolder("Assistant")

controls.mobiletoggle = settingsFolder.AddSwitch("Mobile Toggle Button", function(enabled)
	mobileBtn.Visible = enabled
end, "misc", "mobiletoggle")

local cleanup -- forward declared

settingsFolder.AddButton("Reset All Settings", function()
	mergeConfig(cfg, deepCopy(defaultCfg))
	saveConfig()
	controls.showMonitor.Set(cfg.monitor.enabled)
	controls.notifyMythic.Set(cfg.monitor.notifyOnMythic)
	controls.walkspeedenabled.Set(cfg.movement.walkspeedenabled)
	controls.walkdynamic.Set(cfg.movement.walkdynamic)
	controls.walkspeed.Set(cfg.movement.walkspeed)
	controls.walkspeed2.Set(cfg.movement.walkspeed2)
	controls.highlightTurpentine.Set(cfg.highlights.turpentine)
	controls.highlightCausticWax.Set(cfg.highlights.causticWax)
	controls.highlightSwirledWax.Set(cfg.highlights.swirledWax)
	controls.highlightBeam.Set(cfg.highlights.beam)
	controls.highlightLabel.Set(cfg.highlights.label)
	controls.highlightNotify.Set(cfg.highlights.notify)
	controls.hideDecorations.Set(cfg.decorations.hide)
	controls.lowGraphics.Set(cfg.perf.lowGraphics)
	controls.hideBees.Set(cfg.perf.hideBees)
	controls.filterParticles.Set(cfg.perf.filterParticles)
	controls.keepSporeTrails.Set(cfg.perf.keepSporeTrails)
	controls.hidePlayers.Set(cfg.perf.hidePlayers)
	controls.hideFlowers.Set(cfg.perf.hideFlowers)
	controls.hideBalloons.Set(cfg.perf.hideBalloons)
	controls.flamesEnabled.Set(cfg.flames.enabled)
	controls.flamesShiftLockCompat.Set(cfg.flames.shiftLockCompat)
	controls.flamesRefreshPriority.Set(cfg.flames.refreshPriority)
	controls.flamesOnlyReady.Set(cfg.flames.onlyRefreshReady)
	controls.flamesSmartDig.Set(cfg.flames.smartAutoDig)
	controls.flamesRefreshAge.Set(cfg.flames.refreshAge)
	controls.flamesMaxRange.Set(cfg.flames.maxRange)
	controls.hideHoney.Set(cfg.tokens.hideHoney)
	controls.hideSoftWax.Set(cfg.tokens.hideSoftWax)
	controls.hideBitterberry.Set(cfg.tokens.hideBitterberry)
	controls.hideTreat.Set(cfg.tokens.hideTreat)
	controls.hideRoyalJelly.Set(cfg.tokens.hideRoyalJelly)
	controls.transparencyEnabled.Set(cfg.puffshrooms.transparencyEnabled)
	controls.commonTransparency.Set(cfg.puffshrooms.commonTransparency)
	controls.rareTransparency.Set(cfg.puffshrooms.rareTransparency)
	controls.epicTransparency.Set(cfg.puffshrooms.epicTransparency)
	controls.fadeGui.Set(cfg.puffshrooms.fadeGui)
	controls.mobiletoggle.Set(cfg.misc.mobiletoggle)
	ui.Notify("Puffshroom Assistant", "Settings reset to defaults")
end, 145)

settingsFolder.AddButton("Unload Assistant", function()
	if cleanup then
		cleanup()
	end
end, 145)

settingsFolder.Toggle(true, true)

-- Runtime Watchers & Monitor Step
local function bindCollectiblesFolder(folder)
	connections:Cancel("collectiblesAdded")
	connections:Cancel("collectiblesRemoved")
	if not folder then
		return
	end
	connections:Add("collectiblesAdded", folder.ChildAdded:Connect(function(token)
		tokenHider:Watch(token)
		tokenHider:Evaluate(token)
		tokenHighlighter:Evaluate(token)
	end))
	connections:Add("collectiblesRemoved", folder.ChildRemoved:Connect(function(token)
		tokenHider:Unwatch(token)
		tokenHighlighter:Remove(token)
		tokenHighlighter.notified[token] = nil
	end))
	for _, token in ipairs(folder:GetChildren()) do
		tokenHider:Watch(token)
		tokenHider:Evaluate(token)
		tokenHighlighter:Evaluate(token)
	end
end

bindCollectiblesFolder(workspace:FindFirstChild("Collectibles"))
flameController:BindFolder(workspace:FindFirstChild("PlayerFlames"))

local function bindPuffFolder(folder)
	connections:Cancel("puffAdded")
	connections:Cancel("puffRemoved")
	if not folder then
		return
	end
	connections:Add("puffAdded", folder.ChildAdded:Connect(function(puff)
		if stepMonitor then
			stepMonitor(true)
		end
	end))
	connections:Add("puffRemoved", folder.ChildRemoved:Connect(function(puff)
		puffVisuals:Restore(puff)
		puffMetaCache[puff] = nil
		monitorState.notified[puff] = nil
		if stepMonitor then
			stepMonitor(true)
		end
	end))
end

local happenings = workspace:FindFirstChild("Happenings")
if happenings then
	bindPuffFolder(happenings:FindFirstChild("Puffshrooms"))
	connections:Add("happeningsAdded", happenings.ChildAdded:Connect(function(child)
		if child.Name == "Puffshrooms" then
			bindPuffFolder(child)
			if stepMonitor then
				stepMonitor(true)
			end
		end
	end))
end

connections:Add("workspaceChildren", workspace.ChildAdded:Connect(function(child)
	if child.Name == "Collectibles" then
		bindCollectiblesFolder(child)
	elseif child.Name == "PlayerFlames" then
		flameController:BindFolder(child)
	elseif child.Name == "Bees" and cfg.perf.hideBees then
		fpsOptimizer:SetHideBees(true)
	elseif child.Name == "Particles" and cfg.perf.filterParticles then
		fpsOptimizer:ApplyParticlesFolder()
	elseif child.Name == "Flowers" and cfg.perf.hideFlowers then
		if task and task.defer then
			task.defer(function()
				if cfg.perf.hideFlowers then
					fpsOptimizer:SetHideFlowers(true)
				end
			end)
		else
			fpsOptimizer:SetHideFlowers(true)
		end
	elseif child.Name == "Balloons" and cfg.perf.hideBalloons then
		if task and task.defer then
			task.defer(function()
				if cfg.perf.hideBalloons then
					fpsOptimizer:SetHideBalloons(true)
				end
			end)
		else
			fpsOptimizer:SetHideBalloons(true)
		end
	elseif child.Name == "Happenings" then
		bindPuffFolder(child:FindFirstChild("Puffshrooms"))
		connections:Add("happeningsAdded", child.ChildAdded:Connect(function(sub)
			if sub.Name == "Puffshrooms" then
				bindPuffFolder(sub)
				if stepMonitor then
					stepMonitor(true)
				end
			end
		end))
	end
end))

connections:Add("workspaceRemoved", workspace.ChildRemoved:Connect(function(child)
	if child.Name == "PlayerFlames" then
		flameController:BindFolder(nil)
	end
end))

stepMonitor = function(skipMaintain)
	local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 }
	local mythics = {}
	local total = 0
	local livePuffs = {}

	local hap = workspace:FindFirstChild("Happenings")
	local puffFolderObj = hap and hap:FindFirstChild("Puffshrooms")
	if puffFolderObj then
		for _, puff in ipairs(puffFolderObj:GetChildren()) do
			local info = parsePuffshroom(puff)
			if info then
				livePuffs[puff] = true
				total += 1
				counts[info.rarity] = (counts[info.rarity] or 0) + 1
				puffVisuals:Apply(puff, info.rarity)
				if info.rarity == "Mythic" then
					table.insert(mythics, info)
					if cfg.monitor.notifyOnMythic and not monitorState.notified[puff] then
						monitorState.notified[puff] = true
						ui.Notify("Mythic Puffshroom!", info.fieldName .. " (Lvl " .. info.level .. ")")
					end
				end
			end
		end
	end

	-- Prune stale references for despawned puffshrooms
	for puff in pairs(puffVisuals.saved) do
		if not livePuffs[puff] then
			puffVisuals.saved[puff] = nil
			puffVisuals.appliedAlpha[puff] = nil
			puffVisuals.appliedFadeGui[puff] = nil
			puffVisuals.appliedHideParticles[puff] = nil
			puffVisuals.appliedKeepSpores[puff] = nil
			puffVisuals.descCache[puff] = nil
		end
	end
	for puff in pairs(puffMetaCache) do
		if not livePuffs[puff] then
			puffMetaCache[puff] = nil
		end
	end
	for puff in pairs(monitorState.notified) do
		if not livePuffs[puff] then
			monitorState.notified[puff] = nil
		end
	end

	monitorState.counts = counts
	monitorState.total = total
	monitorState.mythics = mythics

	local countSummary = string.format(
		"Active Puffs: %d (%dC / %dR / %dE / %dL / %dM)",
		total,
		counts.Common,
		counts.Rare,
		counts.Epic,
		counts.Legendary,
		counts.Mythic
	)
	if monitorState.lastCountSummary ~= countSummary then
		monitorState.lastCountSummary = countSummary
		puffCountsLabel.Text = countSummary
	end

	local hudText
	local badgeText
	local statusText
	local hasMythics = #mythics > 0

	if hasMythics then
		badgeText = #mythics == 1 and "MYTHIC!" or ("MYTHIC x" .. #mythics)
		if #mythics == 1 then
			local m = mythics[1]
			hudText = string.format("MYTHIC PUFFSHROOM: %s (Lvl %d, %s)", m.fieldName, m.level, m.timeText)
			statusText = string.format("Status: MYTHIC in %s (Lvl %d)", m.fieldName, m.level)
		else
			local parts = {}
			for _, m in ipairs(mythics) do
				table.insert(parts, string.format("%s L%d", m.fieldName, m.level))
			end
			local joined = table.concat(parts, ", ")
			hudText = string.format("MYTHIC PUFFSHROOMS (%d): %s", #mythics, joined)
			statusText = string.format("Status: %d MYTHICS (%s)", #mythics, joined)
		end
	else
		badgeText = "Puffs: " .. total
		hudText = "MYTHIC MONITOR  |  None on map"
		statusText = "Status: No Mythic on map"
	end

	if monitorState.lastHasMythics ~= hasMythics then
		monitorState.lastHasMythics = hasMythics
		if hasMythics then
			monitorStroke.Color = mythicPurple
			monitorAccent.BackgroundColor3 = mythicPurple
			monitorDotHalo.BackgroundColor3 = mythicDotColor
			monitorDot.BackgroundColor3 = mythicDotColor
			monitorMainText.TextColor3 = mythicTextColor
			monitorBadge.BackgroundColor3 = mythicPurple
			monitorBadge.TextColor3 = Color3.new(1, 1, 1)
			monitorStatusLabel.TextColor3 = mythicTextColor
		else
			monitorStroke.Color = uicolor
			monitorAccent.BackgroundColor3 = uicolor
			monitorDotHalo.BackgroundColor3 = Color3.fromRGB(115, 130, 155)
			monitorDot.BackgroundColor3 = Color3.fromRGB(115, 130, 155)
			monitorMainText.TextColor3 = Color3.fromRGB(220, 226, 236)
			monitorBadge.BackgroundColor3 = color_4
			monitorBadge.TextColor3 = Color3.fromRGB(220, 225, 235)
			monitorStatusLabel.TextColor3 = Color3.fromRGB(225, 230, 240)
		end
	end

	if monitorState.lastBadgeText ~= badgeText then
		monitorState.lastBadgeText = badgeText
		monitorBadge.Text = badgeText
	end
	if monitorState.lastStatusText ~= statusText then
		monitorState.lastStatusText = statusText
		monitorStatusLabel.Text = statusText
	end
	if monitorState.lastHudText ~= hudText then
		monitorState.lastHudText = hudText
		monitorMainText.Text = hudText
		local targetWidth = 440
		local okSize, measured = pcall(function()
			return TextService:GetTextSize(hudText, 12.5, Enum.Font.GothamBold, Vector2.new(1000, 34))
		end)
		if okSize and measured then
			targetWidth = math.clamp(measured.X + 135, 440, 680)
		end
		monitorFrame.Size = UDim2.new(0, targetWidth, 0, 34)
	end

	if not skipMaintain then
		monitorState.maintainTick = (monitorState.maintainTick or 0) + 1
		if monitorState.maintainTick % 2 == 1 then
			tokenHider:Maintain()
			tokenHighlighter:Maintain()
		end
	end
end

threads:Add("monitor", function()
	while not threads.closed do
		stepMonitor(false)
		task.wait(0.25)
	end
end)

local api
cleanup = function()
	threads:CancelAll()
	connections:CancelAll()
	walkSpeedController:Restore()
	decorationsController:Restore()
	fpsOptimizer:RestoreAll()
	flameController:UnbindRenderStep()
	flameController:ReleaseGyro()
	flameController:InvalidateTarget()
	table.clear(flameController.tracked)
	flameController.cachedField = nil
	flameController.cachedFieldPos = nil
	tokenHider:RestoreAll()
	tokenHighlighter:ClearAll()
	puffVisuals:RestoreAll()
	table.clear(puffMetaCache)
	if ScreenGui and ScreenGui.Parent then
		ScreenGui:Destroy()
	end
	if _G.puffshroomAssistant == api then
		_G.puffshroomAssistant = nil
	end
	if _G.puffshroomAssistantLoading then
		_G.puffshroomAssistantLoading = nil
	end
end

api = {
	gui = ScreenGui,
	cfg = cfg,
	controls = controls,
	Destroy = cleanup,
}

if isTestHarness then
	api.parsePuffshroom = parsePuffshroom
	api.puffMetaCache = puffMetaCache
	api.tokenHider = tokenHider
	api.tokenHighlighter = tokenHighlighter
	api.puffVisuals = puffVisuals
	api.walkSpeedController = walkSpeedController
	api.decorationsController = decorationsController
	api.fpsOptimizer = fpsOptimizer
	api.flameController = flameController
	api.monitorState = monitorState
	api.monitorFrame = monitorFrame
	api.monitorMainText = monitorMainText
	api.monitorBadge = monitorBadge
	api.stepMonitor = stepMonitor
end

_G.puffshroomAssistant = api
_G.puffshroomAssistantLoading = nil

return api
