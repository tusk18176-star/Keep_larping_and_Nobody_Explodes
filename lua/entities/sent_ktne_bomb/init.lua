AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("ktne_open_ui_mp")
util.AddNetworkString("ktne_sync_state_mp")
util.AddNetworkString("ktne_action_mp")
util.AddNetworkString("ktne_close_ui_mp")

local ModuleBuilders = include("ktne/server/module_builders.lua")

local deepCopy = ModuleBuilders.deepCopy
local wireColors = ModuleBuilders.wireColors
local symbolPool = ModuleBuilders.symbolPool
local keypadRows = ModuleBuilders.keypadRows
local tamperLeftColors = ModuleBuilders.tamperLeftColors
local tamperRightColors = ModuleBuilders.tamperRightColors
local modulePoolOrder = ModuleBuilders.modulePoolOrder
local moduleDisplayNames = ModuleBuilders.moduleDisplayNames
local formatChatTimeRemaining = ModuleBuilders.formatChatTimeRemaining
local buildSeismicState = ModuleBuilders.buildSeismicState
local sumDigits = ModuleBuilders.sumDigits
local serialDigits = ModuleBuilders.serialDigits
local buildWireModule = ModuleBuilders.buildWireModule
local buildKeypadModule = ModuleBuilders.buildKeypadModule
local buildSpiralModule = ModuleBuilders.buildSpiralModule
local buildTamperModule = ModuleBuilders.buildTamperModule
local buildMemoryModule = ModuleBuilders.buildMemoryModule
local buildRedBlueModule = ModuleBuilders.buildRedBlueModule
local buildElectricModule = ModuleBuilders.buildElectricModule
local buildTwinModule = ModuleBuilders.buildTwinModule
local buildOverrideModule = ModuleBuilders.buildOverrideModule
local buildCalibrationModule = ModuleBuilders.buildCalibrationModule
local buildInterruptModule = ModuleBuilders.buildInterruptModule
local serialToReactorCode = ModuleBuilders.serialToReactorCode
local buildReactorModule = ModuleBuilders.buildReactorModule
local reactorCodeToDrillDigits = ModuleBuilders.reactorCodeToDrillDigits
local drillTargetsForTime = ModuleBuilders.drillTargetsForTime
local buildDrillModule = ModuleBuilders.buildDrillModule
local buildThermoModule = ModuleBuilders.buildThermoModule
local buildMinesModule = ModuleBuilders.buildMinesModule

local DEFAULT_START_TIME = 300

local function buildPKBState()
    return {
        active = false,
        phase = "idle",
        timer = 0,
        colors = {},
        connections = {},
        blocked = {},
        completed = {},
        completedPaths = {},
        draggingColor = nil,
        dragVisited = {},
        lastDragKey = nil,
    }
end

local function resetPKBOutageState(pkb)
    pkb.phase = "outage"
    pkb.timer = 0
    pkb.completed = {}
    pkb.completedPaths = {}
    pkb.draggingColor = nil
    pkb.dragVisited = {}
    pkb.lastDragKey = nil
end

local function regenPKBLayout(pkb)
    local fresh = buildPKBState()
    pkb.colors = fresh.colors
    pkb.connections = fresh.connections
    pkb.blocked = fresh.blocked
    pkb.active = fresh.active
    pkb.phase = fresh.phase
    pkb.timer = fresh.timer
    pkb.completed = {}
    pkb.completedPaths = {}
    pkb.draggingColor = nil
    pkb.dragVisited = {}
    pkb.lastDragKey = nil
end

function ENT:SanitizeActionData(action, data)
    if not istable(data) then return {} end

    local safe = {}
    if data.index ~= nil then safe.index = clampInt(data.index, 0, 64, 0) end
    if data.x ~= nil then safe.x = clampInt(data.x, 0, 64, 0) end
    if data.y ~= nil then safe.y = clampInt(data.y, 0, 64, 0) end
    if data.seq ~= nil then safe.seq = clampInt(data.seq, 0, 1000000, 0) end
    if data.key ~= nil then safe.key = clampInt(data.key, 0, 64, 0) end
    if data.value ~= nil then safe.value = clampInt(data.value, 0, 999, 0) end
    if data.delta ~= nil then safe.delta = clampInt(data.delta, -999, 999, 0) end
    if data.holding ~= nil then safe.holding = data.holding == true end

    if data.text ~= nil then
        safe.text = string.sub(tostring(data.text or ""):gsub("[%c]+", " "), 1, 256)
    end
    if data.make ~= nil then
        safe.make = string.sub(string.upper(tostring(data.make or "")), 1, 32)
    end
    if data.role ~= nil then
        local role = tostring(data.role or "")
        safe.role = role == "manual" and "manual" or "panel"
    end
    if data.channel ~= nil then
        local channel = tostring(data.channel or "")
        safe.channel = channel == "exhaust" and "exhaust" or "coolant"
    end
    if data.code ~= nil then
        safe.code = string.sub(tostring(data.code or ""), 1, 32)
    end
    if data.color ~= nil then safe.color = string.sub(tostring(data.color or ""), 1, 32) end
    if data.source ~= nil then safe.source = string.sub(tostring(data.source or ""), 1, 32) end
    if data.receiver ~= nil then safe.receiver = string.sub(tostring(data.receiver or ""), 1, 32) end
    if data.symbol ~= nil then safe.symbol = string.sub(tostring(data.symbol or ""), 1, 32) end

    return safe
end

function ENT:OpenDebugPickerFor(ply)
    if not IsValid(ply) then return end
    net.Start("ktne_open_ui_mp")
        net.WriteEntity(self)
        net.WriteString("__debug_picker")
        net.WriteTable({
            active = self:GetGameActive(),
            debugEnabled = self.KTNEDebugOnePlayer == true or self:GetNWBool("KTNE_DebugOnePlayer", false) == true,
            currentRole = self.DebugTestRole or "",
        })
    net.Send(ply)
end

