local DEBUG = false

local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local types = require('openmw.types')
local selfObj = require('openmw.self')
local SF = require('openmw.interfaces').SkillFramework

if not SF then
    error("[BattleExp] Skill Framework is not loaded! Make sure it is installed and enabled.")
end

local skillId = 'battle_experience'
local useTypes = { Kill = 1 }

SF.registerSkill(skillId, {
    name = "Battle Experience",
    description = "Hard-earned combat experience, forged in the ashes of slain foes.",
    icon = { fgr = "icons/k/Attribute_Endurance.dds" },
    attribute = "endurance",
    specialization = SF.SPECIALIZATION.Combat,
    skillGain = {
        [useTypes.Kill] = 0.1 -- Amount of XP gained per kill (default)
    }
})

-- Initialize the skill to a base level of 5 if it's currently 0 or nil
-- This ensures the UI progress bar math calculates properly
local skillStat = SF.getSkillStat(skillId)
if skillStat and (skillStat.base == nil or skillStat.base < 5) then
    skillStat.base = 5
end

local function growEndurance(amount)
    local endurance = types.Actor.stats.attributes.endurance(selfObj)
    local newVal = endurance.base + amount
    endurance.base = newVal
    if DEBUG then print(string.format("[BattleExp] Endurance increased to %d", newVal)) end
end

-- HP formula: e + (e^2 / 100)
-- 30 endurance = 39 hp (9 HP more than in vanilla)
-- 50 endurance = 75 hp (15 HP more than in vanilla)
-- 62 endurance = 100 hp (corresponds to ~10 lvl orc)
-- 100 endurance = 200 hp (corresponds to ~20 lvl orc)
local function calcMaxHP(endurance)
    return endurance + (endurance * endurance / 100)
end

local function setHealthFromEndurance()
    local types = require('openmw.types')
    local selfObj = require('openmw.self')
    local e = types.Actor.stats.attributes.endurance(selfObj).base
    local newMaxHP = calcMaxHP(e)
    local health = types.Actor.stats.dynamic.health(selfObj)
    health.base = newMaxHP
    if DEBUG then print(string.format("[BattleExp] Endurance=%d -> MaxHP=%.1f", e, newMaxHP)) end
end

-- hide character level in char sheet
local API = require('openmw.interfaces').StatsWindow
local C = API.Constants

API.modifyLine(C.DefaultLines.LEVEL, {
    visibleFn = function() return false end,
})

-- prevent leveling up character
local SP = require('openmw.interfaces').SkillProgression
SP.addSkillLevelUpHandler(function(skillId, source, options)
    options.levelUpProgress = nil
end)

return {
    engineHandlers = {
        onLoad = function()
            setHealthFromEndurance()
        end,
        onActive = function()
            setHealthFromEndurance()
        end,
        onSleepFinished = function()
            setHealthFromEndurance()
        end,
    },
    eventHandlers = {
        UiModeChanged = function(data)
        if not data.newMode then
            -- UI was just closed (rest, char sheet, etc.)
            setHealthFromEndurance()
            end
        end,
        GrantEnduranceReward = function(data)
            local enemyLevel = data and data.level or 1
            local enemyName = data and data.name
            local baseXPFactor = 0.1
            local dynamicXP = enemyLevel * baseXPFactor

            local stat = SF.getSkillStat(skillId)
            local reqForCurentLevel = SF.getSkillProgressRequirement(skillId)

            local currentProgressPercent = stat.progress or 0
            local currentProgress = currentProgressPercent * reqForCurentLevel

            local xpNeededToLevelUp = reqForCurentLevel - currentProgress

            if DEBUG then print(string.format("[BattleExp] xpNeededToLevelUp %s", tostring(xpNeededToLevelUp))) end

            if dynamicXP >= xpNeededToLevelUp then
                local levelBefore = SF.getSkillStat(skillId).base

                -- add until level up
                SF.skillUsed(skillId, {
                    skillGain = xpNeededToLevelUp,
                    useType = useTypes.Kill
                })
                
                -- carryover surplus XP
                local surplusXP = dynamicXP - xpNeededToLevelUp
                if surplusXP > 0 then
                    SF.skillUsed(skillId, {
                        skillGain = surplusXP,
                        useType = useTypes.Kill
                    })
                end

                local levelAfter = SF.getSkillStat(skillId).base
                local levelsGained = levelAfter - levelBefore

                growEndurance(levelsGained)  -- +1 Endurance per skill level gained
                setHealthFromEndurance()
            else
                -- no skill level up
                SF.skillUsed(skillId, {
                    skillGain = dynamicXP,
                    useType = useTypes.Kill
                })
            end

            ui.showMessage(string.format("%s defeated (+%.1f XP)", enemyName, dynamicXP))
        end
    }
}

-- TODO:
-- detect player's summons as killers
-- disabled character levelling rly works?
-- drain/fortify works?
-- Heavy armor, medium armor and spear are governed by strength
