AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("ktne_open_ui_mp")
util.AddNetworkString("ktne_sync_state_mp")
util.AddNetworkString("ktne_action_mp")
util.AddNetworkString("ktne_close_ui_mp")

local function deepCopy(tbl)
    if not istable(tbl) then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        out[k] = istable(v) and deepCopy(v) or v
    end
    return out
end

local wireColors = {"Red", "Blue", "Yellow", "White", "Black"}
local symbolPool = {"Alpha", "Star", "Omega", "Bolt", "Rune", "Moon", "Crown", "Anchor"}
local keypadRows = {
    {"Bolt", "Alpha", "Star", "Moon", "Anchor", "Rune", "Omega", "Crown"},
    {"Moon", "Crown", "Omega", "Alpha", "Rune", "Star", "Bolt", "Anchor"},
    {"Anchor", "Rune", "Bolt", "Crown", "Star", "Omega", "Moon", "Alpha"},
}
local tamperLeftColors = {"Red", "Yellow", "Blue", "Green"}
local tamperRightColors = {"Orange", "Grey", "Purple", "Black"}
local modulePoolOrder = {"wires", "keypad", "spiral", "tamper", "memory", "redblue", "mines"}

local moduleDisplayNames = {
    wires = "Wire Module",
    keypad = "Keypad Module",
    spiral = "Spiral Lock",
    tamper = "Anti-Tamper Device",
    memory = "Memory (Network Stabilization)",
    redblue = "Red & Blue Button",
    mines = "Minesweeper",
    electric = "Electric Flow Control",
    twin = "Twin Payload Disconnection",
    thermo = "Thermo Regulation",
    override = "Emergency Nuclear Override",
    calibration = "Seismic Calibration",
    interrupt = "Interrupt Vibration Pattern",
    reactor = "Reactor Dismantle",
    drill = "Disable the Tectonic Drill",
}

local function formatChatTimeRemaining(t)
    t = math.max(0, tonumber(t or 0) or 0)
    local m = math.floor(t / 60)
    local s = t % 60
    return string.format("%d:%02d", m, s)
end


