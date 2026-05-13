local I = require('openmw.interfaces')

I.Settings.registerPage({
    key         = 'BattleExp',
    l10n        = 'BattleExp',
    name        = 'Battle Exp',
    description = 'HP/Endurance overhaul that rewards combat exposure. HP is deleveled and Endurance kill based. Think XP, but simpler.',
})

I.Settings.registerGroup({
    key              = 'SettingsBattleExp',
    page             = 'BattleExp',
    l10n             = 'BattleExp',
    name             = 'Customize your experience',
    permanentStorage = true,
    settings = {
        {
            key         = 'hideLevel',
            renderer    = 'checkbox',
            name        = 'Hide Character Level',
            description = 'Hides the level row in the character sheet.',
            default     = true,
        },
        {
            key         = 'disableLevel',
            renderer    = 'checkbox',
            name        = 'Disable Character Leveling',
            description = 'Disables vanilla character leveling.',
            default     = true,
        },
        {
            key         = 'userBattleExpScale',
            name        = 'Battle Experience progress scaling (%)',
            description = 'A higher percentage means faster leveling \n(1% - slowest, 100% - default, 1000% - fastest)',
            renderer    = 'number',
            integer     = true,
            default     = 100,
            min         = 1,
            max         = 1000,
        },
        {
            key         = 'showXpNotifications',
            renderer    = 'checkbox',
            name        = 'Show "defeated" notifications',
            description = 'Displays a "defeated" notification after each killed enemy.',
            default     = true,
        },
        {
            key         = 'showScaledXp',
            renderer    = 'checkbox',
            name        = 'Show scaled XP in "defeated" notifications',
            description = 'Scaled XP is affected by your Battle Experience level and custom scale, base XP depends only on enemy lvl',
            default     = false,
        },
        {
            key         = 'rewardMelee',
            renderer    = 'checkbox',
            name        = 'Reward melee combat',
            description = 'Grants small XP bonus to Battle Experience for using melee weapons.',
            default     = true,
        },
        {
            key         = 'synergicTraining',
            renderer    = 'checkbox',
            name        = 'Synergic training',
            description = 'Using any melee weapon slightly improves proficiency with all others (until 50 skill lvl).',
            default     = false,
        },
    },
})
