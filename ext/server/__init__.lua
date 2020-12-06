local conf = require("configuration.lua")

class 'Killstreak'

function Killstreak:__init()
    print("Initializing server module")
    self.playerScores = {}
    self.playerKillstreakScore = {}
    self.playerKillstreaks = {}
    Events:Subscribe('Level:Loaded', self, self.OnLoad)
    Events:Subscribe('Level:Destroy', self, self.ResetState)
    Events:Subscribe('Player:Left', self, self.OnPlayerLeft)
    NetEvents:Subscribe("Killstreak:newClient",self,self.sendConfToNewClient)
    NetEvents:Subscribe("Killstreak:notifyServerUsedSteps",self,self.usedSteps)
    NetEvents:Subscribe("Killstreak:updatePlayerKS",self,self.updatePlayerKS)
end

function Killstreak:__gc()
    Events:Unsubscribe('Player:Update')
    NetEvents:Unsubscribe()
end

function Killstreak:OnLoad()
    Events:Unsubscribe('Player:Update')

    self:ResetState()
    
    Events:Subscribe("Player:Update",self,self.OnPlayerUpdate)
end

function Killstreak:sendConfToNewClient(player)
    print("New Player "..player.name.. "with conf "..json.encode(conf) )
    self.playerKillstreaks[player.id] = {}
    NetEvents:SendTo("Killstreak:Client:getConf",player,json.encode(conf))
end

function Killstreak:updatePlayerKS(player,ks)
    print("player killstreaks: ".. ks)
    if ks ~= nil then
        
        self.playerKillstreaks[player.id] = json.decode(ks)
    end
    
end
function Killstreak:ResetState()
    self.playerKillstreakScore = {}
    self.playerScores = {}
end

function Killstreak:OnPlayerLeft()
    return
end

function Killstreak:usedSteps(playerObj,usedStep)
    print("cost: ".. tostring(self.playerKillstreaks[playerObj.id][usedStep][3]))
    self.playerKillstreakScore[playerObj.id] = self.playerKillstreakScore[playerObj.id] - self.playerKillstreaks[playerObj.id][usedStep][3]
    print("Player " .. tostring(playerObj.name) .. " used Killstreaknr. "..tostring(usedStep) .." and a new KillStreak-Score: " .. tostring(self.playerKillstreakScore[playerObj.id]))
    NetEvents:SendTo("Killstreak:ScoreUpdate",playerObj,tostring(self.playerKillstreakScore[playerObj.id]))
end

function Killstreak:OnPlayerUpdate(player, deltaTime)
    if not player.alive or not player.hasSoldier then
        return
    end
    modified = false
    if self.playerScores[player.id] == nil then
        self.playerScores[player.id] = player.score 
        self.playerKillstreakScore[player.id] = player.score
        modified = true
    end
    if player.score > self.playerScores[player.id] then
        self.playerKillstreakScore[player.id] = self.playerKillstreakScore[player.id] + (player.score - self.playerScores[player.id])
        self.playerScores[player.id] = player.score
        modified = true
    end 

    if modified and self.playerKillstreakScore[player.id] ~= 0 then
        print("Player " .. tostring(player.name) .. " has new Ingame-Score: " .. tostring(player.score) .. " and a new KillStreak-Score: " .. tostring(self.playerKillstreakScore[player.id]))
        NetEvents:SendTo("Killstreak:ScoreUpdate",player,tostring(self.playerKillstreakScore[player.id]))
    end
end

g_KillStreakServer = Killstreak()