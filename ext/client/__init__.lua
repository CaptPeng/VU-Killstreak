local bindings = require("keybindings.lua")
local conf = nil
local step = -1
local inUse = {false, false, false, false}
-- blocks the use of time based killstreaks and prevent that is constantily shown in the ui
local running = {false, false, false, false}
local keyUpThreshold = 30
local curKeyUpEvents = 0
local selectedKillstreaks = nil
local score = 0
local disabledAction = false
local uiHidden = false

NetEvents:Subscribe(
    "Killstreak:ScoreUpdate",
    function(data)
        data = tonumber(data)
        score = data
        print("Got Data " .. tostring(data))
        calcStep(data)
        WebUI:ExecuteJS('document.dispatchEvent(new CustomEvent("Killstreak:UpdateScore",{detail:"' .. data .. '"}))')    
    end
)

Events:Subscribe(
    "Extension:Loaded",
    function()
        NetEvents:Subscribe("Killstreak:Client:getConf", getConf)
        NetEvents:SendLocal("Killstreak:newClient", player)
    end
)
Events:Subscribe(
    "Player:Connected",
    function(player)
        if player.id == PlayerManager:GetLocalPlayer().id then
            NetEvents:SendLocal("Killstreak:newClient", player)
        end
    end
)
Events:Subscribe(
    "Level:Loaded",
    function(levelName, gameMode)
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:showKsButton"))')
    end
)

Events:Subscribe(
    "Killstreak:disableIngameUI",
    function(levelName, gameMode)
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:showKsButton"))')
    end
)

Events:Subscribe(
    "Killstreak:enableIngameUI",
    function(levelName, gameMode)
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:showKsButton"))')
    end
)

NetEvents:Subscribe(
    "Killstreak:hideAll",
    function()
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideKsButton"))')
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideSelectScreen"))')
    end
)

NetEvents:Subscribe(
    "Killstreak:hideButton",
    function()
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideKsButton"))')
    end
)

NetEvents:Subscribe(
    "Killstreak:showButton",
    function()
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:showKsButton"))')
    end
)

-- Invoke this to show a message on the screen.
-- messageObj: {title: string, message: string} as JSON string
Events:Subscribe(
    "Killstreak:showNotification",
    function(messageObjJson)
        messageObjJson = json.encode(messageObjJson)
        WebUI:ExecuteJS(
            'document.dispatchEvent(new CustomEvent("Killstreak:UI:showNotification",{detail:' ..
                messageObjJson .. "}))"
        )
    end
)

NetEvents:Subscribe(
    "Killstreak:showNotification",
    function(messageObjJson)
        messageObjJson = json.encode(messageObjJson)
        print("new message")
        print(messageObjJson)
        WebUI:ExecuteJS(
            'document.dispatchEvent(new CustomEvent("Killstreak:UI:showNotification",{detail:' ..
                messageObjJson .. "}))"
        )
    end
)

Events:Subscribe(
    "Level:Finalized",
    function(levelName, gameMode)
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideKsButton"))')
        WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideSelectScreen"))')
    end
)

function disableInteractions()
    disabledAction = true
    WebUI:ExecuteJS(
        'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' .. tostring(-10) .. "}))"
    )
    for i, v in pairs(inUse) do
        if inUse[i] == true then
            inUse[i] = false
            running[i] = false
            Events:Dispatch(selectedKillstreaks[i][1] .. ":Disable", i)
        end
    end
end

Hooks:Install(
    "UI:PushScreen",
    1,
    function(hook, screen, priority, parentGraph, stateNodeGuid)
        local screen = UIGraphAsset(screen)
        --print(screen.name)
        -- UI/Flow/Screen/EORWinningTeamScreen
        -- UI/Flow/Screen/EORLoosingTeamScreen
        if screen.name == "UI/Flow/Screen/EORWinningTeamScreen" then
            print("hide web ui --------------------")
            WebUI:Hide()
            WebUI:ExecuteJS(
                'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' .. tostring(-10) .. "}))"
            )
            WebUI:ExecuteJS('document.dispatchEvent(new CustomEvent("Killstreak:UpdateScore",{detail:"' .. tostring(0) .. '"}))')
            uiHidden = true
        end

        if screen.name == "UI/Flow/Screen/SpawnScreenPC" then
            WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:showKsButton"))')
            if uiHidden == true then
                print("show ui ---")
                WebUI:Show()
                uiHidden = false
            end
        end

        if screen.name == "UI/Flow/Screen/KillScreen" then
            print("disable interactions screen")
            disableInteractions()
        end
    end
)