function ENT:StartDebugGameFor(ply, role)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not (self.KTNEDebugOnePlayer == true or self:GetNWBool("KTNE_DebugOnePlayer", false) == true) then return end

    role = role == "manual" and "manual" or "panel"
    self.DebugOnePlayerActive = true
    self.DebugTestRole = role
    self.DebugTestSID = sid64(ply)
    self.PanelPlayer = ply
    self.ManualPlayer = ply
    self:SetPanelPlySID(self.DebugTestSID)
    self:SetManualPlySID(self.DebugTestSID)

    if not self:GetGameActive() then
        self:StartGame()
    else
        self:OpenUIFor(ply)
        self:SyncState(true)
    end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self.RoundEnding then return end

    self:UnassignInvalidPlayers()
    if (self.KTNEDebugOnePlayer == true or self:GetNWBool("KTNE_DebugOnePlayer", false) == true) and (not self:GetGameActive() or self.DebugOnePlayerActive) then
        self:OpenDebugPickerFor(activator)
        return
    end

    local role = self:AssignPlayer(activator)
    if not role then
        activator:ChatPrint("This bomb already has two players.")
        return
    end

    if not self:GetGameActive() then
        self:StartGame()
        if self:GetJoinedCount() < 2 then
            self:PushChatEntry("system", "SYSTEM", "Waiting for a second player to join the bomb.")
        end
    else
        self:OpenUIFor(activator)
    end

    self:SyncState(true)
end

function ENT:OpenUIFor(ply)
    if not IsValid(ply) then return end
    local role = self:GetPlayerRole(ply)
    net.Start("ktne_open_ui_mp")
        net.WriteEntity(self)
        net.WriteString(role)
        net.WriteTable(self:GetClientStateFor(role, true, nil, ply))
    net.Send(ply)
end


function ENT:PushChatEntry(kind, speaker, text)
    self.ChatLog = self.ChatLog or {}
    self.ChatSeq = (self.ChatSeq or 0) + 1
    self.ChatLog[#self.ChatLog + 1] = {
        seq = self.ChatSeq,
        kind = kind or "system",
        speaker = speaker or "SYSTEM",
        text = tostring(text or ""),
        at = CurTime(),
        clock = os.date("%H:%M"),
    }
    while #self.ChatLog > 80 do
        table.remove(self.ChatLog, 1)
    end
    self._chatDirty = true
end

function ENT:GetChatAckKey(ply)
    if not IsValid(ply) then return nil end
    local sid = ply.SteamID64 and ply:SteamID64() or nil
    if sid and sid ~= "" and sid ~= "0" then return sid end
    return tostring(ply:EntIndex())
end

function ENT:GetLastChatAck(ply)
    local key = self:GetChatAckKey(ply)
    if not key then return 0 end
    self.ChatAckSeq = self.ChatAckSeq or {}
    return math.max(0, math.floor(tonumber(self.ChatAckSeq[key] or 0) or 0))
end

function ENT:SetLastChatAck(ply, seq)
    local key = self:GetChatAckKey(ply)
    if not key then return end
    self.ChatAckSeq = self.ChatAckSeq or {}
    self.ChatAckSeq[key] = math.max(0, math.floor(tonumber(seq) or 0))
end

function ENT:CheckCompletionLogs()
    self._loggedSolved = self._loggedSolved or {}
    local solvedCount, totalCount = 0, 0
    local changed = false
    for _, id in ipairs(self.ModuleSlots or {}) do
        if id ~= "blank" then
            totalCount = totalCount + 1
            local module = self.Modules and self.Modules[id]
            if module and module.solved then
                solvedCount = solvedCount + 1
                if not self._loggedSolved[id] then
                    self._loggedSolved[id] = true
                    local remaining = math.max(0, totalCount - solvedCount)
                    self:NotifyPlayers(string.format("Module complete: %s (%d complete, %d remaining)", moduleDisplayNames[id] or id, solvedCount, remaining))
                    changed = true
                end
            end
        end
    end
    return changed
end

