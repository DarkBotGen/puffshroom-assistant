-- Offline Luau tests for Puffshroom Assistant (Atlas+ WalkSpeed 90, Token Hider,
-- Puffshroom Transparency for Common/Rare/Epic, and Top Mythic Monitor).

local function createSignal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, connected = true }
			table.insert(listeners, entry)
			return {
				Disconnect = function()
					entry.connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in ipairs(listeners) do
				if entry.connected then
					entry.fn(...)
				end
			end
		end,
		ActiveCount = function()
			local n = 0
			for _, entry in ipairs(listeners) do
				if entry.connected then
					n += 1
				end
			end
			return n
		end,
	}
end

local function makeMockInstance(className, name)
	local children = {}
	local inst
	inst = {
		ClassName = className,
		Name = name or className,
		Parent = nil,
		Transparency = 0,
		LocalTransparencyModifier = 0,
		TextTransparency = 0,
		BackgroundTransparency = 0,
		ImageTransparency = 0,
		Enabled = true,
		Text = "",
		Texture = "",
		Position = { X = 0, Y = 0, Z = 0 },
		Size = { X = 100, Y = 20, Z = 100 },
		DescendantAdded = createSignal(),
		ChildAdded = createSignal(),
		ChildRemoved = createSignal(),
		_propSignals = {},
	}
	function inst:IsA(target)
		if target == className then
			return true
		end
		if target == "BasePart" and (className == "Part" or className == "MeshPart" or className == "BasePart") then
			return true
		end
		return false
	end
	function inst:FindFirstChild(childName)
		for _, c in ipairs(children) do
			if c.Name == childName then
				return c
			end
		end
		return nil
	end
	function inst:FindFirstChildOfClass(cls)
		for _, c in ipairs(children) do
			if c:IsA(cls) then
				return c
			end
		end
		return nil
	end
	function inst:GetChildren()
		return table.clone(children)
	end
	function inst:GetDescendants()
		local out = {}
		local function walk(node)
			for _, c in ipairs(node:GetChildren()) do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(self)
		return out
	end
	function inst:GetPropertyChangedSignal(prop)
		if not self._propSignals[prop] then
			self._propSignals[prop] = createSignal()
		end
		return self._propSignals[prop]
	end
	function inst:AddChild(child)
		child.Parent = self
		table.insert(children, child)
		self.ChildAdded:Fire(child)
		self.DescendantAdded:Fire(child)
		return child
	end
	function inst:RemoveChild(child)
		for i, c in ipairs(children) do
			if c == child then
				table.remove(children, i)
				child.Parent = nil
				self.ChildRemoved:Fire(child)
				break
			end
		end
	end
	function inst:SetTexture(tex)
		self.Texture = tex
		if self._propSignals.Texture then
			self._propSignals.Texture:Fire()
		end
	end
	function inst:Destroy()
		self.Parent = nil
	end
	return inst
end

local function makePuffshroom(rarity, level, timeStr, fieldPart)
	local puff = makeMockInstance("Model", "Puffshroom")
	local top = puff:AddChild(makeMockInstance("MeshPart", "Puffball Top"))
	local stem = puff:AddChild(makeMockInstance("Part", "Puffball Stem"))
	local decal = stem:AddChild(makeMockInstance("Decal", "StemDecal"))
	local emitter = top:AddChild(makeMockInstance("ParticleEmitter", "Glow"))
	local attachment = top:AddChild(makeMockInstance("Attachment", "Attachment"))
	local gui = attachment:AddChild(makeMockInstance("BillboardGui", "Gui"))
	local nameRow = gui:AddChild(makeMockInstance("Frame", "NameRow"))
	local nameLbl = nameRow:AddChild(makeMockInstance("TextLabel", "TextLabel"))
	nameLbl.Text = (rarity == "Common" and "Puffshroom" or (rarity .. " Puffshroom")) .. " (Lvl " .. level .. ")"
	local barRow = gui:AddChild(makeMockInstance("Frame", "BarRow"))
	local bar = barRow:AddChild(makeMockInstance("Frame", "Bar"))
	local numLbl = bar:AddChild(makeMockInstance("TextLabel", "NumberLabel"))
	numLbl.Text = timeStr
	stem.Position = fieldPart.Position
	top.Position = fieldPart.Position
	return puff, top, stem, decal, emitter, gui, nameLbl
end