NetEvents:Subscribe(
    "Killstreak:DisableInteraction",
    function()
        print("Disable interactions")
        disableInteractions()
    end
)
Events:Subscribe(
    "Soldier:HealthAction",
    function(soldier, action)
        if action == HealthStateAction.OnManDown then
            if soldier.player ~= nil then
                if player.id == PlayerManager:GetLocalPlayer().id then
                    disableInteractions()
                end
            else
                print("Player of soldier is nil")
            end
        end
    end
)

NetEvents:Subscribe(
    "Killstreak:EnableInteraction",
    function()
        disabledAction = false
    end
)

Events:Subscribe(
    "Player:Respawn",
    function(player)
        if player.id == PlayerManager:GetLocalPlayer().id then
            WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideKsButton"))')
            WebUI:ExecuteJS('document.dispatchEvent(new Event("Killstreak:UI:hideSelectScreen"))')
            disabledAction = false
        end
    end
)

Events:Subscribe(
    "Killstreak:selectedKillstreaks",
    function(ks)
        test = json.encode(ks)
        -- print("ks test " .. test)
        NetEvents:SendLocal("Killstreak:updatePlayerKS", json.decode(ks))
        decodeKs = json.decode(ks)
        selectedKillstreaks = decodeKs
        calcStep(score)
        WebUI:ExecuteJS('document.dispatchEvent(new CustomEvent("Killstreak:UpdateScore",{detail:"' .. score .. '"}))')
    end
)
-- timerObjJson: JSON string from the timer object for the frontend {duration: number,text: string}
Events:Subscribe(
    "Killstreak:newTimer",
    function(timerObjJson)
        print(timerObjJson)
        timerObjJson = json.encode(timerObjJson)
        WebUI:ExecuteJS(
            'document.dispatchEvent(new CustomEvent("Killstreak:UI:newTimer",{detail:' .. timerObjJson .. "}))"
        )
    end
)

-- timerObjJson: JSON string from the timer object for the frontend {duration: number,text: string}
NetEvents:Subscribe(
    "Killstreak:newTimer",
    function(timerObjJson)
        print(timerObjJson)
        timerObjJson = json.encode(timerObjJson)
        WebUI:ExecuteJS(
            'document.dispatchEvent(new CustomEvent("Killstreak:UI:newTimer",{detail:' .. timerObjJson .. "}))"
        )
    end
)

-- Your mod get the following parameters in the Invoke Event:
-- 1. Position of Killstreak 1-4
Events:Subscribe(
    "Client:UpdateInput",
    function(delta)
        if selectedKillstreaks == nil then
            return
        end
        if disabledAction then
            return
        end

        for i, v in pairs(selectedKillstreaks) do
            if InputManager:WentKeyUp(tonumber(bindings[i])) and inUse[i] == false then
                print("key detected")
                print(tostring(i) .. " step " .. tostring(step))
                print(json.encode(inUse))
                print(json.encode(running))
                if i <= step then
                    -- quit if the current KS is still running
                    if running[i] == true then
                        break
                    end
                    -- Check if another KS is currently in use
                    used = nil
                    for i, v in pairs(inUse) do
                        if inUse[i] == true then
                            used = i
                        end
                    end
                    if used ~= nil then
                        WebUI:ExecuteJS(
                            'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' ..
                                tostring(-10) .. "}))"
                        )
                        -- Disable the aktive KS
                        print("Disable because of a switch")
                        Events:Dispatch(selectedKillstreaks[used][1] .. ":Disable", i)
                        inUse[used] = false
                        running[used] = false
                    end
                    print("Activate")
                    print("Dispatched event " .. tostring(selectedKillstreaks[i][1]))
                    WebUI:ExecuteJS(
                        'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' ..
                            tostring(i) .. "}))"
                    )
                    inUse[i] = true
                    running[i] = true
                    Events:Dispatch(selectedKillstreaks[i][1] .. ":Invoke", i)
                    return
                end
            end
            if InputManager:WentKeyUp(tonumber(bindings[i])) and inUse[i] == true then
                print("Disable")
                Events:Dispatch(selectedKillstreaks[i][1] .. ":Disable", i)
                WebUI:ExecuteJS(
                    'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' ..
                        tostring(-10) .. "}))"
                )
                inUse[i] = false
                running[i] = false
                return
            end
        end
    end
)