function ENT:GetClientStateFor(role, includeStatic, syncFlags, ply)
    syncFlags = syncFlags or {}
    local includeDynamic = includeStatic or syncFlags.dynamic == true
    local includeChat = includeStatic or syncFlags.chat == true
    local includeManual = includeStatic or syncFlags.includeManual == true
    local state = {
        serial = self.Serial,
        make = self.MakeName,
        bombIdentified = self.BombIdentified == true,
        identifiedMake = self.IdentifiedMake or "",
        active = self:GetGameActive(),
        timeRemaining = self:GetTimeRemaining(),
        strikes = self:GetStrikes(),
        maxStrikes = 3,
        panelJoined = IsValid(self.PanelPlayer),
        manualJoined = IsValid(self.ManualPlayer),
        allSolved = self:AllSolved(),
        roundSuccess = self.RoundSuccess == true,
        roundResultStamp = tonumber(self.RoundResultStamp or 0) or 0,
        sectionCount = 6,
        powerOutage = (self.PKB and self.PKB.active == true and self.PKB.phase == "outage") or false,
    }

    if includeDynamic then
        state.modules = {}
        state.activeSlots = deepCopy(self.ModuleSlots or {})
        state.radioactiveSeal = deepCopy(self.RadioSeal or {progress = 0, holding = false, active = false})
        state.seismicControl = deepCopy(self.Seismic or {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}})
        state.pkbControl = deepCopy(self.PKB or {active = false, phase = "idle", timer = 0, colors = {}, connections = {}, blocked = {}, completed = {}, completedPaths = {}, dragVisited = {}, lastDragKey = nil})
    end
    if includeChat then
        if includeStatic then
            state.chatLog = deepCopy(self.ChatLog or {})
        else
            local lastAck = self:GetLastChatAck(ply)
            state.chatLog = {}
            for _, entry in ipairs(self.ChatLog or {}) do
                if math.floor(tonumber(entry and entry.seq or 0) or 0) > lastAck then
                    state.chatLog[#state.chatLog + 1] = deepCopy(entry)
                end
            end
        end
    end

    local function attachPanelModules()
        if not includeDynamic then return end
        for _, id in ipairs(self.ModuleSlots or {}) do
            local module = deepCopy(self.Modules[id])
            if module and id == "override" then
                module.targetBits = nil
                module.baseBits = nil
                module.flags = nil
            end
            if module then
                state.modules[id] = module
            end
        end
    end

    local function attachManual()
        if includeManual then
            state.manual = deepCopy(self.ManualData)
        end
        state.moduleStatus = {
            wiresSolved = self.Modules.wires and self.Modules.wires.solved or false,
            keypadSolved = self.Modules.keypad and self.Modules.keypad.solved or false,
            spiralSolved = self.Modules.spiral and self.Modules.spiral.solved or false,
            tamperSolved = self.Modules.tamper and self.Modules.tamper.solved or false,
            memorySolved = self.Modules.memory and self.Modules.memory.solved or false,
            redblueSolved = self.Modules.redblue and self.Modules.redblue.solved or false,
            minesSolved = self.Modules.mines and self.Modules.mines.solved or false,
            electricSolved = self.Modules.electric and self.Modules.electric.solved or false,
            twinSolved = self.Modules.twin and self.Modules.twin.solved or false,
            thermoSolved = self.Modules.thermo and self.Modules.thermo.solved or false,
            overrideSolved = self.Modules.override and self.Modules.override.solved or false,
            calibrationSolved = self.Modules.calibration and self.Modules.calibration.solved or false,
            interruptSolved = self.Modules.interrupt and self.Modules.interrupt.solved or false,
            reactorSolved = self.Modules.reactor and self.Modules.reactor.solved or false,
            drillSolved = self.Modules.drill and self.Modules.drill.solved or false,
        }
    end

    if role == "panel" then
        attachPanelModules()
    elseif role == "manual" then
        attachManual()
    elseif role == "solo" then
        attachPanelModules()
        attachManual()
    end

    return state
end


function ENT:NotifyPlayers(msg)
    self:PushChatEntry("system", "SYSTEM", msg)
end

function ENT:GetConfiguredStartTime()
    local selected = self.KTNESelectedStartTime or self:GetNWInt("KTNE_SelectedStartTime", DEFAULT_START_TIME)
    return math.Clamp(math.floor(tonumber(selected) or DEFAULT_START_TIME), 60, 480)
end

function ENT:StartGame()
    self.ChatLog = {}
    self.ChatSeq = 0
    self._loggedSolved = {}
    self:GenerateModules()
    self:SetGameActive(true)
    local startTime = self:GetConfiguredStartTime()
    self:SetTimeRemaining(startTime)
    self:SetStrikes(0)
    self:ClearRoundFlags()
    self._nextSecondTick = CurTime() + 1
    self._nextIdleSync = CurTime() + 1
    self:NotifyPlayers("Bomb started. Defuse all visible modules before the timer reaches zero. Current timer: " .. formatChatTimeRemaining(startTime) .. ".")
    self:OpenUIFor(self.PanelPlayer)
    self:OpenUIFor(self.ManualPlayer)
    self:SyncState(true)
end

function ENT:AllSolved()
    if not self.ModuleSlots or #self.ModuleSlots == 0 then return false end
    for _, id in ipairs(self.ModuleSlots) do
        if id ~= "blank" then
            local module = self.Modules[id]
            if not module or not module.solved then return false end
        end
    end
    return true
end

function ENT:OtherModulesSolvedExcept(skipId)
    for _, id in ipairs(self.ModuleSlots or {}) do
        if id ~= skipId and id ~= "blank" then
            local module = self.Modules[id]
            if module and not module.solved then return false end
        end
    end
    return true
end

function ENT:AddStrike(reason)
    self:SetStrikes(self:GetStrikes() + 1)
    self:NotifyPlayers(reason .. " Strike " .. self:GetStrikes() .. "/3")
    if self:GetStrikes() >= 3 then
        self:ExplodeBomb("Too many strikes!")
    else
        self:SyncState(true)
    end
end

function ENT:FinishRound(wasSuccess, reason)
    if self.RoundEnding then return end
    self.RoundEnding = true
    self:SetGameActive(false)

    local rec, seen = {}, {}
    for _, ply in ipairs({self.PanelPlayer, self.ManualPlayer}) do
        if IsValid(ply) and not seen[ply] then
            seen[ply] = true
            table.insert(rec, ply)
        end
    end
      if wasSuccess then
          self.RoundSuccess = true
          self.RoundResultStamp = CurTime()
          self:NotifyPlayers(reason or "Bomb defused!")
          self:SyncState(true)
      else
          self.RoundSuccess = false
          self.RoundResultStamp = 0
          if #rec > 0 then
              net.Start("ktne_close_ui_mp")
                  net.WriteEntity(self)
              net.Send(rec)
          end
          self:NotifyPlayers(reason or "The bomb exploded!")
          if not (KTNE_ExplosionSupport and KTNE_ExplosionSupport.RunFailureEffects and KTNE_ExplosionSupport.RunFailureEffects(self, reason)) then
              local effect = EffectData()
            effect:SetOrigin(self:GetPos())
            util.Effect("Explosion", effect, true, true)
            self:EmitSound("BaseExplosionEffect.Sound")

            local dmg = DamageInfo()
            dmg:SetDamage(120)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetAttacker(IsValid(self) and self or game.GetWorld())
            dmg:SetInflictor(IsValid(self) and self or game.GetWorld())
            util.BlastDamageInfo(dmg, self:GetPos(), 220)
        end
    end

      timer.Simple(wasSuccess and 0.5 or 0.9, function()
          if not IsValid(self) then return end
          self:Remove()
      end)
  end

function ENT:ExplodeBomb(reason)
    if KTNE_ExplosionSupport and KTNE_ExplosionSupport.TryBeginInevitable and KTNE_ExplosionSupport.TryBeginInevitable(self, reason) then
        return
    end
    self:FinishRound(false, reason)
end

function ENT:DefuseBomb()
    self:FinishRound(true, "Bomb defused!")
end

function ENT:ResetProgressForOutage()
    for id, module in pairs(self.Modules or {}) do
        if module and not module.solved then
            if id == "keypad" then
                module.progress = 1
            elseif id == "memory" then
                module.started = false
                module.currentRound = 0
                module.inputIndex = 1
                module.previewSequence = {}
            elseif id == "tamper" then
                module.connections = {}
            elseif id == "twin" then
                module.progress = 1
                module.cut = {}
            elseif id == "override" then
                module.switches = {0,0,0}
            elseif id == "calibration" then
                module.hits = 0
                module.phase = "idle"
                module.currentLight = 0
                module.lightVisible = false
                module.nextSwitch = 0
            elseif id == "interrupt" then
                module.currentRound = 1
                module.phase = "idle"
                module.clickCount = 0
                module.deadline = 0
            elseif id == "wires" then
                for _, wire in ipairs(module.wires or {}) do wire.cut = false end
            end
        end
    end
end


function ENT:HandlePanelAction(ply, action, data)
    data = self:SanitizeActionData(action, data)
    if self:IsActionRateLimited(ply, action) then return end

    if action == "debug_start_role" then
        self:StartDebugGameFor(ply, tostring((data and data.role) or "panel"))
        return
    elseif action == "leave_bomb" then
        self:ReleasePlayer(ply)
        return
    elseif action == "chat_ack" then
        if self:IsPanelUser(ply) or self:IsManualUser(ply) then
            self:SetLastChatAck(ply, data and data.seq)
        end
        return
    end

    if not self:GetGameActive() then return end
    if action == "chat_message" then
        if not (self:IsPanelUser(ply) or self:IsManualUser(ply)) then return end
        local text = tostring((data and data.text) or ""):gsub("[%c]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return end
        local speaker = self:IsPanelUser(ply) and "Primary" or "Secondary"
        self:PushChatEntry("chat", speaker, text)
        self:SyncState(true)
        return
    end
    if action == "radio_hold" or action == "seismic_press" or action == "identify_bomb" or action == "pkb_begin" or action == "pkb_hover" or action == "pkb_release" then
        if not (self:IsPanelUser(ply) or self:IsManualUser(ply)) then return end
    elseif not self:IsPanelUser(ply) then
        return
    end

    if action == "identify_bomb" then
        local guess = string.upper(tostring(data.make or ""))
        self.IdentifiedMake = guess
        if guess == string.upper(tostring(self.MakeName or "")) then
            self.BombIdentified = true
            self:NotifyPlayers("Bomb make identified: " .. tostring(self.MakeName))
        else
            self:NotifyPlayers("Incorrect bomb identification: " .. guess)
        end
        self:SyncState(true)
        return
    end
    if not self.BombIdentified then
        self:NotifyPlayers("Identify the bomb make from the manual before interacting with covered modules.")
        self:SyncState(true)
        return
    end

    local pkb = self.PKB or {active = false, phase = "idle"}
    if pkb.active == true and pkb.phase == "outage" and action ~= "pkb_begin" and action ~= "pkb_hover" and action ~= "pkb_release" then
        self:NotifyPlayers("Power outage in progress. Restore power from the datapad terminal first.")
        self:SyncState(true)
        return
    end

    local thermo = self.Modules.thermo
    if thermo and not thermo.solved and action ~= "thermo_set" then
        self:AddStrike("Thermo Regulation must be solved first.")
        return
    end

    if action == "thermo_set" then
        local module = self.Modules.thermo
        if not module or module.solved then return end
        local channel = tostring(data.channel or "")
        local value = math.Clamp(math.floor(tonumber(data.value or 0) or 0), 0, 99)

        if channel == "coolant" then
            module.currentCoolant = value
            if value == module.targetCoolant then
                module.coolantLocked = true
                self:NotifyPlayers("Coolant flow balanced.")
            else
                self:AddStrike("Incorrect coolant flow.")
            end
        elseif channel == "exhaust" then
            if not module.coolantLocked then
                self:AddStrike("Adjust coolant flow first.")
                return
            end
            module.currentExhaust = value
            if value == module.targetExhaust then
                module.solved = true
                self:NotifyPlayers("Thermo Regulation module solved.")
            else
                self:AddStrike("Incorrect heat exhaust flow.")
            end
        end

    elseif action == "cut_wire" then
        local module = self.Modules.wires
        if not module or module.solved then return end
        local idx = tonumber(data.index or 0)
        local wire = module.wires[idx]
        if not wire or wire.cut then return end

        wire.cut = true
        if idx == module.correctIndex then
            module.solved = true
            self:NotifyPlayers("Wire module solved.")
        else
            self:AddStrike("Wrong wire cut.")
        end

    elseif action == "press_symbol" then
        local module = self.Modules.keypad
        if not module or module.solved then return end
        local sym = tostring(data.symbol or "")
        local expected = module.expected[module.progress]

        if sym == expected then
            module.progress = module.progress + 1
            if module.progress > #module.expected then
                module.solved = true
                self:NotifyPlayers("Keypad module solved.")
            end
        else
            module.progress = 1
            self:AddStrike("Wrong keypad button.")
        end

    elseif action == "spiral_adjust" then
        local module = self.Modules.spiral
        if not module or module.solved then return end
        local idx = tonumber(data.index or 0)
        local delta = tonumber(data.delta or 0)
        if idx < 1 or idx > #module.current or (delta ~= 1 and delta ~= -1) then return end
        module.current[idx] = (module.current[idx] + delta) % 10
        if module.current[idx] < 0 then module.current[idx] = module.current[idx] + 10 end

        local okay = true
        for i = 1, #module.combo do
            if module.current[i] ~= module.combo[i] then
                okay = false
                break
            end
        end
        if okay then
            module.solved = true
            self:NotifyPlayers("Spiral lock solved.")
        end

    elseif action == "tamper_connect" then
        local module = self.Modules.tamper
        if not module or module.solved then return end
        local source = tonumber(data.source or 0)
        local receiver = tonumber(data.receiver or 0)
        if source < 1 or source > #module.leftColors or receiver < 1 or receiver > #module.rightColors then return end

        module.connections[source] = receiver

        local allPlaced = true
        local used = {}
        for i = 1, #module.leftColors do
            local r = module.connections[i]
            if not r then
                allPlaced = false
                break
            end
            if used[r] then
                self:AddStrike("Two wires were placed into the same receiver.")
                module.connections = {}
                self:SyncState(true)
                return
            end
            used[r] = true
        end

        if allPlaced then
            local okay = true
            for i = 1, #module.correctMap do
                if module.connections[i] ~= module.correctMap[i] then
                    okay = false
                    break
                end
            end
            if okay then
                module.solved = true
                self:NotifyPlayers("Anti-tamper module solved.")
            else
                module.connections = {}
                self:AddStrike("Anti-tamper wiring mismatch.")
            end
        end

    elseif action == "memory_press" then
        local module = self.Modules.memory
        if not module or module.solved then return end
        local key = tonumber(data.key or 0)
        if key < 1 or key > 9 then return end

        if not module.started then
            if key ~= module.startKey then return end
            module.started = true
            module.currentRound = 1
            module.inputIndex = 1
            module.previewNonce = (module.previewNonce or 0) + 1
            module.previewSequence = {module.sequence[1]}
            self:NotifyPlayers("Memory sequence started.")
        else
            local expected = module.sequence[module.inputIndex]
            if key == expected then
                if module.inputIndex >= module.currentRound then
                    if module.currentRound >= 4 then
                        module.solved = true
                        module.previewSequence = {}
                        self:NotifyPlayers("Memory module solved.")
                    else
                        module.currentRound = module.currentRound + 1
                        module.inputIndex = 1
                        module.previewNonce = (module.previewNonce or 0) + 1
                        module.previewSequence = {}
                        for i = 1, module.currentRound do
                            module.previewSequence[i] = module.sequence[i]
                        end
                    end
                else
                    module.inputIndex = module.inputIndex + 1
                end
            else
                module.started = false
                module.currentRound = 0
                module.inputIndex = 1
                module.previewSequence = {}
                self:AddStrike("Memory pattern mismatch.")
            end
        end

    elseif action == "press_redblue" then
        local module = self.Modules.redblue
        if not module or module.solved then return end
        local color = tostring(data.color or "")
        if color ~= "Red" and color ~= "Blue" then return end
        if not self:OtherModulesSolvedExcept("redblue") then
            self:AddStrike("Red & Blue button must be completed last.")
            return
        end
        if color == module.correct then
            module.solved = true
            self:NotifyPlayers("Red & Blue button solved.")
        else
            self:AddStrike("Wrong Red & Blue button.")
        end

    elseif action == "mines_click" then
        local module = self.Modules.mines
        if not module or module.solved then return end
        local x = tonumber(data.x or 0)
        local y = tonumber(data.y or 0)
        if x < 1 or x > 5 or y < 1 or y > 5 then return end
        if x == module.targetX and y == module.targetY then
            module.solved = true
            self:NotifyPlayers("Minesweeper module solved.")
        else
            self:AddStrike("Wrong payload tile selected.")
        end

    elseif action == "electric_connect" then
        local module = self.Modules.electric
        if not module or module.solved then return end
        local color = tostring(data.color or "")
        if color ~= "Red" and color ~= "Green" and color ~= "Blue" then return end
        if color == module.targetColor then
            module.connectedTo = color
            module.solved = true
            self:NotifyPlayers("Electric Flow Control solved.")
        else
            self:AddStrike("Incorrect electric flow route selected.")
        end


    elseif action == "radio_hold" then
        local seal = self.RadioSeal or {active = false, progress = 0, holding = false, holdUntil = 0}
        if seal.active then
            local holding = tobool(data.holding)
            if holding then
                seal.holding = true
                seal.holdUntil = CurTime() + 0.25
                seal.progress = math.max(0, math.floor((seal.progress or 0) - 1))
            else
                seal.holding = false
                seal.holdUntil = 0
            end
            self.RadioSeal = seal
        end

    elseif action == "seismic_press" then
        local seismic = self.Seismic or {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}}
        if seismic.active ~= true or seismic.phase ~= "alarm" then return end
        local idx = math.Clamp(math.floor(tonumber(data.index or 0) or 0), 1, 5)
        local allowed = false
        for _, v in ipairs(seismic.pattern or {}) do
            if v == idx then allowed = true break end
        end
        if not allowed then
            self:AddStrike("Incorrect seismic pillar selected.")
            return
        end
        seismic.pressed = seismic.pressed or {}
        seismic.pressed[idx] = true
        local allPressed = true
        for _, v in ipairs(seismic.pattern or {}) do
            if not seismic.pressed[v] then
                allPressed = false
                break
            end
        end
        if allPressed then
            self.Seismic = {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}, alertText = ""}
    self.PKB = buildPKBState()
            self:NotifyPlayers("Seismic activity stabilized. New pattern uploaded.")
        else
            self.Seismic = seismic
        end


    elseif action == "pkb_begin" then
        local pkb = self.PKB or {active = false, phase = "idle"}
        if pkb.active ~= true or pkb.phase ~= "outage" then return end
        local color = tostring(data.color or "")
        local x = tonumber(data.x or 0)
        local y = tonumber(data.y or 0)
        local conn = pkb.connections and pkb.connections[color] or nil
        if not conn or pkb.completed[color] then return end
        if x ~= conn.output.x or y ~= conn.output.y then return end
        pkb.draggingColor = color
        pkb.dragVisited = {[pkbKey(x, y)] = true}
        pkb.lastDragKey = pkbKey(x, y)
        self.PKB = pkb

    elseif action == "pkb_hover" then
        local pkb = self.PKB or {active = false, phase = "idle"}
        if pkb.active ~= true or pkb.phase ~= "outage" then return end
        local color = tostring(data.color or "")
        if pkb.draggingColor ~= color then return end
        local x = tonumber(data.x or 0)
        local y = tonumber(data.y or 0)
        if x < 1 or x > PKB_GRID_W or y < 1 or y > PKB_GRID_H then return end
        local key = pkbKey(x, y)
        local lastX, lastY = pkb.lastDragKey and pkb.lastDragKey:match("^(%-?%d+):(%-?%d+)$")
        lastX, lastY = tonumber(lastX), tonumber(lastY)
        if not lastX or not lastY then return end
        if math.abs(x - lastX) + math.abs(y - lastY) ~= 1 then return end
        if pkb.blocked and pkb.blocked[key] then
            self:AddStrike("Power restoration path crossed a blocked circuit tile.")
            regenPKBLayout(pkb)
            resetPKBOutageState(pkb)
            self.PKB = pkb
            return
        end
        for completedColor, path in pairs(pkb.completedPaths or {}) do
            if completedColor ~= color and path[key] then
                self:AddStrike("Power restoration path crossed an occupied circuit tile.")
                regenPKBLayout(pkb)
                resetPKBOutageState(pkb)
                self.PKB = pkb
                return
            end
        end
        pkb.dragVisited[key] = true
        pkb.lastDragKey = key
        self.PKB = pkb

    elseif action == "pkb_release" then
        local pkb = self.PKB or {active = false, phase = "idle"}
        if pkb.active ~= true or pkb.phase ~= "outage" then return end
        local color = tostring(data.color or "")
        if pkb.draggingColor ~= color then return end
        local x = tonumber(data.x or -1)
        local y = tonumber(data.y or -1)
        local conn = pkb.connections and pkb.connections[color] or nil
        local success = conn and x == conn.receiver.x and y == conn.receiver.y
        pkb.draggingColor = nil
        pkb.lastDragKey = nil
        if not success then
            pkb.dragVisited = {}
            self:AddStrike("Power restoration connection released before the correct receiver.")
            regenPKBLayout(pkb)
            resetPKBOutageState(pkb)
            self.PKB = pkb
            return
        end
        pkb.completed[color] = true
        pkb.completedPaths[color] = deepCopy(pkb.dragVisited or {})
        pkb.dragVisited = {}
        local allDone = true
        for _, c in ipairs(pkb.colors or {}) do
            if not pkb.completed[c] then allDone = false break end
        end
        if allDone then
            regenPKBLayout(pkb)
            pkb.phase = "active"
            pkb.timer = math.random(48, 65)
            self.PKB = pkb
            self:NotifyPlayers("Power restored. Datapad grid reset for the next outage cycle.")
        else
            self.PKB = pkb
        end



    elseif action == "reactor_code" then
        local module = self.Modules.reactor
        if not module or module.solved or module.unlocked then return end
        local code = string.upper(tostring(data.code or "")):gsub("[^A-Z]", "")
        if #code ~= 4 then return end
        if code == tostring(module.code or "") then
            module.unlocked = true
            module.input = ""
            module.cleared = 0
            module.activeCount = 0
            module.grid = {
                {false, false, false},
                {false, false, false},
                {false, false, false},
            }
            module.nextSpawn = CurTime() + 0.5
            self:NotifyPlayers("Reactor face plate removed.")
        else
            self:AddStrike("Incorrect reactor access code.")
            module.input = ""
            self:NextThink(CurTime() + 0.25)
            return true
        end

    elseif action == "reactor_clear" then
        local module = self.Modules.reactor
        if not module or module.solved or not module.unlocked then return end
        local x = math.Clamp(tonumber(data.x or 0) or 0, 1, 3)
        local y = math.Clamp(tonumber(data.y or 0) or 0, 1, 3)
        if not module.grid or not module.grid[y] or module.grid[y][x] ~= true then return end
        module.grid[y][x] = false
        module.activeCount = math.max(0, (module.activeCount or 0) - 1)
        module.cleared = (module.cleared or 0) + 1
        module.danger = (module.activeCount or 0) >= 6
        if module.cleared >= 20 then
            module.solved = true
            module.danger = false
            self:NotifyPlayers("Reactor Dismantle solved.")
        end

