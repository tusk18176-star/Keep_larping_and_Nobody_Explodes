KTNE_ClientUiState = KTNE_ClientUiState or {contexts = {}}

local ktneEscWasDown = false

local function ktneIterContexts()
    return pairs((KTNE_ClientUiState and KTNE_ClientUiState.contexts) or {})
end

local function ktneGetPrimaryActiveContext()
    for id, ctx in ktneIterContexts() do
        if istable(ctx) and isfunction(ctx.getPrimaryActiveFrame) then
            local fr, ent = ctx.getPrimaryActiveFrame()
            if IsValid(ent) and IsValid(fr) and not fr._closing and (not fr.IsVisible or fr:IsVisible()) then
                return ctx, fr, ent, id
            end
        end
    end
    return nil, nil, nil, nil
end

local function ktneHasLiveBombUi()
    local ctx, fr, ent = ktneGetPrimaryActiveContext()
    if not istable(ctx) or not IsValid(fr) or not IsValid(ent) then
        return false, nil, nil, nil
    end
    if fr._closing then
        return false, nil, nil, nil
    end
    if fr.IsVisible and not fr:IsVisible() then
        return false, nil, nil, nil
    end
    return true, ctx, fr, ent
end

local function ktneHasFocusedTypingEntry()
    for _, ctx in ktneIterContexts() do
        if istable(ctx) and isfunction(ctx.hasFocusedTypingEntry) and ctx.hasFocusedTypingEntry() then
            return true
        end
    end
    return false
end

local function ktneIsPushToTalkBind(bind)
    for _, ctx in ktneIterContexts() do
        if istable(ctx) and isfunction(ctx.isPushToTalkBind) and ctx.isPushToTalkBind(bind) then
            return true
        end
    end
    return false
end

local function ktneRefreshKeyboardOwners()
    local anyActive = false
    for _, ctx in ktneIterContexts() do
        if istable(ctx) and isfunction(ctx.getPrimaryActiveFrame) then
            local fr, ent = ctx.getPrimaryActiveFrame()
            if IsValid(ent) and IsValid(fr) and not fr._closing and (not fr.IsVisible or fr:IsVisible()) then
                anyActive = true
                if isfunction(ctx.refreshKeyboardOwner) then
                    ctx.refreshKeyboardOwner(fr)
                end
            end
        end
    end
    return anyActive
end

local function ktneCloseActiveUi()
    local ctx = select(1, ktneGetPrimaryActiveContext())
    if not istable(ctx) or not isfunction(ctx.closeActiveUi) then
        return false
    end
    return ctx.closeActiveUi() == true
end

local function ktneCloseActiveUiForLifecycle()
    local live = ktneHasLiveBombUi()
    if not live then
        return false
    end
    gui.HideGameUI()
    return ktneCloseActiveUi()
end

hook.Add("PlayerBindPress", "KTNE_ClientUiInput_Bind", function(_, bind)
    local live = ktneHasLiveBombUi()
    if not live then
        return
    end

    if ktneHasFocusedTypingEntry() then
        return
    end

    local lower = string.lower(tostring(bind or ""))
    if ktneIsPushToTalkBind(lower) then
        return
    end

    return true
end)

hook.Add("Think", "KTNE_ClientUiInput_EscClose", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        ktneEscWasDown = false
        return
    end

    if not ply:Alive() then
        ktneEscWasDown = false
        ktneCloseActiveUiForLifecycle()
        return
    end

    local live, ctx, fr, ent = ktneHasLiveBombUi()
    if not live then
        ktneEscWasDown = false
        return
    end

    ktneRefreshKeyboardOwners()

    local escDown = input.IsKeyDown(KEY_ESCAPE)
    if escDown and not ktneEscWasDown then
        gui.HideGameUI()
        ktneCloseActiveUi()
    end
    ktneEscWasDown = escDown == true
end)

hook.Add("PlayerSpawn", "KTNE_ClientUiInput_SpawnClose", function(ply)
    local localPly = LocalPlayer()
    if not IsValid(localPly) or ply ~= localPly then
        return
    end
    timer.Simple(0, function()
        ktneCloseActiveUiForLifecycle()
    end)
end)