function getConf(config)
    -- print("Get conf " .. config)
    confResend = json.encode(config)
    WebUI:Init()
    
    WebUI:ExecuteJS(
        'document.dispatchEvent(new CustomEvent("Killstreak:UI:getAllKillstreaks",{detail:' .. confResend .. "}))"
    )
    WebUI:ExecuteJS(
        'document.dispatchEvent(new CustomEvent("Killstreak:UpdateScore",{detail:"' .. tostring(score) .. '"}))'
    )
    WebUI:Show()
    WebUI:DisableKeyboard()
    config = json.decode(config)
end

function calcStep(data)
    count = 1
    tempTable = {}
    if selectedKillstreaks ~= nil then
        tempTable = selectedKillstreaks
    end
    for _ in pairs(tempTable) do
        count = count + 1
    end
    if count == 1 then
        return
    end
    for i = 1, count, 1 do
        if i + 1 == count then
            step = 4
            break
        end

        if i == 1 then
            if tempTable[i][3] > data then
                print("New Step minimal " .. tostring(0))
                step = 0
                break
            end
        end
        if tempTable[i][3] <= data and data < tempTable[i + 1][3] then
            print("New Step " .. tostring(i))
            step = i
            break
        end
        print(tostring(tempTable[i][3]) .. " | " .. tostring(data) .. " | " .. tostring(tempTable[i + 1][3]))
    end
end


NetEvents:Subscribe(
    "Killstreak:StepUpdate",
    function(data)
        step = data
    end
)

-- invoke this to adjust the points your killstreak costs
-- usedStep = index you got with the Invoke event (parameter 1)
-- timeBased = set this to true to decrase the playe score but block the reuse of your killstreak till you call Events:Dispatch("Killstreak:Finished", curStep)
Events:Subscribe(
    "Killstreak:usedStep",
    function(usedStep, timeBased)
        converted = json.encode(inUse)
        print("Client recievet step used")
        print("used Step " .. tostring(usedStep))
        print("inUse: " .. converted)
        WebUI:ExecuteJS(
            'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' .. tostring(-10) .. "}))"
        )
        inUse[usedStep] = false
        if timeBased == nil or timeBased == false then
            running[usedStep] = false
        end

        NetEvents:SendLocal("Killstreak:notifyServerUsedSteps", usedStep)
    end
)

Events:Subscribe(
    "Killstreak:Finished",
    function(usedStep)
        running[usedStep] = false
    end
)
function resetState()
    step = -1
    inUse = {false, false, false, false}
    -- blocks the use of time based killstreaks and prevent that is constantily shown in the ui
    running = {false, false, false, false}
    score = 0
    disabledAction = false
    WebUI:ExecuteJS(
        'document.dispatchEvent(new CustomEvent("Killstreak:UI:selectStep",{detail:' .. tostring(-10) .. "}))"
    )
    WebUI:ExecuteJS(
        'document.dispatchEvent(new CustomEvent("Killstreak:UpdateScore",{detail:"' .. tostring(0) .. '"}))'
    )
end

Events:Subscribe(
    "Server:RoundOver",
    self,
    function()
        for i, v in pairs(self.playerKillstreakScore) do
            self.playerKillstreakScore[i] = 0
            NetEvents:SendTo("Killstreak:ScoreUpdate", PlayerManager:getPlayerById(i), tostring(0))
        end
    end
)

Events:Subscribe(
    "Server:RoundReset",
    self,
    function()
        for i, v in pairs(self.playerScores) do
            self.playerScores[i] = 0
        end
        for i, v in pairs(self.playerKillstreakScore) do
            self.playerKillstreakScore[i] = 0
            NetEvents:SendTo("Killstreak:ScoreUpdate", PlayerManager:getPlayerById(i), tostring(0))
        end
    end
)