elseif action == "drill_code" then
    local module = self.Modules.drill
    if not module or module.solved or module.unlocked then return end
    local code = tostring(data.code or ""):gsub("[^%d]", "")
    if #code ~= 6 then return end
    if code == tostring(module.code or "") then
        module.unlocked = true
        module.input = ""
        module.lastUnlockTime = self:GetTimeRemaining()
        module.targetCuts = drillTargetsForTime(self:GetTimeRemaining())
        module.cut = {}
        self:NotifyPlayers("Tectonic drill controls unlocked.")
    else
        self:AddStrike("Incorrect tectonic drill override code.")
        module.input = ""
    end

elseif action == "drill_cut" then
    local module = self.Modules.drill
    if not module or module.solved or not module.unlocked then return end
    local color = tostring(data.color or "")
    local shouldCut = false
    for _, c in ipairs(module.targetCuts or {}) do
        if c == color then shouldCut = true break end
    end
    if module.cut[color] then return end
    if not shouldCut then
        self:SetStrikes(3)
        self:ExplodeBomb("Incorrect tectonic drill wire was cut.")
        return
    end
    module.cut[color] = true
    local count = 0
    for _, c in ipairs(module.targetCuts or {}) do
        if module.cut[c] then count = count + 1 end
    end
    if count >= 3 then
        module.solved = true
        self:NotifyPlayers("Tectonic drill disabled.")
    end