local function buildSeismicState()
    local count = math.random(1, 5)
    local pool = {1, 2, 3, 4, 5}
    table.Shuffle(pool)
    local pattern = {}
    for i = 1, count do
        pattern[#pattern + 1] = pool[i]
    end
    table.sort(pattern)
    return {
        active = true,
        phase = "preview",
        timer = 15,
        pattern = pattern,
        pressed = {},
        alertText = "SEISMIC ACTIVITY CALIBRATION WINDOW OPEN",
    }
end
local PKB_GRID_W = 12
local PKB_GRID_H = 5

local function pkbKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function pkbHasRoute(blocked, startPos, endPos)
    local q = {{x = startPos.x, y = startPos.y}}
    local seen = {[pkbKey(startPos.x, startPos.y)] = true}
    local head = 1
    while q[head] do
        local node = q[head]
        head = head + 1
        if node.x == endPos.x and node.y == endPos.y then
            return true
        end
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, ny = node.x + d[1], node.y + d[2]
            if nx >= 1 and nx <= PKB_GRID_W and ny >= 1 and ny <= PKB_GRID_H then
                local key = pkbKey(nx, ny)
                if not seen[key] and (not blocked[key] or (nx == endPos.x and ny == endPos.y)) then
                    seen[key] = true
                    q[#q + 1] = {x = nx, y = ny}
                end
            end
        end
    end
    return false
end

local function buildPKBState()
    local rows = {1, 2, 3, 4, 5}
    table.Shuffle(rows)
    local colors = {"Red", "Green", "Blue"}
    local connections = {}
    for i, color in ipairs(colors) do
        local row = rows[i]
        connections[color] = {
            output = {x = 1, y = row},
            receiver = {x = PKB_GRID_W, y = row},
            row = row,
        }
    end

    local blocked = {}
    local blockedCount = math.random(4, 6)
    local attempts = 0
    while attempts < 256 do
        attempts = attempts + 1
        blocked = {}
        local innerAttempts = 0
        while table.Count(blocked) < blockedCount and innerAttempts < 1024 do
            innerAttempts = innerAttempts + 1
            local x = math.random(2, PKB_GRID_W - 1)
            local y = math.random(1, PKB_GRID_H)
            blocked[pkbKey(x, y)] = true
        end

        local valid = true
        for _, color in ipairs(colors) do
            local conn = connections[color]
            if not pkbHasRoute(blocked, conn.output, conn.receiver) then
                valid = false
                break
            end
        end
        if valid then break end
    end

    return {
        active = true,
        phase = "active",
        timer = math.random(48, 65),
        colors = colors,
        connections = connections,
        blocked = blocked,
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
    pkb.completed = {}
    pkb.completedPaths = {}
    pkb.draggingColor = nil
    pkb.dragVisited = {}
    pkb.lastDragKey = nil
end




local function sumDigits(str)
    local s = 0
    for c in tostring(str):gmatch("%d") do
        s = s + tonumber(c)
    end
    return s
end

local function serialDigits(str)
    local out = {}
    for c in tostring(str):gmatch("%d") do
        out[#out + 1] = tonumber(c)
    end
    if #out == 0 then out = {0, 0, 0, 0} end
    return out
end

local function buildWireModule(lastDigit)
    local wireCount = math.random(3, 5)
    local wires = {}
    local redCount = 0
    for i = 1, wireCount do
        local color = wireColors[math.random(#wireColors)]
        if color == "Red" then redCount = redCount + 1 end
        wires[i] = {color = color, cut = false}
    end

    local correctWire
    if lastDigit % 2 == 1 then
        correctWire = wireCount
    elseif redCount >= 2 then
        correctWire = 1
    else
        correctWire = math.max(1, math.floor((wireCount + 1) / 2))
    end

    return {
        id = "wires",
        solved = false,
        wires = wires,
        correctIndex = correctWire,
        redCount = redCount,
    }
end

local function buildKeypadModule(lastDigit)
    local pool = table.Copy(symbolPool)
    table.Shuffle(pool)
    local candidate = {pool[1], pool[2], pool[3], pool[4]}

    local rowIndex = (lastDigit % #keypadRows) + 1
    local ranking = {}
    for i, sym in ipairs(keypadRows[rowIndex]) do ranking[sym] = i end
    table.sort(candidate, function(a, b) return (ranking[a] or 999) < (ranking[b] or 999) end)
    local expected = table.Copy(candidate)
    local displayed = table.Copy(expected)
    table.Shuffle(displayed)

    return {
        id = "keypad",
        solved = false,
        symbols = displayed,
        expected = expected,
        progress = 1,
        rowIndex = rowIndex
    }
end

local function buildSpiralModule(digits)
    local combo = {}
    local current = {}
    for i = 1, 8 do
        local src = digits[((i - 1) % #digits) + 1] or 0
        combo[i] = (src + i) % 10
        current[i] = math.random(0, 9)
    end
    return {
        id = "spiral",
        solved = false,
        combo = combo,
        current = current
    }
end

local function buildTamperModule(digitSum)
    local leftColors = table.Copy(tamperLeftColors)
    local rightColors = table.Copy(tamperRightColors)
    local serialShift = (digitSum % #rightColors) + 1
    local correctMap = {}
    for i = 1, #leftColors do
        correctMap[i] = ((i + serialShift - 2) % #rightColors) + 1
    end

    return {
        id = "tamper",
        solved = false,
        leftColors = leftColors,
        rightColors = rightColors,
        correctMap = correctMap,
        connections = {},
        serialShift = serialShift
    }
end

local function buildMemoryModule(lastDigit)
    local startKey = lastDigit == 0 and 9 or math.Clamp(lastDigit, 1, 9)
    local sequence = {}
    for i = 1, 4 do
        sequence[i] = math.random(1, 9)
    end

    return {
        id = "memory",
        solved = false,
        startKey = startKey,
        sequence = sequence,
        started = false,
        currentRound = 0,
        inputIndex = 1,
        previewNonce = 0,
        previewSequence = {},
    }
end

local function buildRedBlueModule(digitSum, lastDigit)
    return {
        id = "redblue",
        solved = false,
        digitSum = digitSum,
        lastDigit = lastDigit,
        correct = "Blue",
        switches = {},
    }
end

local function normalizeMineCoord(n)
    local digit = math.abs(tonumber(n) or 0) % 10
    if digit > 5 then digit = digit - 5 end
    if digit == 0 then digit = 1 end
    return digit
end



local function buildElectricModule(serial)
    local numeric = tonumber(serial) or 0
    local target
    if numeric <= 2999 then
        target = "Red"
    elseif numeric <= 5999 then
        target = "Blue"
    else
        target = "Green"
    end

    return {
        id = "electric",
        solved = false,
        sourceColor = "Yellow",
        targetColor = target,
        options = {"Red", "Green", "Blue"},
        connectedTo = nil,
        numericSerial = numeric,
    }
end




local function buildTwinModule(serial)
    local displayOrder = {"Grey", "Yellow", "Red", "Green", "Blue", "Black"}
    local correctOrder = table.Copy(displayOrder)
    local digits = {}
    for c in tostring(serial):gmatch("%d") do
        digits[#digits + 1] = tonumber(c)
    end
    while #digits < 4 do digits[#digits + 1] = 0 end

    local function swapColor(a, b)
        local ia, ib
        for i, name in ipairs(correctOrder) do
            if name == a then ia = i end
            if name == b then ib = i end
        end
        if ia and ib then
            correctOrder[ia], correctOrder[ib] = correctOrder[ib], correctOrder[ia]
        end
    end

    local d3 = digits[#digits - 1] or 0
    local d4 = digits[#digits] or 0
    if d3 % 2 == 1 and d4 % 2 == 1 then
        swapColor("Yellow", "Grey")
    end
    if tostring(serial):find("0", 1, true) then
        swapColor("Black", "Blue")
    end
    local first = tostring(serial):sub(1, 1)
    if first == "5" or first == "3" then
        swapColor("Red", "Green")
    end

    return {
        id = "twin",
        solved = false,
        displayOrder = displayOrder,
        correctOrder = correctOrder,
        progress = 1,
        cut = {},
        lethal = true,
    }
end

local function buildOverrideModule(serial)
    local digits = serialDigits(serial)
    while #digits < 4 do digits[#digits + 1] = 0 end

    local baseBits = {math.random(0, 1), math.random(0, 1), math.random(0, 1)}
    local targetBits = table.Copy(baseBits)
    local flags = {
        hasFive = tostring(serial):find("5", 1, true) ~= nil,
        evenEnd = ((digits[#digits] or 0) % 2) == 0,
        zeroFrontOrRear = tostring(serial):sub(1, 1) == "0" or tostring(serial):sub(-1) == "0",
        middleOverFive = ((digits[2] or 0) + (digits[3] or 0)) > 5,
    }

    local function flip(index)
        targetBits[index] = targetBits[index] == 1 and 0 or 1
    end

    if flags.hasFive then
        flip(1)
        flip(2)
        flip(3)
    end
    if flags.evenEnd then
        flip(1)
    end
    if flags.zeroFrontOrRear then
        flip(3)
    end
    if flags.middleOverFive then
        flip(2)
        flip(3)
    end

    return {
        id = "override",
        solved = false,
        switches = {0, 0, 0},
        targetBits = targetBits,
        baseBits = baseBits,
        flags = flags,
    }
end

local function buildCalibrationModule(serial)
    local digits = serialDigits(serial)
    while #digits < 4 do digits[#digits + 1] = 0 end
    local colors = {"Yellow", "Blue", "Green"}
    local startButton = ((digits[1] or 0) % 3) + 1
    local targetIndex = ((digits[#digits] or 0) % 3) + 1
    return {
        id = "calibration",
        solved = false,
        startButton = startButton,
        targetIndex = targetIndex,
        targetColor = colors[targetIndex],
        hits = 0,
        requiredHits = 7,
        phase = "idle",
        nextSwitch = 0,
        lightVisible = false,
        currentLight = 0,
    }
end

local function buildInterruptModule()
    return {
        id = "interrupt",
        solved = false,
        rounds = {
            {target = 15, time = 6},
            {target = 7, time = 5},
            {target = 24, time = 9},
            {target = 18, time = 8},
        },
        currentRound = 1,
        phase = "idle",
        clickCount = 0,
        deadline = 0,
    }
end

local function serialToReactorCode(serial)
    local out = {}
    serial = tostring(serial or "0000")
    for i = 1, #serial do
        local d = tonumber(serial:sub(i, i)) or 0
        local n = (d == 0) and 26 or d
        out[#out + 1] = string.char(64 + n)
    end
    return table.concat(out)
end

local function buildReactorModule(serial)
    return {
        id = "reactor",
        solved = false,
        unlocked = false,
        code = serialToReactorCode(serial),
        input = "",
        cleared = 0,
        danger = false,
        grid = {
            {false, false, false},
            {false, false, false},
            {false, false, false},
        },
        activeCount = 0,
        nextSpawn = 0,
    }
end


local function reactorCodeToDrillDigits(code, serial, hasTamper)
    local digits = {}
    code = tostring(code or "")
    for i = 1, #code do
        local c = code:sub(i, i)
        if c:match("%u") then
            local n = string.byte(c) - 65
            digits[#digits + 1] = math.abs(n) % 10
        end
    end
    local serialNums = serialDigits(serial)
    while #serialNums < 4 do serialNums[#serialNums + 1] = 0 end
    if hasTamper then
        digits[#digits + 1] = serialNums[1] or 0
        digits[#digits + 1] = serialNums[3] or 0
    else
        digits[#digits + 1] = serialNums[2] or 0
        digits[#digits + 1] = serialNums[4] or 0
    end
    return table.concat(digits, "")
end

local function drillTargetsForTime(secondsLeft)
    if secondsLeft <= 60 then
        return {"Red", "Blue", "Black"}
    elseif secondsLeft <= 120 then
        return {"Green", "Yellow", "Red"}
    elseif secondsLeft <= 180 then
        return {"Black", "Red", "Yellow"}
    elseif secondsLeft <= 240 then
        return {"White", "Green", "Blue"}
    else
        return {"Blue", "White", "Yellow"}
    end
end

local function buildDrillModule(serial, hasTamper)
    local reactorCode = serialToReactorCode(serial)
    return {
        id = "drill",
        solved = false,
        unlocked = false,
        code = reactorCodeToDrillDigits(reactorCode, serial, hasTamper),
        input = "",
        wires = {"Red", "Blue", "Green", "Black", "White", "Yellow"},
        targetCuts = {},
        cut = {},
        danger = true,
        lastUnlockTime = 0,
    }
end

local function buildThermoModule(serial)
    local digits = serialDigits(serial)
    local a = digits[2] or 0
    local b = digits[3] or 0
    local coolant = a * 10 + b
    local exhaust
    if coolant <= 20 then
        exhaust = 17
    elseif coolant <= 40 then
        exhaust = 53
    elseif coolant <= 60 then
        exhaust = 30
    elseif coolant <= 80 then
        exhaust = 8
    else
        exhaust = 85
    end

    return {
        id = "thermo",
        solved = false,
        targetCoolant = coolant,
        targetExhaust = exhaust,
        currentCoolant = 50,
        currentExhaust = 50,
        coolantLocked = false,
    }
end

local function buildMinesModule(serial)
    local digits = serialDigits(serial)
    local firstTwo = (digits[1] or 0) + (digits[2] or 0)
    local lastThree = (digits[#digits] or 0) + (digits[#digits - 1] or 0) + (digits[#digits - 2] or 0)

    return {
        id = "mines",
        solved = false,
        targetX = normalizeMineCoord(firstTwo),
        targetY = normalizeMineCoord(lastThree),
        firstTwoSum = firstTwo,
        lastThreeSum = lastThree,
    }
end



function ENT:Initialize()
    self:SetModel("models/releasepackprops/bomb_fix.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysWake()
    self:SetUseType(SIMPLE_USE)

    self.PanelPlayer = nil
    self.ManualPlayer = nil
    self.Modules = {}
    self.ModuleSlots = {}
    self.ManualData = {}
    self.LastSync = 0
    self.RoundEnding = false
    self.MakeName = "ABBERANT"
    self.BombIdentified = false
    self.RadioSeal = {active = false, progress = 0, holding = false, holdUntil = 0}
    self.Seismic = {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}, alertText = ""}
    self.PKB = {active = false, phase = "idle", timer = 0, colors = {}, connections = {}, blocked = {}, completed = {}, completedPaths = {}, draggingColor = nil, dragVisited = {}, lastDragKey = nil}
    self.IdentifiedMake = ""
    self.KTNEDebugOnePlayer = false
    self.DebugOnePlayerActive = false
    self.DebugTestRole = nil
    self.DebugTestSID = nil

    self:SetGameActive(false)
    self:SetTimeRemaining(0)
    self:SetStrikes(0)
    self:SetPanelPlySID("")
    self:SetManualPlySID("")

    self._nextSecondTick = CurTime() + 1
    self:ResetBomb(true)
end

function ENT:ClearRoundFlags()
    self.RoundEnding = false
    self.RoundSuccess = false
    self.RoundResultStamp = 0
end

function ENT:ResetBomb(keepPlayers)
    if not keepPlayers then
        self.PanelPlayer = nil
        self.ManualPlayer = nil
        self:SetPanelPlySID("")
        self:SetManualPlySID("")
    end

    self.Modules = {}
    self.ModuleSlots = {}
    self.ManualData = {}
    self.RadioSeal = {active = false, progress = 0, holding = false, holdUntil = 0}
    self.Seismic = {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}, alertText = ""}
    self.PKB = {active = false, phase = "idle", timer = 0, colors = {}, connections = {}, blocked = {}, completed = {}, completedPaths = {}, draggingColor = nil, dragVisited = {}, lastDragKey = nil}
    self.BombIdentified = false
    self.IdentifiedMake = ""
    self:SetGameActive(false)
    self:SetTimeRemaining(0)
    self:SetStrikes(0)
    self:GenerateModules()
    self._nextSecondTick = CurTime() + 1
    self:ClearRoundFlags()
    self:SyncState(true)
end

function ENT:GenerateModules()
    self.Serial = tostring(math.random(1000, 9999))
    self.MakeName = "ABBERANT"
    self.BombIdentified = false
    self.IdentifiedMake = ""
    self.RadioSeal = {
        active = true,
        progress = 0,
        holding = false,
        holdUntil = 0,
    }
    self.Seismic = {active = false, phase = "idle", timer = 0, pattern = {}, pressed = {}, alertText = ""}
    self.PKB = {active = false, phase = "idle", timer = 0, colors = {}, connections = {}, blocked = {}, completed = {}, completedPaths = {}, draggingColor = nil, dragVisited = {}, lastDragKey = nil}

    local digits = serialDigits(self.Serial)
    local digitSum = sumDigits(self.Serial)
    local lastDigit = digits[#digits] or 0

    local generated = {
        wires = buildWireModule(lastDigit),
        keypad = buildKeypadModule(lastDigit),
        spiral = buildSpiralModule(digits),
        tamper = buildTamperModule(digitSum),
        memory = buildMemoryModule(lastDigit),
        redblue = buildRedBlueModule(digitSum, lastDigit),
        mines = buildMinesModule(self.Serial),
        electric = buildElectricModule(self.Serial),
        twin = buildTwinModule(self.Serial),
        thermo = buildThermoModule(self.Serial),
        override = buildOverrideModule(self.Serial),
        calibration = buildCalibrationModule(self.Serial),
        interrupt = buildInterruptModule(),
        reactor = buildReactorModule(self.Serial),
        drill = buildDrillModule(self.Serial, false),
    }

    local selection = table.Copy(modulePoolOrder)
    table.Shuffle(selection)

    self.Modules = {}
    self.ModuleSlots = {}
    for slot = 1, 4 do
        local id = selection[slot]
        self.ModuleSlots[slot] = id
        self.Modules[id] = generated[id]
    end
    self.ModuleSlots[5] = "twin"
    self.Modules.twin = generated.twin
    self.ModuleSlots[6] = "override"
    self.Modules.override = generated.override

    local hasMemory = self.Modules.memory ~= nil
    local hasWires = self.Modules.wires ~= nil
    local isTwoPlayer = true
    local redblue = generated.redblue
    local switchCount = 0
    if isTwoPlayer then switchCount = switchCount + 1 end
    if hasMemory then switchCount = switchCount + 1 end
    if hasWires and ((generated.wires.redCount or 0) == 2) then switchCount = switchCount + 1 end
    if lastDigit == 0 then switchCount = switchCount + 1 end
    local baseColor = digitSum > 25 and "Blue" or "Red"
    if switchCount % 2 == 1 then
        redblue.correct = (baseColor == "Blue") and "Red" or "Blue"
    else
        redblue.correct = baseColor
    end
    redblue.switches = {
        twoPlayer = isTwoPlayer,
        memoryPresent = hasMemory,
        twoRedWires = hasWires and ((generated.wires.redCount or 0) == 2) or false,
        serialEndsZero = (lastDigit == 0),
        switchCount = switchCount,
    }

    local memoryStartKey = generated.memory.startKey
    self.ManualData = {
        serial = self.Serial,
        make = self.MakeName,
        bombIdentified = self.BombIdentified == true,
        identifiedMake = self.IdentifiedMake or "",
        overview = {
            title = "Field Manual Overview",
            lines = {
                "Bomb Make: ABBERANT",
                "Serial Number: " .. self.Serial,
                "Slots 1 through 4 were selected from the random module pool.",
                "Slot 5 contains Twin Payload Disconnection. Slot 6 contains Emergency Nuclear Override.",
                "The datapad terminal runs the Abberant heat venting module.",
                "Solve all six active modules before the timer reaches zero.",
                "Every incorrect action adds a strike. Three strikes detonates the bomb.",
            }
        },

        reactor = {
            title = "PKB: Reactor Dismantle",
            lines = {
                "This module is a staged reactor access and purge drill.",
                "First, enter the 4-letter reactor access code on the face plate.",
                "Generate the code from the serial number using A1Z26 on each digit separately.",
                "Digits 1 through 9 map to A through I. A serial digit of 0 maps to Z for this bomb.",
                "For this bomb, serial " .. self.Serial .. " converts to reactor code " .. generated.reactor.code .. ".",
                "A wrong code entry causes 1 strike.",
                "Once opened, a 3 by 3 reactor grid is exposed.",
                "X faults begin appearing every half second. Click each X to clear it.",
                "Clear a total of 20 X faults to dismantle the reactor and solve the module.",
                "If all 9 boxes are filled with X faults at once, the bomb detonates immediately.",
                "If 6 or more X faults are present at once, the module enters a red danger state.",
            }
        },
        drill = {
            title = "PKB: Disable the Tectonic Drill",
            lines = {
                "Bomb Type: PKB",
                "Enter the 6-digit override to unlock the drill wire panel.",
                "Digits 1 to 4 are the reactor code converted with A0Z25 and reduced to the last digit.",
                "Digits 5 and 6 use serial positions 1 and 3 if Anti-Tamper is present; otherwise positions 2 and 4.",
                "Once unlocked, cut exactly three wires based on the timer at the moment the code is accepted.",
                "0:01 to 1:00 = Red, Blue, Black",
                "1:01 to 2:00 = Green, Yellow, Red",
                "2:01 to 3:00 = Black, Red, Yellow",
                "3:01 to 4:00 = White, Green, Blue",
                "4:01 or higher = Blue, White, Yellow",
                "Any incorrect cut instantly detonates the bomb.",
            }
        },
        interrupt = {
            title = "Interrupt Vibration Pattern",
            lines = {
                "Bomb Type: Seismic",
                "Press START at the bottom of the module to begin the sequence.",
                "There are 4 rounds and each round requires the EXACT number of clicks before time expires.",
                "Round 1: 15 clicks in 4 seconds.",
                "Round 2: 7 clicks in 3 seconds.",
                "Round 3: 24 clicks in 7 seconds.",
                "Round 4: 18 clicks in 6 seconds.",
                "If you click too few before time runs out, or if you click too many at any time, the module gives one strike and resets.",
                "After each successful round, the next round starts immediately.",
                "Complete all 4 rounds to solve the module.",
            }
        },
        thermo = {
            title = "Thermo Regulation Module",
            lines = {
                "Bomb Type: Incendiary",
                "This module MUST be completed first. Any attempt to solve another live module before Thermo Regulation causes a strike.",
                "Adjust COOLANT FLOW first. Exhaust adjustments before the coolant is set correctly cause a strike.",
                "Use the serial number's middle two digits as the exact coolant percentage.",
                "For this bomb, the coolant target is " .. generated.thermo.targetCoolant .. "%.",
                "Then use the coolant range to determine the heat exhaust target:",
                "0% to 20% -> 17%",
                "21% to 40% -> 53%",
                "41% to 60% -> 30%",
                "61% to 80% -> 8%",
                "81% to 99% -> 85%",
                "For this bomb, the heat exhaust target is " .. generated.thermo.targetExhaust .. "%.",
            }
        },
        wires = {
            title = "Wire Module",
            lines = {
                "Use the serial header at the top of the bomb. Do NOT look for the serial in the wire section.",
                "Apply the first matching rule only:",
                "1) If the serial number ends in an odd digit, cut the LAST wire.",
                "2) Otherwise, if there are two or more RED wires, cut the FIRST wire.",
                "3) Otherwise, cut the MIDDLE wire.",
                "Cut exactly one wire. A wrong wire adds one strike.",
            }
        },
        keypad = {
            title = "Keypad Module",
            lines = {
                "Use the serial number's LAST digit to choose a precedence row.",
                "Row 1 if the last digit divided by 3 has a remainder of 0",
                "Row 2 if the last digit divided by 3 has a remainder of 1",
                "Row 3 if the last digit divided by 3 has a remainder of 2",
                "Press ONLY the four shown symbols in the order they appear in the chosen row.",
                "Row 1: " .. table.concat(keypadRows[1], " -> "),
                "Row 2: " .. table.concat(keypadRows[2], " -> "),
                "Row 3: " .. table.concat(keypadRows[3], " -> "),
            }
        },
        spiral = {
            title = "Remote Trigger Buffer Signal (Spiral Lock)",
            lines = {
                "Set all eight dials to the correct combo using only the up/down arrows.",
                "Build the combo from the serial number digits:",
                "Dial n = repeating serial digit plus n, divided by 10, keeping only the remainder.",
                "Example pattern positions use serial digits 1-4, then repeat for 5-8.",
                "For this bomb, the serial is " .. self.Serial .. ".",
                "Resulting combo: " .. table.concat(generated.spiral.combo, " "),
            }
        },
        tamper = {
            title = "Anti-Tampering Device",
            lines = {
                "Drag each source wire on the left into the correct receiver on the right.",
                "Use the serial DIGIT SUM to calculate the shift.",
                "Shift = take the sum of the serial digits, divide it by 4, then add 1 to the remainder.",
                "Left-side wire colors are always: " .. table.concat(tamperLeftColors, " -> "),
                "Right-side receiver colors are always: " .. table.concat(tamperRightColors, " -> "),
                "Match each left wire to a right receiver by shifting through the receiver list.",
                "Receiver step order: " .. table.concat(tamperRightColors, " -> "),
                "For this bomb, serial digit sum = " .. digitSum .. ", so the shift value is " .. generated.tamper.serialShift .. ".",
                "Start from receiver 1 = " .. tamperRightColors[1] .. ". Count forward by the shift value for each left wire index.",
                "Wire 1 uses the first receiver color after shifting, wire 2 uses the next shifted receiver, and so on.",
            }
        },
        memory = {
            title = "Memory (Network Stabilization)",
            lines = {
                "This module uses a 1 through 9 keypad and four memory rounds.",
                "Use the serial number's LAST digit to determine the starting key.",
                "If the serial ends in 0, treat the starting key as 9.",
                "For this bomb, the correct starting key is " .. memoryStartKey .. ".",
                "Press the starting key once to begin the sequence.",
                "Each round shows one additional grey pad lighting white.",
                "Repeat the shown pads in the same order after the preview ends.",
                "If you press a wrong key, the module resets, adds one strike, and must be restarted from the starting key.",
                "There are 4 rounds total. Complete all 4 rounds to solve the module.",
            }
        },
        redblue = {
            title = "Red & Blue Button",
            lines = {
                "This module MUST be completed last. Pressing it before all other live modules are solved always causes a strike.",
                "Start with the serial digit sum.",
                "If the sum is greater than 25, press the BLUE button.",
                "If the sum is 25 or less, press the RED button.",
                "Then switch the correct color once for each true exception.",
                "Exception 1: if the bomb is in two-player mode, switch it.",
                "Exception 2: if the Memory module is present, switch it.",
                "Exception 3: if the Wire module is present AND there are exactly two red wires, switch it.",
                "Exception 4: if the serial number ends in 0, switch it.",
                "For this bomb, serial digit sum = " .. digitSum .. ". Final correct button: " .. redblue.correct .. ".",
            }
        },
        mines = {
            title = "Minesweeper (Payload Location Identification)",
            lines = {
                "There is one hidden payload inside the 5 x 5 tile grid. Click the correct tile to solve the module.",
                "Horizontal position: add the FIRST TWO serial digits. Use the last digit of that sum.",
                "If that value is greater than 5, subtract 5. If it is 0, treat it as 1.",
                "Vertical position: add the LAST THREE serial digits. Use the last digit of that sum.",
                "Apply the same conversion rules: greater than 5 means subtract 5, and 0 becomes 1.",
                "For this bomb, the first-two sum is " .. generated.mines.firstTwoSum .. ", giving horizontal tile " .. generated.mines.targetX .. ".",
                "The last-three sum is " .. generated.mines.lastThreeSum .. ", giving vertical tile " .. generated.mines.targetY .. ".",
                "Coordinates are counted from the LEFT for horizontal and from the TOP for vertical.",
                "Clicking any other tile causes one strike.",
            }
        },
        electric = {
            title = "Electric Flow Control",
            lines = {
                "Bomb Type: EMP Charge",
                "Connect the center yellow wire to exactly one side wire.",
                "Convert the serial number into a whole number from 0000 to 9999.",
                "If the serial is between 0000 and 2999, connect Yellow to RED.",
                "If the serial is between 3000 and 5999, connect Yellow to BLUE.",
                "If the serial is between 6000 and 9999, connect Yellow to GREEN.",
                "For this bomb, the serial value is " .. (generated.electric.numericSerial or 0) .. ".",
                "That means the correct wire is " .. (generated.electric.targetColor or "UNKNOWN") .. ".",
                "Clicking the wrong wire causes one strike.",
            }
        },
        override = {
            title = "Emergency Nuclear Override",
            lines = {
                "Bomb Type: Aberrant",
                "Set the three override switches to match the manual code, then press CHECK OVERRIDE.",
                "Generated code: " .. table.concat(generated.override.baseBits, " "),
                "If a generated number is 0, the corresponding switch must be OFF. If it is 1, the switch must be ON.",
                "Apply all matching exceptions in order. They stack.",
                "If the serial number contains at least one 5, flip ALL correct switch modes.",
                "If the serial number ends with an even digit, flip the FIRST switch's correct status.",
                "If the serial number starts or ends with 0, flip the THIRD switch's correct status.",
                "If the two middle digits add up to more than 5, flip the SECOND and THIRD switch statuses.",
                "Active exceptions for this bomb: " .. ((generated.override.flags.hasFive and "[contains 5] " or "") .. (generated.override.flags.evenEnd and "[even end] " or "") .. (generated.override.flags.zeroFrontOrRear and "[0 at front/rear] " or "") .. (generated.override.flags.middleOverFive and "[middle sum > 5]" or "none")),
                "Pressing CHECK with the wrong combination causes one strike.",
            }
        },
        calibration = {
            title = "Seismic Calibration",
            lines = {
                "Bomb Type: Seismic",
                "Begin by pressing the correct lower calibration button.",
                "For this bomb, the correct start button is BUTTON " .. tostring(generated.calibration.startButton) .. ".",
                "After a 2 second grace period, watch the three top lights cycle in half-second intervals with half-second dark pauses between them.",
                "For this bomb, press the center button only when the " .. tostring(generated.calibration.targetColor):upper() .. " light is lit.",
                "Pressing during the wrong light or while no light is lit causes one strike and resets calibration progress.",
                "You must hit the center button 7 times on the correct light to solve the module.",
            }
        },
        twin = {
            title = "Twin Payload Disconnection",
            lines = {
                "Bomb Type: Aberrant",
                "WARNING: Confirm every action with the manual. One wrong cut immediately detonates the bomb.",
                "Base cut order: Grey -> Yellow -> Red -> Green -> Blue -> Black",
                "Apply ALL matching shifts in this exact order:",
                "1) If the serial number ends with two odd digits in a row, switch Yellow and Grey.",
                "2) If the serial number contains at least one 0, switch Black and Blue.",
                "3) If the serial number starts with 5 or 3, switch Red and Green.",
                "Cut all six wires in the resulting order. The boxes do not change the sequence.",
            }
        },
        reactor = {
            title = "PKB: Reactor Dismantle",
            lines = {
                "This module is a staged reactor access and purge drill.",
                "First, enter the 4-letter reactor access code on the face plate.",
                "Generate the code from the serial number using A1Z26 on each digit separately.",
                "Digits 1 through 9 map to A through I. A serial digit of 0 maps to Z for this bomb.",
                "For this bomb, serial " .. self.Serial .. " converts to reactor code " .. generated.reactor.code .. ".",
                "A wrong code entry causes 1 strike.",
                "Once opened, a 3 by 3 reactor grid is exposed.",
                "X faults begin appearing every half second. Click each X to clear it.",
                "Clear a total of 20 X faults to dismantle the reactor and solve the module.",
                "If all 9 boxes are filled with X faults at once, the bomb detonates immediately.",
                "If 6 or more X faults are present at once, the module enters a red danger state.",
            }
        },
        interrupt = {
            title = "Interrupt Vibration Pattern",
            lines = {
                "Bomb Type: Seismic",
                "Press START at the bottom of the module to begin the sequence.",
                "There are 4 rounds and each round requires the EXACT number of clicks before time expires.",
                "Round 1: 15 clicks in 4 seconds.",
                "Round 2: 7 clicks in 3 seconds.",
                "Round 3: 24 clicks in 7 seconds.",
                "Round 4: 18 clicks in 6 seconds.",
                "If you click too few before time runs out, or if you click too many at any time, the module gives one strike and resets.",
                "After each successful round, the next round starts immediately.",
                "Complete all 4 rounds to solve the module.",
            }
        },
        thermo = {
            title = "Thermo Regulation Module",
            lines = {
                "Bomb Type: Incendiary",
                "This module MUST be completed first. Any attempt to solve another live module before Thermo Regulation causes a strike.",
                "Adjust COOLANT FLOW first. Exhaust adjustments before the coolant is set correctly cause a strike.",
                "Use the serial number's middle two digits as the exact coolant percentage.",
                "For this bomb, the coolant target is " .. generated.thermo.targetCoolant .. "%.",
                "Then use the coolant range to determine the heat exhaust target:",
                "0% to 20% -> 17%",
                "21% to 40% -> 53%",
                "41% to 60% -> 30%",
                "61% to 80% -> 8%",
                "81% to 99% -> 85%",
                "For this bomb, the heat exhaust target is " .. generated.thermo.targetExhaust .. "%.",
            }
        },
    }
end


local function sid64(ply)
    return IsValid(ply) and (ply:SteamID64() or "") or ""
end

local MAX_ACTION_MSG_BITS = 8192
local DEFAULT_ACTION_COOLDOWN = 0.05
local PLAYER_SLOT_IDLE_TIMEOUT = 120
local ACTION_COOLDOWNS = {
    debug_start_role = 0.25,
    leave_bomb = 0.25,
    chat_message = 0.35,
    identify_bomb = 0.2,
    radio_hold = 0.05,
    seismic_press = 0.08,
    thermo_set = 0.05,
    tamper_connect = 0.08,
    memory_press = 0.08,
    pkb_begin = 0.15,
    pkb_hover = 0.02,
    pkb_release = 0.05,
    reactor_code = 0.25,
    reactor_clear = 0.05,
    drill_code = 0.25,
    drill_cut = 0.08,
    override_toggle = 0.08,
    override_check = 0.15,
    calibration_start = 0.15,
    calibration_press = 0.08,
    interrupt_start = 0.15,
    interrupt_click = 0.05,
    twin_cut = 0.08,
}

local function clampInt(value, minValue, maxValue, defaultValue)
    local num = math.floor(tonumber(value or defaultValue) or defaultValue or 0)
    return math.Clamp(num, minValue, maxValue)
end

function ENT:IsPanelUser(ply)
    if not IsValid(ply) then return false end
    return ply == self.PanelPlayer
end

function ENT:IsManualUser(ply)
    if not IsValid(ply) then return false end
    return ply == self.ManualPlayer
end

function ENT:GetPlayerRole(ply)
    if not IsValid(ply) then return "spectator" end
    if self.DebugOnePlayerActive and sid64(ply) == tostring(self.DebugTestSID or "") then
        return self.DebugTestRole == "manual" and "manual" or "panel"
    end
    return self:IsPanelUser(ply) and "panel" or (self:IsManualUser(ply) and "manual" or "spectator")
end

function ENT:GetJoinedCount()
    local n = 0
    if IsValid(self.PanelPlayer) then n = n + 1 end
    if IsValid(self.ManualPlayer) then n = n + 1 end
    return n
end

function ENT:TouchPlayerActivity(ply)
    local sid = sid64(ply)
    if sid == "" then return end
    self._playerActivity = self._playerActivity or {}
    self._playerActivity[sid] = CurTime()
end

function ENT:ClearPlayerActivityBySID(sid)
    sid = tostring(sid or "")
    if sid == "" then return end
    self._playerActivity = self._playerActivity or {}
    self._playerActivity[sid] = nil
end

function ENT:EvictInactivePlayers()
    local activity = self._playerActivity or {}
    local now = CurTime()
    local stalePlayers = {}

    for _, ply in ipairs({self.PanelPlayer, self.ManualPlayer}) do
        local sid = sid64(ply)
        local last = activity[sid] or 0
        if sid ~= "" and last > 0 and (now - last) >= PLAYER_SLOT_IDLE_TIMEOUT then
            stalePlayers[sid] = ply
        end
    end

    local changed = false
    for sid, ply in pairs(stalePlayers) do
        changed = self:ReleasePlayerBySID(sid) or changed
        if IsValid(ply) then
            net.Start("ktne_close_ui_mp")
                net.WriteEntity(self)
            net.Send(ply)
        end
    end

    if changed then
        self:SyncState(true)
    end
end

function ENT:AssignPlayer(ply)
    if not IsValid(self.PanelPlayer) then
        self.PanelPlayer = ply
        self:SetPanelPlySID(ply:SteamID64() or "")
        self:TouchPlayerActivity(ply)
        return "panel"
    elseif not IsValid(self.ManualPlayer) and ply ~= self.PanelPlayer then
        self.ManualPlayer = ply
        self:SetManualPlySID(ply:SteamID64() or "")
        self:TouchPlayerActivity(ply)
        return "manual"
    elseif self:IsPanelUser(ply) then
        self:TouchPlayerActivity(ply)
        return "panel"
    elseif self:IsManualUser(ply) then
        self:TouchPlayerActivity(ply)
        return "manual"
    end
end


function ENT:UnassignInvalidPlayers()
    if not IsValid(self.PanelPlayer) then
        self.PanelPlayer = nil
        self:SetPanelPlySID("")
    end
    if not IsValid(self.ManualPlayer) then
        self.ManualPlayer = nil
        self:SetManualPlySID("")
    end
end

function ENT:ReleasePlayerBySID(sid)
    sid = tostring(sid or "")
    if sid == "" then return false end

    local changed = false
    if tostring(self:GetPanelPlySID() or "") == sid then
        self.PanelPlayer = nil
        self:SetPanelPlySID("")
        changed = true
    end
    if tostring(self:GetManualPlySID() or "") == sid then
        self.ManualPlayer = nil
        self:SetManualPlySID("")
        changed = true
    end

    if tostring(self.DebugTestSID or "") == sid then
        self.DebugOnePlayerActive = false
        self.DebugTestRole = nil
        self.DebugTestSID = nil
        changed = true
    end

    if changed then
        self:ClearPlayerActivityBySID(sid)
    end

    return changed
end

function ENT:ReleasePlayer(ply, opts)
    local changed = self:ReleasePlayerBySID(sid64(ply))
    if not changed then return false end

    if IsValid(ply) and not (opts and opts.skipClose) then
        net.Start("ktne_close_ui_mp")
            net.WriteEntity(self)
        net.Send(ply)
    end

    self:SyncState(true)
    return true
end

function ENT:IsActionRateLimited(ply, action)
    if not IsValid(ply) then return true end

    self._actionThrottle = self._actionThrottle or {}
    local key = sid64(ply) .. ":" .. tostring(action or "")
    local now = CurTime()
    local nextAllowed = self._actionThrottle[key] or 0
    if nextAllowed > now then
        return true
    end

    self._actionThrottle[key] = now + (ACTION_COOLDOWNS[action] or DEFAULT_ACTION_COOLDOWN)
    return false
end

function ENT:SanitizeActionData(action, data)
    if not istable(data) then return {} end

    local safe = {}
    if data.index ~= nil then safe.index = clampInt(data.index, 0, 64, 0) end
    if data.x ~= nil then safe.x = clampInt(data.x, 0, 64, 0) end
    if data.y ~= nil then safe.y = clampInt(data.y, 0, 64, 0) end
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
    self:TouchPlayerActivity(ply)

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
    self:EvictInactivePlayers()
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
    self:TouchPlayerActivity(ply)
    local role = self:GetPlayerRole(ply)
    if math.random(1, 100) == 1 then
        self:PushChatEntry("dev", "SYSTEM", [[Addon made by Tusk

Thank you to the Playtesters who helped with playtesting during devolpment!
-Jameson
-Nice
-DinoNuggs
-Esk

Addon Funded by the Chipkittle Family
Thank you for playing! :)]])
    end
    net.Start("ktne_open_ui_mp")
        net.WriteEntity(self)
        net.WriteString(role)
        net.WriteTable(self:GetClientStateFor(role, true))
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

function ENT:GetClientStateFor(role, includeStatic, syncFlags)
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
        state.chatLog = deepCopy(self.ChatLog or {})
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

function ENT:StartGame()
    self.ChatLog = {}
    self.ChatSeq = 0
    self._loggedSolved = {}
    self:GenerateModules()
    self:SetGameActive(true)
    self:SetTimeRemaining(240)
    self:SetStrikes(0)
    self:ClearRoundFlags()
    self._nextSecondTick = CurTime() + 1
    self._nextIdleSync = CurTime() + 1
    self:NotifyPlayers("Abberant bomb started. Defuse all six visible modules within 4:00.")
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
    end

    if not self:GetGameActive() then return end
    if action == "chat_message" then
        if not (self:IsPanelUser(ply) or self:IsManualUser(ply)) then return end
        self:TouchPlayerActivity(ply)
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

    self:TouchPlayerActivity(ply)

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
            net.WriteTable(self:GetClientStateFor(role, includeStatic, syncFlags))
        net.Send(ply)
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
    ent:Spawn()
    ent:Activate()
    return ent
end