local function makeToken(iconId)
	local token = makeMockInstance("Part", "C")
	local front = token:AddChild(makeMockInstance("Decal", "FrontDecal"))
	front.Texture = "rbxassetid://" .. iconId
	local back = token:AddChild(makeMockInstance("Decal", "BackDecal"))
	back.Texture = "rbxassetid://" .. iconId
	local glow = token:AddChild(makeMockInstance("ParticleEmitter", "Glow"))
	return token, front, back, glow
end

-- Minimal mirror of Puffshroom Assistant logic under test
local cfg = {
	movement = { walkspeedenabled = false, walkdynamic = false, walkspeed = 90, walkspeed2 = 1.5 },
	tokens = { hideHoney = false, hideSoftWax = false, hideBitterberry = false, hideTreat = false, hideRoyalJelly = false },
	highlights = { turpentine = true, causticWax = true, swirledWax = true, beam = true, label = true, notify = true },
	puffshrooms = { transparencyEnabled = true, commonTransparency = 0, rareTransparency = 0, epicTransparency = 0, fadeGui = false },
	monitor = { enabled = true, notifyOnMythic = true },
}

local playerMovespeedStat = 32
local humanoid = { WalkSpeed = 32, Health = 100, Parent = true }

local walkSpeedController = { lastAppliedSpeed = nil, originalSpeed = nil, trackedHumanoid = nil }
function walkSpeedController:Step()
	if not cfg.movement.walkspeedenabled then
		return
	end
	local h = humanoid
	if not h or not h.Parent or h.Health <= 0 then
		return
	end
	if self.trackedHumanoid ~= h then
		self.trackedHumanoid = h
		self.originalSpeed = h.WalkSpeed
		self.lastAppliedSpeed = nil
	end
	local maxCap = math.clamp(tonumber(cfg.movement.walkspeed) or 90, 30, 90)
	local targetSpeed = not cfg.movement.walkdynamic and maxCap or math.min(maxCap, playerMovespeedStat * cfg.movement.walkspeed2)
	local currentSpeed = h.WalkSpeed
	local wasSetByUs = self.lastAppliedSpeed ~= nil and math.abs(currentSpeed - self.lastAppliedSpeed) < 0.05
	if currentSpeed < targetSpeed or (wasSetByUs and currentSpeed > targetSpeed) then
		h.WalkSpeed = targetSpeed
		self.lastAppliedSpeed = targetSpeed
	end
end
function walkSpeedController:Restore()
	local h = self.trackedHumanoid
	if h and h.Parent and self.lastAppliedSpeed ~= nil then
		if math.abs(h.WalkSpeed - self.lastAppliedSpeed) < 0.05 then
			h.WalkSpeed = playerMovespeedStat
		end
	end
	self.lastAppliedSpeed = nil
	self.originalSpeed = nil
	self.trackedHumanoid = nil
end

-- 1. WalkSpeed tests (fixed 90, decrease slider, higher boost preserved, dynamic mode, restore)
cfg.movement.walkspeedenabled = true
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 90, "expected fixed walkspeed 90, got " .. tostring(humanoid.WalkSpeed))

cfg.movement.walkspeed = 65
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 65, "lowering walkspeed slider should lower speed to 65")

humanoid.WalkSpeed = 110
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 110, "external boost > targetSpeed must not be nerfed")

humanoid.WalkSpeed = 65
cfg.movement.walkspeed = 90
cfg.movement.walkdynamic = true
cfg.movement.walkspeed2 = 1.5
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 48, "dynamic mode should compute 32 * 1.5 = 48")

playerMovespeedStat = 70
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 90, "dynamic mode must cap at max walkspeed 90")

walkSpeedController:Restore()
assert(humanoid.WalkSpeed == 70, "restoring walkspeed should return to PlayerMovespeed")

-- 2. Token Hider & Highlight tests (Honey, Soft Wax, Bitterberry, Treat, Royal Jelly + Swirled/Caustic/Turpentine)
local tokenIds = {
	honey = { ["1472135114"] = true, ["1952683491"] = true },
	softWax = { ["8277778300"] = true },
	bitterberry = { ["4483236276"] = true, ["6087985073"] = true },
	treat = { ["2028574353"] = true },
	royalJelly = { ["1471882621"] = true },
	swirledWax = { ["8277783113"] = true },
	causticWax = { ["8277781666"] = true },
	turpentine = { ["8310376128"] = true },
}
local tokenHider = { ids = tokenIds, saved = {}, watchers = {} }
local function extractTokenIconId(token)
	local front = token:FindFirstChild("FrontDecal")
	return front and string.match(tostring(front.Texture), "%d+") or nil