elseif action == "override_toggle" then
        local module = self.Modules.override
        if not module or module.solved then return end
        local index = tonumber(data.index or 0)
        if index < 1 or index > 3 then return end
        module.switches[index] = module.switches[index] == 1 and 0 or 1

    elseif action == "override_check" then
        local module = self.Modules.override
        if not module or module.solved then return end
        local okay = true
        for i = 1, 3 do
            if (module.switches[i] or 0) ~= (module.targetBits[i] or 0) then
                okay = false
                break
            end
        end
        if okay then
            module.solved = true
            self:NotifyPlayers("Emergency Nuclear Override solved.")
        else
            self:AddStrike("Incorrect Emergency Nuclear Override combination.")
        end

    elseif action == "calibration_start" then
        local module = self.Modules.calibration
        if not module or module.solved then return end
        local index = tonumber(data.index or 0)
        if module.phase ~= "idle" then return end
        if index ~= module.startButton then
            module.hits = 0
            module.phase = "idle"
            module.currentLight = 0
            module.lightVisible = false
            self:AddStrike("Incorrect calibration starter button.")
            return
        end
        module.phase = "grace"
        module.currentLight = 0
        module.lightVisible = false
        module.nextSwitch = CurTime() + 2

    elseif action == "calibration_press" then
        local module = self.Modules.calibration
        if not module or module.solved then return end
        if module.phase ~= "running" then
            module.hits = 0
            module.phase = "idle"
            module.currentLight = 0
            module.lightVisible = false
            self:AddStrike("Calibration press was mistimed.")
            return
        end
        if not module.lightVisible or module.currentLight ~= module.targetIndex then
            module.hits = 0
            module.phase = "idle"
            module.currentLight = 0
            module.lightVisible = false
            self:AddStrike("Calibration press was mistimed.")
            return
        end
        module.hits = (module.hits or 0) + 1
        if module.hits >= (module.requiredHits or 7) then
            module.solved = true
            module.phase = "solved"
            module.currentLight = 0
            module.lightVisible = false
            self:NotifyPlayers("Seismic Calibration solved.")
        else
            module.lightVisible = false
            module.currentLight = 0
            module.nextSwitch = CurTime() + 0.5
        end

    elseif action == "interrupt_start" then
        local module = self.Modules.interrupt
        if not module or module.solved then return end
        if module.phase ~= "idle" then return end
        module.phase = "running"
        module.clickCount = 0
        local round = module.rounds[module.currentRound or 1]
        module.deadline = CurTime() + (round and round.time or 0)

    elseif action == "interrupt_click" then
        local module = self.Modules.interrupt
        if not module or module.solved then return end
        if module.phase ~= "running" then return end
        module.clickCount = (module.clickCount or 0) + 1
        local round = module.rounds[module.currentRound or 1]
        if module.clickCount > (round and round.target or 0) then
            module.phase = "idle"
            module.currentRound = 1
            module.clickCount = 0
            module.deadline = 0
            self:AddStrike("Interrupt Vibration Pattern overshot the required clicks.")
            return
        end

    elseif action == "twin_cut" then
        local module = self.Modules.twin
        if not module or module.solved then return end
        local index = tonumber(data.index or 0)
        local color = module.displayOrder[index]
        if not color or module.cut[index] then return end

        local expectedColor = module.correctOrder[module.progress or 1]
        if color ~= expectedColor then
            self:SetStrikes(3)
            self:ExplodeBomb("Incorrect wire cut on Twin Payload Disconnection.")
            return
        end

        module.cut[index] = true
        module.progress = (module.progress or 1) + 1
        if module.progress > #module.correctOrder then
            module.solved = true
            self:NotifyPlayers("Twin Payload Disconnection solved.")
        else
            self:NotifyPlayers("Twin Payload progress: " .. tostring(module.progress - 1) .. "/6")
        end
    end

    self:CheckCompletionLogs()
    if self:AllSolved() then
        self:DefuseBomb()
    else
        self:SyncState(true)
    end
