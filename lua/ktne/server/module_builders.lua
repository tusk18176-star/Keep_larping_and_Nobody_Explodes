-- Shared KTNE module builders extracted from entity init.lua copies.
-- Returned as a table so entity init.lua files can bind only what they need.

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

local PKB_LAYOUT_MAX_ATTEMPTS = 16
local PKB_LAYOUT_MAX_INNER_ATTEMPTS = 256

local function buildPKBFallbackBlocked()
    local blocked = {}
    blocked[pkbKey(4, 2)] = true
    blocked[pkbKey(4, 4)] = true
    blocked[pkbKey(8, 2)] = true
    blocked[pkbKey(8, 4)] = true
    return blocked
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

    local blocked = nil
    local blockedCount = math.random(4, 6)
    local attempts = 0
    while attempts < PKB_LAYOUT_MAX_ATTEMPTS do
        attempts = attempts + 1
        local candidate = {}
        local innerAttempts = 0
        while table.Count(candidate) < blockedCount and innerAttempts < PKB_LAYOUT_MAX_INNER_ATTEMPTS do
            innerAttempts = innerAttempts + 1
            local x = math.random(2, PKB_GRID_W - 1)
            local y = math.random(1, PKB_GRID_H)
            candidate[pkbKey(x, y)] = true
        end

        local valid = table.Count(candidate) >= blockedCount
        if valid then
            for _, color in ipairs(colors) do
                local conn = connections[color]
                if not pkbHasRoute(candidate, conn.output, conn.receiver) then
                    valid = false
                    break
                end
            end
        end

        if valid then
            blocked = candidate
            break
        end
    end

    if not blocked then
        blocked = buildPKBFallbackBlocked()
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

return {
    deepCopy = deepCopy,
    wireColors = wireColors,
    symbolPool = symbolPool,
    keypadRows = keypadRows,
    tamperLeftColors = tamperLeftColors,
    tamperRightColors = tamperRightColors,
    modulePoolOrder = modulePoolOrder,
    moduleDisplayNames = moduleDisplayNames,
    formatChatTimeRemaining = formatChatTimeRemaining,
    buildSeismicState = buildSeismicState,
    buildPKBState = buildPKBState,
    resetPKBOutageState = resetPKBOutageState,
    regenPKBLayout = regenPKBLayout,
    sumDigits = sumDigits,
    serialDigits = serialDigits,
    buildWireModule = buildWireModule,
    buildKeypadModule = buildKeypadModule,
    buildSpiralModule = buildSpiralModule,
    buildTamperModule = buildTamperModule,
    buildMemoryModule = buildMemoryModule,
    buildRedBlueModule = buildRedBlueModule,
    normalizeMineCoord = normalizeMineCoord,
    buildElectricModule = buildElectricModule,
    buildTwinModule = buildTwinModule,
    buildOverrideModule = buildOverrideModule,
    buildCalibrationModule = buildCalibrationModule,
    buildInterruptModule = buildInterruptModule,
    serialToReactorCode = serialToReactorCode,
    buildReactorModule = buildReactorModule,
    reactorCodeToDrillDigits = reactorCodeToDrillDigits,
    drillTargetsForTime = drillTargetsForTime,
    buildDrillModule = buildDrillModule,
    buildThermoModule = buildThermoModule,
    buildMinesModule = buildMinesModule,
}