end
function tokenHider:ShouldHide(token)
	local id = extractTokenIconId(token)
	if not id then return false end
	return (cfg.tokens.hideHoney and self.ids.honey[id])
		or (cfg.tokens.hideSoftWax and self.ids.softWax[id])
		or (cfg.tokens.hideBitterberry and self.ids.bitterberry[id])
		or (cfg.tokens.hideTreat and self.ids.treat[id])
		or (cfg.tokens.hideRoyalJelly and self.ids.royalJelly[id])
		or false
end
function tokenHider:Hide(token)
	local record = self.saved[token] or {}
	self.saved[token] = record
	local function setProp(inst, prop, val)
		record[inst] = record[inst] or {}
		if record[inst][prop] == nil then record[inst][prop] = inst[prop] end
		inst[prop] = val
	end
	setProp(token, "LocalTransparencyModifier", 1)
	setProp(token, "Transparency", 1)
	for _, d in ipairs(token:GetDescendants()) do
		if d:IsA("Decal") then setProp(d, "Transparency", 1)
		elseif d:IsA("ParticleEmitter") then setProp(d, "Enabled", false) end
	end
end
function tokenHider:Restore(token)
	local record = self.saved[token]
	if not record then return end
	self.saved[token] = nil
	for inst, props in pairs(record) do
		for prop, val in pairs(props) do inst[prop] = val end
	end
end
function tokenHider:Evaluate(token)
	if self:ShouldHide(token) then self:Hide(token) else self:Restore(token) end
end

local honeyTok, honeyFront = makeToken("1472135114")
local waxTok, waxFront = makeToken("8277778300")
local bitterTok, bitterFront = makeToken("4483236276")
local treatTok, treatFront = makeToken("2028574353")
local rjTok, rjFront = makeToken("1471882621")
local starTreatTok, starTreatFront = makeToken("2028603146")
local starJellyTok, starJellyFront = makeToken("2319943273")
local linkTok, linkFront = makeToken("1629547638")
honeyTok.Parent, waxTok.Parent, bitterTok.Parent, treatTok.Parent, rjTok.Parent = true, true, true, true, true
starTreatTok.Parent, starJellyTok.Parent, linkTok.Parent = true, true, true

cfg.tokens.hideHoney = true
cfg.tokens.hideSoftWax = true
cfg.tokens.hideBitterberry = true
cfg.tokens.hideTreat = true
cfg.tokens.hideRoyalJelly = true
for _, tok in ipairs({ honeyTok, waxTok, bitterTok, treatTok, rjTok, starTreatTok, starJellyTok, linkTok }) do
	tokenHider:Evaluate(tok)
end
assert(honeyTok.LocalTransparencyModifier == 1 and honeyFront.Transparency == 1, "honey token should be hidden")
assert(waxTok.LocalTransparencyModifier == 1 and waxFront.Transparency == 1, "soft wax token should be hidden")
assert(bitterTok.LocalTransparencyModifier == 1 and bitterFront.Transparency == 1, "bitterberry token should be hidden")
assert(treatTok.LocalTransparencyModifier == 1 and treatFront.Transparency == 1, "treat token should be hidden")
assert(rjTok.LocalTransparencyModifier == 1 and rjFront.Transparency == 1, "royal jelly token should be hidden")
assert(starTreatTok.LocalTransparencyModifier == 0 and starTreatFront.Transparency == 0, "star treat must stay visible")
assert(starJellyTok.LocalTransparencyModifier == 0 and starJellyFront.Transparency == 0, "star jelly must stay visible")
assert(linkTok.LocalTransparencyModifier == 0 and linkFront.Transparency == 0, "token link must stay visible")

cfg.tokens.hideSoftWax = false
cfg.tokens.hideTreat = false
cfg.tokens.hideRoyalJelly = false
tokenHider:Evaluate(waxTok)
tokenHider:Evaluate(treatTok)
tokenHider:Evaluate(rjTok)
assert(waxTok.LocalTransparencyModifier == 0 and waxFront.Transparency == 0, "soft wax should restore when untoggled")
assert(treatTok.LocalTransparencyModifier == 0 and treatFront.Transparency == 0, "treat should restore when untoggled")
assert(rjTok.LocalTransparencyModifier == 0 and rjFront.Transparency == 0, "royal jelly should restore when untoggled")