end

net.Receive("ktne_action_mp", function(len, ply)
    if len > MAX_ACTION_MSG_BITS then return end
    local ent = net.ReadEntity()
    local action = net.ReadString()
    local data = net.ReadTable() or {}
    if not IsValid(ent) then return end
    local class = ent:GetClass()
    if class ~= "sent_ktne_bomb" and class ~= "sent_ktne_abberant_mp" and class ~= "sent_ktne_seismic_mp" and class ~= "sent_ktne_pkb_mp" then return end
    ent:HandlePanelAction(ply, action, data)
end)

function ENT:SyncState(force, syncFlags)
    syncFlags = syncFlags or {}
    local sendChat = syncFlags.chat == true or self._chatDirty == true
    if sendChat then syncFlags.chat = true end
    local bypassThrottle = syncFlags.bypassThrottle == true
    if not bypassThrottle and self.LastSync > CurTime() then return end
    self.LastSync = CurTime() + 0.08
    local includeStatic = syncFlags.includeStatic == true

    local targets = {}
    if IsValid(self.PanelPlayer) then table.insert(targets, self.PanelPlayer) end
    if IsValid(self.ManualPlayer) and self.ManualPlayer ~= self.PanelPlayer then table.insert(targets, self.ManualPlayer) end
    if #targets == 0 then return end

    for _, ply in ipairs(targets) do
        local role = self:GetPlayerRole(ply)
        net.Start("ktne_sync_state_mp")
            net.WriteEntity(self)
            net.WriteString(role)
            net.WriteTable(self:GetClientStateFor(role, includeStatic, syncFlags, ply))
        net.Send(ply)
    end

    if sendChat then
        self._chatDirty = false
    end
end

function ENT:Think()
    self:UnassignInvalidPlayers()
    local now = CurTime()
    local nextTick = now + 0.25
    local shouldSync = false
    local chatChanged = false

    if self:GetGameActive() then
        self._nextSecondTick = self._nextSecondTick or now
        if now >= self._nextSecondTick then
            local secondTicks = math.max(1, math.floor(now - self._nextSecondTick) + 1)
            self._nextSecondTick = self._nextSecondTick + secondTicks
            shouldSync = true

            local t = self:GetTimeRemaining()
            if t > 0 then
                local newT = t
                for _ = 1, secondTicks do
                    newT = newT - 1
                    if newT == 240 or newT == 180 or newT == 120 or newT == 60 or newT == 30 then
                        self:NotifyPlayers("Time left: " .. formatChatTimeRemaining(newT))
                    end
                    if newT <= 0 then
                        self:SetTimeRemaining(0)
                        self:ExplodeBomb("Time ran out!")
                        self:NextThink(nextTick)
                        return true
                    end
                end
                self:SetTimeRemaining(newT)
            end

            local seal = self.RadioSeal or {active = false, progress = 0, holding = false, holdUntil = 0}
            if seal.active then
                seal.holding = (seal.holdUntil or 0) > now
                if not seal.holding then
                    for _ = 1, secondTicks do
                        seal.progress = math.min(100, math.floor((seal.progress or 0) + math.random(1, 3)))
                        if seal.progress >= 100 then break end
                    end
                end
                self.RadioSeal = seal

                if seal.progress >= 100 then
                    self:SetStrikes(3)
                    self:ExplodeBomb("Radioactive seal failed!")
                    self:NextThink(nextTick)
                    return true
                end
            else
                seal.holding = false
                seal.holdUntil = 0
                seal.progress = math.Clamp(tonumber(seal.progress or 0) or 0, 0, 99)
                self.RadioSeal = seal
            end

            local seismic = self.Seismic or {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}}
            if seismic.active then
                for _ = 1, secondTicks do
                    seismic.timer = math.max(0, math.floor(tonumber(seismic.timer or 0) or 0) - 1)
                    if seismic.phase == "preview" then
                        if seismic.timer <= 0 then
                            seismic.phase = "dormant"
                            seismic.timer = math.random(30, 52)
                            seismic.pressed = {}
                            seismic.alertText = "Seismic memory window closed. Stand by for activity."
                        end
                    elseif seismic.phase == "dormant" then
                        if seismic.timer <= 0 then
                            seismic.phase = "alarm"
                            seismic.timer = 15
                            seismic.pressed = {}
                            seismic.alertText = "SEISMIC ACTIVITY IN PROGRESS, STABILIZATION REQUIRED IMMEDIATELY"
                            self:NotifyPlayers("Seismic activity in progress. Stabilize the marked pillars now.")
                            chatChanged = true
                        end
                    elseif seismic.phase == "alarm" then
                        if seismic.timer <= 0 then
                            self:SetStrikes(3)
                            self:ExplodeBomb("Seismic activity was not stabilized in time.")
                            return true
                        end
                    end
                end
                self.Seismic = seismic
            else
                self.Seismic = {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}}
            end

            local pkb = self.PKB or {active = false, phase = "idle", timer = 0}
            if pkb.active then
                for _ = 1, secondTicks do
                    pkb.timer = math.max(0, math.floor(tonumber(pkb.timer or 0) or 0) - 1)
                    if pkb.phase == "active" then
                        if pkb.timer <= 0 then
                            resetPKBOutageState(pkb)
                            self:ResetProgressForOutage()
                            self:NotifyPlayers("Power outage detected. Restore the PKB circuits from the datapad terminal.")
                            shouldSync = true
                            chatChanged = true
                            break
                        end
                    elseif pkb.phase == "outage" then
                        pkb.timer = 0
                        break
                    end
                end
                self.PKB = pkb
            else
                self.PKB = {active = false, phase = "idle", timer = 0, colors = {}, connections = {}, blocked = {}, completed = {}, completedPaths = {}, draggingColor = nil, dragVisited = {}, lastDragKey = nil}
            end
        end

        local interrupt = self.Modules and self.Modules.interrupt or nil
        if interrupt and not interrupt.solved and interrupt.phase == "running" then
            local round = interrupt.rounds[interrupt.currentRound or 1]
            if CurTime() >= (interrupt.deadline or 0) then
                if interrupt.clickCount == (round and round.target or 0) then
                    if (interrupt.currentRound or 1) >= #interrupt.rounds then
                        interrupt.solved = true
                        interrupt.phase = "solved"
                        interrupt.deadline = 0
                        self:NotifyPlayers("Interrupt Vibration Pattern solved.")
                        chatChanged = true
                    else
                        interrupt.currentRound = (interrupt.currentRound or 1) + 1
                        interrupt.clickCount = 0
                        round = interrupt.rounds[interrupt.currentRound]
                        interrupt.deadline = CurTime() + (round and round.time or 0)
                    end
                else
                    interrupt.phase = "idle"
                    interrupt.currentRound = 1
                    interrupt.clickCount = 0
                    interrupt.deadline = 0
                    self:AddStrike("Interrupt Vibration Pattern did not reach the required clicks in time.")
                    self:NextThink(nextTick)
                    return true
                end
            end
        end


        local reactor = self.Modules and self.Modules.reactor or nil
        if reactor and reactor.unlocked and not reactor.solved then
            reactor.nextSpawn = tonumber(reactor.nextSpawn or 0) or 0
            if CurTime() >= reactor.nextSpawn then
                local empty = {}
                reactor.activeCount = 0
                for yy = 1, 3 do
                    for xx = 1, 3 do
                        if reactor.grid[yy][xx] then
                            reactor.activeCount = reactor.activeCount + 1
                        else
                            empty[#empty + 1] = {x = xx, y = yy}
                        end
                    end
                end
                if #empty > 0 then
                    local pick = empty[math.random(#empty)]
                    reactor.grid[pick.y][pick.x] = true
                    reactor.activeCount = reactor.activeCount + 1
                end
                reactor.danger = reactor.activeCount >= 6
                reactor.nextSpawn = CurTime() + 0.5
                if reactor.activeCount >= 9 then
                    self:SetStrikes(3)
                    self:ExplodeBomb("Reactor core overflowed!")
                    return true
                end
            end
        end

        local calibration = self.Modules and self.Modules.calibration or nil
        if calibration and not calibration.solved then
            if calibration.phase == "grace" and CurTime() >= (calibration.nextSwitch or 0) then
                calibration.phase = "running"
                calibration.lightVisible = true
                calibration.currentLight = math.random(1, 3)
                calibration.nextSwitch = CurTime() + 0.5
                shouldSync = true
            elseif calibration.phase == "running" and CurTime() >= (calibration.nextSwitch or 0) then
                if calibration.lightVisible then
                    calibration.lightVisible = false
                    calibration.currentLight = 0
                else
                    calibration.lightVisible = true
                    calibration.currentLight = math.random(1, 3)
                end
                calibration.nextSwitch = CurTime() + 0.5
                shouldSync = true
            end
        end


        chatChanged = self:CheckCompletionLogs() or chatChanged
        if shouldSync or chatChanged or now >= (self._nextIdleSync or 0) then
            self._nextIdleSync = now + 1
            self:SyncState(false, {dynamic = shouldSync, chat = chatChanged})
        end
    end

    self:NextThink(nextTick)
    return true
end

function ENT:OnRemove()
    local rec, seen = {}, {}
    for _, ply in ipairs({self.PanelPlayer, self.ManualPlayer}) do
        if IsValid(ply) and not seen[ply] then
            seen[ply] = true
            table.insert(rec, ply)
        end
    end
    if #rec > 0 then
        net.Start("ktne_close_ui_mp")
            net.WriteEntity(self)
        net.Send(rec)
    end
end

function ENT:SpawnFunction(ply, tr, class)
    if not tr.Hit then return end
    local ent = ents.Create(class)
    ent:SetPos(tr.HitPos + tr.HitNormal * 18)
    if IsValid(ply) then
        ent:SetCreator(ply)
        ent.KTNESpawnerSID = tostring(ply:SteamID64() or "")
        ent:SetNWString("KTNE_SpawnerSID", ent.KTNESpawnerSID)
    end
    ent.KTNESelectedStartTime = DEFAULT_START_TIME
    ent:SetNWInt("KTNE_SelectedStartTime", DEFAULT_START_TIME)
    ent:Spawn()
    ent:Activate()
    return ent
end