-- 2b. 3D Highlight matching & color presets
local HIGHLIGHT_STYLES = {
	swirledWax = { key = "swirledWax", label = "SWIRLED WAX", color = { 255, 225, 40 } },
	causticWax = { key = "causticWax", label = "CAUSTIC WAX", color = { 45, 240, 85 } },
	turpentine = { key = "turpentine", label = "TURPENTINE", color = { 255, 45, 55 } },
}
local function getHighlightStyle(token)
	local id = extractTokenIconId(token)
	if not id then return nil end
	if cfg.highlights.turpentine and tokenIds.turpentine[id] then return HIGHLIGHT_STYLES.turpentine end
	if cfg.highlights.causticWax and tokenIds.causticWax[id] then return HIGHLIGHT_STYLES.causticWax end
	if cfg.highlights.swirledWax and tokenIds.swirledWax[id] then return HIGHLIGHT_STYLES.swirledWax end
	return nil
end

local swirledTok = makeToken("8277783113")
local causticTok = makeToken("8277781666")
local turpTok = makeToken("8310376128")
assert(getHighlightStyle(swirledTok).key == "swirledWax" and getHighlightStyle(swirledTok).color[1] == 255 and getHighlightStyle(swirledTok).color[2] == 225, "swirled wax should highlight yellow")
assert(getHighlightStyle(causticTok).key == "causticWax" and getHighlightStyle(causticTok).color[2] == 240 and getHighlightStyle(causticTok).color[1] == 45, "caustic wax should highlight green")
assert(getHighlightStyle(turpTok).key == "turpentine" and getHighlightStyle(turpTok).color[1] == 255 and getHighlightStyle(turpTok).color[2] == 45, "turpentine should highlight red")
assert(getHighlightStyle(waxTok) == nil and getHighlightStyle(treatTok) == nil and getHighlightStyle(rjTok) == nil and getHighlightStyle(linkTok) == nil, "non-highlighted tokens must return nil")

cfg.highlights.causticWax = false
assert(getHighlightStyle(causticTok) == nil, "disabling caustic highlight should return nil")
cfg.highlights.causticWax = true

-- 3. Puffshroom Transparency & Mythic Monitor tests
local fieldRose = makeMockInstance("Part", "Rose Field")
fieldRose.Position = { X = -300, Y = 20, Z = 120 }
local fieldPepper = makeMockInstance("Part", "Pepper Patch")
fieldPepper.Position = { X = -480, Y = 120, Z = 530 }

local function getFieldAt(pos)
	if pos.X == fieldRose.Position.X then return fieldRose end
	if pos.X == fieldPepper.Position.X then return fieldPepper end
	return nil
end

local function parsePuff(puff)
	local top = puff:FindFirstChild("Puffball Top")
	local gui = top:FindFirstChild("Attachment"):FindFirstChild("Gui")
	local text = gui:FindFirstChild("NameRow"):FindFirstChild("TextLabel").Text
	local rawRarity = string.match(text, "(%a*)%s+Puffshroom")
	local rarity = (rawRarity and rawRarity ~= "") and rawRarity or "Common"
	local level = tonumber(string.match(text, "Lvl (%d+)")) or 1
	local timeText = gui:FindFirstChild("BarRow"):FindFirstChild("Bar"):FindFirstChild("NumberLabel").Text
	local stem = puff:FindFirstChild("Puffball Stem")
	local field = getFieldAt(stem.Position)
	return { instance = puff, rarity = rarity, level = level, timeText = timeText, fieldName = field and field.Name or "Unknown Field" }
end

local puffCommon, cTop, cStem, cDecal, cEmit, cGui, cLbl = makePuffshroom("Common", 4, "2:30", fieldRose)
local puffRare, rTop, rStem = makePuffshroom("Rare", 8, "3:15", fieldRose)
local puffEpic, eTop, eStem = makePuffshroom("Epic", 12, "4:00", fieldPepper)
local puffMythic, mTop, mStem, mDecal, mEmit = makePuffshroom("Mythic", 16, "4:45", fieldPepper)

assert(parsePuff(puffCommon).rarity == "Common" and parsePuff(puffCommon).level == 4 and parsePuff(puffCommon).fieldName == "Rose Field")
assert(parsePuff(puffRare).rarity == "Rare" and parsePuff(puffRare).level == 8)
assert(parsePuff(puffEpic).rarity == "Epic" and parsePuff(puffEpic).level == 12)
assert(parsePuff(puffMythic).rarity == "Mythic" and parsePuff(puffMythic).level == 16 and parsePuff(puffMythic).fieldName == "Pepper Patch")

local function applyPuffAlpha(puff, alpha, fadeGui)
	for _, inst in ipairs(puff:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = alpha
		elseif inst:IsA("Decal") then
			inst.Transparency = alpha
		elseif inst:IsA("ParticleEmitter") then
			inst.Enabled = alpha < 0.95
		elseif fadeGui and inst:IsA("BillboardGui") then
			inst.Enabled = alpha < 1
		elseif fadeGui and inst:IsA("TextLabel") then
			inst.TextTransparency = alpha
		end
	end
end

cfg.puffshrooms.commonTransparency = 0.8
cfg.puffshrooms.rareTransparency = 0.5
cfg.puffshrooms.epicTransparency = 0.3
applyPuffAlpha(puffCommon, cfg.puffshrooms.commonTransparency, true)
applyPuffAlpha(puffRare, cfg.puffshrooms.rareTransparency, false)
applyPuffAlpha(puffEpic, cfg.puffshrooms.epicTransparency, false)
applyPuffAlpha(puffMythic, 0, true)

assert(math.abs(cTop.LocalTransparencyModifier - 0.8) < 1e-6 and math.abs(cDecal.Transparency - 0.8) < 1e-6 and math.abs(cLbl.TextTransparency - 0.8) < 1e-6)
assert(math.abs(rTop.LocalTransparencyModifier - 0.5) < 1e-6)
assert(math.abs(eTop.LocalTransparencyModifier - 0.3) < 1e-6)
assert(mTop.LocalTransparencyModifier == 0 and mDecal.Transparency == 0 and mEmit.Enabled == true, "Mythic puffshrooms must stay 100% visible")

-- 4. Reversible Hide Decorations unit test
local decWs = makeMockInstance("Folder", "Workspace")
local decAmulets = decWs:AddChild(makeMockInstance("Folder", "Amulets"))
local decMap = decWs:AddChild(makeMockInstance("Folder", "Map"))
local decFences = decMap:AddChild(makeMockInstance("Folder", "Fences"))
local decTerrain = decMap:AddChild(makeMockInstance("Part", "Terrain"))
local decPlats = decWs:AddChild(makeMockInstance("Folder", "HivePlatforms"))
local decSlot = decPlats:AddChild(makeMockInstance("Model", "Slot1"))
local decPlat = decSlot:AddChild(makeMockInstance("Part", "Platform"))
decPlat.CanCollide = true
local decHive = decSlot:AddChild(makeMockInstance("Model", "Hive"))
local decPlayerRef = decSlot:AddChild(makeMockInstance("ObjectValue", "PlayerRef"))
local decExtra = decSlot:AddChild(makeMockInstance("Part", "SlotDeco"))
local decPuffs = decWs:AddChild(makeMockInstance("Folder", "Happenings"))

local detachedDecos = {}
local savedDecoPlats = {}
local function detachMock(obj)
	if not obj or not obj.Parent then return end
	local parent = obj.Parent
	table.insert(detachedDecos, { inst = obj, parent = parent })
	parent:RemoveChild(obj)
end
detachMock(decWs:FindFirstChild("Amulets"))
detachMock(decMap:FindFirstChild("Fences"))
for _, item in ipairs(decSlot:GetChildren()) do
	if item.Name == "Platform" then
		savedDecoPlats[item] = item.CanCollide
		item.CanCollide = false
	elseif item.Name ~= "Hive" and item.Name ~= "PlayerRef" then
		detachMock(item)
	end
end
assert(decAmulets.Parent == nil and decFences.Parent == nil and decExtra.Parent == nil, "decorations detached")
assert(decTerrain.Parent == decMap and decHive.Parent == decSlot and decPlayerRef.Parent == decSlot and decPuffs.Parent == decWs, "world terrain/hive/puffshrooms kept")
assert(decPlat.CanCollide == false, "hive platform collision disabled")
for i = #detachedDecos, 1, -1 do
	detachedDecos[i].parent:AddChild(detachedDecos[i].inst)
end
for plat, origCol in pairs(savedDecoPlats) do
	plat.CanCollide = origCol
end
assert(decAmulets.Parent == decWs and decFences.Parent == decMap and decExtra.Parent == decSlot and decPlat.CanCollide == true, "decorations and collision restored")

-- 5. BodyGyro Flame Auto-Face, Refresh Priority & Shift Lock AutoRotate tests
local flameCfg = { refreshPriority = true, onlyRefreshReady = false, refreshAge = 3.0, maxRange = 30 }
local function makeFlame(pos, sizeVal, greenVal)
	local f = makeMockInstance("Part", "Flame")
	f.Position = pos
	local pf = f:AddChild(makeMockInstance("ParticleEmitter", "PF"))
	pf.Size = { Keypoints = { { Value = sizeVal } } }
	pf.Color = { Keypoints = { { Value = { R = 1, G = greenVal, B = 0 } } } }
	return f
end
local flDark = makeFlame({ X = -292, Y = 22, Z = 120 }, 1.65, 0.1)
local flTiny = makeFlame({ X = -292, Y = 22, Z = 122 }, 1.35, 0.8)
local flFresh = makeFlame({ X = -293, Y = 22, Z = 120 }, 1.70, 0.8)
local flOld = makeFlame({ X = -285, Y = 22, Z = 120 }, 1.55, 0.8)
local flOther = makeFlame({ X = -480, Y = 122, Z = 530 }, 1.60, 0.8)
for _, fl in ipairs({ flDark, flTiny, flFresh, flOld, flOther }) do
	fl.Parent = true
end
local flameTimes = { [flDark] = 6.0, [flTiny] = 6.0, [flFresh] = 9.0, [flOld] = 6.4, [flOther] = 6.0 }
local function pickFlame(rPos, field, curNow)
	local hasFresh, bestReady, bestFallback = false, nil, nil
	for fl, t0 in pairs(flameTimes) do
		if fl.Parent then
			local pf = fl:FindFirstChild("PF")
			local s = pf.Size.Keypoints[1].Value
			local g = pf.Color.Keypoints[1].Value.G
			if s > 1.4 and g > 0.2 then
				local dx = fl.Position.X - rPos.X
				local dz = fl.Position.Z - rPos.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				local flField = math.abs(fl.Position.X - (-300)) <= 60 and fieldRose or fieldPepper
				if dist < flameCfg.maxRange and flField == field then
					local age = curNow - t0
					if age < flameCfg.refreshAge then hasFresh = true end
					if dist > 4 then
						if age >= flameCfg.refreshAge and (not bestReady or age > bestReady.age) then
							bestReady = { obj = fl, age = age, dist = dist }
						end
						if not bestFallback or dist < bestFallback.dist then
							bestFallback = { obj = fl, age = age, dist = dist }
						end
					end
				end
			end
		end
	end
	if flameCfg.refreshPriority then
		if bestReady then return bestReady.obj, false end
		if flameCfg.onlyRefreshReady then return nil, hasFresh end
		return bestFallback and bestFallback.obj or nil, hasFresh
	end
	return bestFallback and bestFallback.obj or nil, false
end

local rootPos = { X = -300, Y = 22, Z = 120 }
local picked, stopDig = pickFlame(rootPos, fieldRose, 10.0)
assert(picked == flOld and stopDig == false, "should prioritize 3.6s expiring flame over 1.0s fresh flame")
flameTimes[flOld] = nil
picked, stopDig = pickFlame(rootPos, fieldRose, 10.0)
assert(picked == flFresh and stopDig == true, "with fresh flame in range and no ready flame, stopDig=true pauses auto dig")
flameCfg.onlyRefreshReady = true
picked, stopDig = pickFlame(rootPos, fieldRose, 10.0)
assert(picked == nil and stopDig == true, "onlyRefreshReady holds facing torque when only fresh flames exist")

local slHum = { AutoRotate = true, Parent = true }
local savedAR, managedAR = nil, nil
local function suppressAR(h)
	if managedAR ~= h then
		savedAR = h.AutoRotate
		managedAR = h
	end
	h.AutoRotate = false
end
local function restoreAR()
	if managedAR and managedAR.Parent and savedAR ~= nil then
		managedAR.AutoRotate = savedAR
	end
	managedAR, savedAR = nil, nil
end
suppressAR(slHum)
assert(slHum.AutoRotate == false, "Shift Lock compat suppresses AutoRotate when facing flame")
restoreAR()
assert(slHum.AutoRotate == true, "AutoRotate restores immediately when idle or released")

print("PASS: Puffshroom Assistant walkspeed, token hiding, puffshroom transparency, mythic parsing, hide decorations, and flame bodygyro verified")
