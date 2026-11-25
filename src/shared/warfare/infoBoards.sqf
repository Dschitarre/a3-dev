// Information boards: the info dialog with its topics (hotkeys, game mode, ranks, perks, equipment, vehicles, groups,
// revive) as structured text, built on the client from the current game values (client; opened by the base action
// "Show Information", SC\baseActions.sqf).

// ---- text building blocks ----

SC_fnc_infoHeading = {
    params ["_text"];

    format ["<t font='RobotoCondensedBold' size='1.2'>%1</t><br/>", _text]
};

SC_fnc_infoParagraph = {
    params ["_text"];

    _text + "<br/><br/>"
};

SC_fnc_infoList = {
    params ["_items"];

    ((_items apply {[_x] call SC_fnc_infoListItem}) joinString "<br/>") + "<br/><br/>"
};

// ---- bullet points with a hanging indent ----
// Structured text has no indent, so an item longer than a line is wrapped here: the continuation lines start with the
// same characters as the bullet, invisible, and line up with the item text. Wraps to SC_var_infoWrapWidth (set by
// SC_fnc_showInfoTopic before it builds the text); measured in the font and size of the info text (UI_StructuredText).

SC_var_infoBullet = "•  ";
SC_var_infoBulletIndent = "<t color='#00000000' shadow='0'>•</t>  ";
SC_var_infoWrapWidth = 0;

// words of a structured text: split at the spaces outside of tags
SC_fnc_infoWords = {
    params ["_text"];

    private _words = [];
    private _open = "";

    {
        private _word = if (_open == "") then {_x} else {_open + " " + _x};
        private _codes = toArray _word;

        // more "<" than ">": the space was inside a tag
        if (({_x == 60} count _codes) > ({_x == 62} count _codes)) then {
            _open = _word;
        } else {
            _open = "";
            _words pushBack _word;
        };
    } forEach (_text splitString " ");

    if (_open != "") then {
        _words pushBack _open;
    };

    _words
};

// text without tags, for measuring
SC_fnc_infoPlainText = {
    params ["_text"];

    if ((_text find "<") == -1) exitWith {_text};

    private _pieces = _text splitString "<";
    private _plain = if ((_text select [0, 1]) == "<") then {""} else {_pieces deleteAt 0};

    {
        _plain = _plain + (_x select [(_x find ">") + 1]);
    } forEach _pieces;

    _plain
};

SC_fnc_infoListItem = {
    params ["_item"];

    if ((SC_var_infoWrapWidth <= 0) || {(_item find "<br") != -1}) exitWith {SC_var_infoBullet + _item};

    private _fontSize = (((safeZoneW / safeZoneH) min 1.2) / 1.2) / 25;
    private _lines = [];
    private _line = [];
    private _linePlain = SC_var_infoBullet;

    {
        private _wordPlain = [_x] call SC_fnc_infoPlainText;
        private _candidate = _linePlain + ([" ", ""] select (_line isEqualTo [])) + _wordPlain;

        if ((_line isNotEqualTo []) && {(_candidate getTextWidth ["RobotoCondensed", _fontSize]) > SC_var_infoWrapWidth}) then {
            _lines pushBack (_line joinString " ");
            _line = [_x];
            _linePlain = SC_var_infoBullet + _wordPlain;
        } else {
            _line pushBack _x;
            _linePlain = _candidate;
        };
    } forEach ([_item] call SC_fnc_infoWords);

    _lines pushBack (_line joinString " ");

    SC_var_infoBullet + (_lines joinString ("<br/>" + SC_var_infoBulletIndent))
};

SC_fnc_infoBold = {
    params ["_text"];

    format ["<t font='RobotoCondensedBold'>%1</t>", _text]
};

// the player's key for an action ("V"), _default if none is bound
SC_fnc_infoActionKey = {
    params ["_action", "_default"];

    private _keys = ((actionKeysNames [_action, 1]) splitString """") joinString "";

    if (_keys == "") then {_default} else {_keys}
};

// "Ranks 6 - 17: 2 perk slots" lines from SC_var_rankForPerkId
SC_fnc_infoPerkSlotLines = {
    private _ranks = SC_var_rankForPerkId select [1, (count SC_var_rankForPerkId) - 1];
    private _lines = [];

    {
        private _slots = _forEachIndex + 1;
        private _rangeText = if (_slots == (count _ranks)) then {
            format ["Rank %1 and up", _x]
        } else {
            format ["Ranks %1 - %2", _x, ((_ranks select _slots) - 1)]
        };

        _lines pushBack format ["%1: %2 perk slot%3", _rangeText, _slots, (["s", ""] select (_slots == 1))];
    } forEach _ranks;

    _lines
};

// "3x APERS Mine, APERS Tripwire Mine; 2x ..." from VA_maxItemCounts of the item config
SC_fnc_infoMaxItemCountsText = {
    private _byCount = createHashMap;

    {
        _x params ["_class", "_max"];

        private _names = _byCount getOrDefault [_max, []];
        _names pushBackUnique ([_class] call SC_fnc_getDisplayName);
        _byCount set [_max, _names];
    } forEach ((getArray (missionConfigFile >> "VA_maxItemCounts")) select {isClass (configFile >> "CfgMagazines" >> (_x select 0))});

    private _counts = keys _byCount;
    _counts sort false;

    (_counts apply {format ["%1x %2", _x, ((_byCount get _x) joinString ", ")]}) joinString "; "
};

// "a Spawn Truck (Zamak Medical) and a Spawn Helicopter (...)": the spawn vehicles of every side on this map, "" if none
SC_fnc_infoSpawnVehiclesText = {
    private _side = side (group player);

    ((missionNamespace getVariable ["SC_var_spawnVehicleKinds", []]) apply {
        _x params ["_kind", "_count"];

        private _name = SC_var_spawnVehicleNames get _kind;
        private _type = [_side, _kind] call SC_fnc_getSpawnVehicleType;
        private _typeText = if (_type == "") then {""} else {format [" (%1)", ([_type] call SC_fnc_getDisplayName)]};

        if (_count == 1) then {
            format ["a %1%2", _name, _typeText]
        } else {
            format ["%1 %2s%3", _count, _name, _typeText]
        }
    }) joinString " and "
};

// ---- topics ----

// perk descriptions by abbreviation (name and rank come from SC_var_perkConfig)
SC_var_infoPerkTexts = createHashMapFromArray [
    ["EXPR", "+50 % XP for kills, sector captures and teamplay; double XP for revives."],
    ["MEDC", "A Medikit instead of 4 first aid kits. You can revive every teammate, not only your group mates, and you stabilize and revive 1.5 times faster."],
    ["STAM", "Sprinting uses half the stamina, so you can sprint about twice as long; stamina recovers a bit slower (75 %)."],
    ["MRKS", "Marksman rifles, long range scopes and ghillie suits; a rangefinder instead of the binoculars."],
    ["MGNR", "Machine guns."],
    ["LNCR", "Rocket and missile launchers."],
    ["ARMR", "Heavy plate carriers, helmets and uniforms with armor level IV and V."],
    ["GRND", "Rifles with underbarrel grenade launchers and their grenades."],
    ["DEMO", "Mines, explosive charges, claymores and IEDs, in limited numbers (see Equipment and Arsenal). AI never take this perk and airdrops never contain explosives."],
    ["SUPR", "Suppressors."]
];

// [key, title, code returning the structured text]; the order is the order of the topic list
SC_fnc_infoAirdropRules = {
    ["Supply crates are dropped by parachute into the play zone again and again as the points of all sides grow.",
     "A side that falls behind the leading side gets extra drops on one of its sectors (in its base if it owns none) each time its deficit grows by a few more points."]
};

SC_var_infoTopics = [
    ["hotkeys", "Hotkeys", {
        private _thermalText = if (("thermalVision" call BIS_fnc_getParamValue) == 0) then {" (thermal vision is disabled on this server)"} else {""};

        [
            ["Keys"] call SC_fnc_infoHeading,
            [[
                (["F1"] call SC_fnc_infoBold) + ": earplugs in / out (they lower the game volume); an icon at the top right shows while earplugs are in",
                (["Ctrl+F1"] call SC_fnc_infoBold) + ": earplugs settings (also in the F4 settings): the volume of the F1 earplugs, and automatic earplugs while you sit in a ground vehicle, aircraft or boat, each on / off with its own volume. If several earplugs are in, the lowest volume applies",
                (["F2"] call SC_fnc_infoBold) + ": HUD on / off (the settings decide which parts are shown)",
                (["F3"] call SC_fnc_infoBold) + ": GPS / vehicle panel on the right on / off",
                (["F4"] call SC_fnc_infoBold) + ": settings: HUD parts, view distance and grass, earplugs",
                ([["TeamSwitch", "U"] call SC_fnc_infoActionKey] call SC_fnc_infoBold) + ": group menu: join or leave a group; as group leader set its size, lock it and kick members",
                (["H"] call SC_fnc_infoBold) + ": holster / take out your weapon",
                (["J"] call SC_fnc_infoBold) + ": lock / unlock the vehicle you sit in or look at; " + (["Shift+J"] call SC_fnc_infoBold) + ": order the AI out of your locked vehicle",
                ([["GetOver",
                    "V"] call SC_fnc_infoActionKey] call SC_fnc_infoBold) +
                    " while running, also crouched: jump; after the landing you are back in your stance from before (" +
                    ([["Crouch",
                    "X"] call SC_fnc_infoActionKey] call SC_fnc_infoBold) +
                    " during the jump switches it). Standing or walking it climbs over obstacles as usual",
                ([["nightVision", "N"] call SC_fnc_infoActionKey] call SC_fnc_infoBold) + ": switch the vision mode" + _thermalText,
                (["Space"] call SC_fnc_infoBold) + " while unconscious: give up and respawn"
            ]] call SC_fnc_infoList,
            ["Base objects"] call SC_fnc_infoHeading,
            [[
                "Information board: these topics, the equipment list and your statistics",
                "Loadout: arsenal, stored loadouts, last saved loadout, fill magazines",
                "Perks: choose your perks",
                "Vehicles: spawn a vehicle",
                "Teleport: respawn at once and choose a new spawn position",
                "Service area (wrench marker on the map) at the vehicle spawn point: stop there to repair, rearm and refuel"
            ]] call SC_fnc_infoList
        ] joinString ""
    }],
    ["gameMode", "Game Mode", {
        private _playZoneText = if (missionNamespace getVariable ["SC_var_wholeMap", false]) then {
            "This map has no play zone limit. "
        } else {
            "Leaving the play zone (marked on the map) starts a 30 s countdown; if you are still outside when it runs out, you die. "
        };
        private _spawnVehicleText = if ((missionNamespace getVariable ["SC_var_spawnVehicleKinds", []]) isEqualTo []) then {
            ""
        } else {
            " a spawn vehicle of your side (see Vehicles &amp; Airdrops),"
        };

        [
            ["Goal"] call SC_fnc_infoHeading,
            ["Three sides fight for the sectors of the play zone. Every side gains points all the time, in proportion to the share of the sectors it owns. The first side to reach 100 points wins the round. The HUD shows the points of every side at the bottom right with their points per minute above them."] call SC_fnc_infoParagraph,
            ["Sectors"] call SC_fnc_infoHeading,
            [[
                "A side moves the flag of a sector while it has more units in the sector than all other sides together. Unconscious units and aircraft higher than 25 m don't count, vehicles count their crew.",
                "An enemy sector is neutralized first (its flag goes down to 0 %), then raised to 100 %. Only then it is owned: it gives points and is a respawn position of the owner.",
                "The more you outnumber the others, the faster the flag moves.",
                "The sector overview at the top shows the flag of every sector in its holder's color. While you stand in a sector, the box below it shows the progress, the state (Capturing, Held, Contested, Enemy capturing) and the force ratio own : enemy units."
            ]] call SC_fnc_infoList,
            ["Respawn"] call SC_fnc_infoHeading,
            [[
                format ["After %1 s you choose where to respawn: your base, a sector your side owns,%2 or a group mate who is alive and conscious (in a free seat of his vehicle if he sits in one).", SC_var_hudRespawnDelay, _spawnVehicleText],
                "Spawn protection lasts until you walk away from the base respawn point, elsewhere a few seconds.",
                "While you wait, Spectate lets you watch your teammates."
            ]] call SC_fnc_infoList,
            ["Play zone"] call SC_fnc_infoHeading,
            [_playZoneText + "Entering an enemy base starts a 15 s countdown. Inside your own base the inventory is locked: use the arsenal there."] call SC_fnc_infoParagraph,
            ["Round end and map vote"] call SC_fnc_infoHeading,
            [format ["When a side reaches 100 points, a camera circles the play area and the end screen shows the winner, the round duration, the MVPs (most XP, kills, captures and revives) and the leaderboard of all players. Vote for the next map within %1 s; you can change your vote until then. The map with the most votes wins (a tie is decided randomly, Random if nobody votes), it is shown for %2 s, then the mission ends. Your XP, rank, perks and statistics are saved.", SC_var_mapVoteDuration, SC_var_mapVoteResultTime]] call SC_fnc_infoParagraph
        ] joinString ""
    }],
    ["ranks", "Ranks & XP", {
        (call SC_fnc_getPlayerData) params ["_xp"];
        private _rank = player getVariable ["SC_var_rank", 1];
        private _xpExamples = [10, 20, 50] apply {format ["rank %1: %2 XP", _x, (SC_var_xpRanks select (_x - 1))]};

        [
            ["Ranks"] call SC_fnc_infoHeading,
            [format [
                "You earn XP for nearly everything that helps your side. With enough XP you rank up: higher ranks unlock better equipment and vehicles, some ranks unlock perks and more perk slots. The next rank needs %1 XP at rank 1, a little more at every further rank (%2). You are rank %3 with %4 of %5 XP."
                ,(SC_var_xpRanks select 0),(_xpExamples joinString ", "), _rank,
                ([_xp] call SC_fnc_formatCompactNumber),
                ([SC_var_neededXp] call SC_fnc_formatCompactNumber)]] call SC_fnc_infoParagraph,
            ["XP for kills and revives"] call SC_fnc_infoHeading,
            [[
                "Kill: 100 XP, more for destroyed vehicles (the higher their rank, the more). Long range kills give a bonus (x 1.3 at 500 m, x 1.6 at 1 km).",
                "Assist (you hit the enemy, somebody else killed him): a third of that.",
                format ["Bounty: an enemy who killed %1 or more in a row without going down is worth %2 XP more to his killer, +%3 for every further kill, at most %4 XP (the kill feed shows it behind his name).", SC_var_bountyMinStreak, SC_var_bountyXp, SC_var_bountyXpPerKill, SC_var_bountyMaxXp],
                "Revive: 50 XP."
            ]] call SC_fnc_infoList,
            ["XP for sectors"] call SC_fnc_infoHeading,
            [[
                format ["4 XP per capture tick while your side moves the flag of the sector you stand in (about 200 XP per minute), credited every %1 s.", SC_var_captureXpSendInterval],
                "200 XP for every player of your side in the sector when your side raises a sector from 0 % to 100 %."
            ]] call SC_fnc_infoList,
            ["Teamplay XP (shown in the mid feed)"] call SC_fnc_infoHeading,
            [[
                format ["Transport: %1 XP per passenger of your side you drive at least %2 m and drop off near a sector your side doesn't own; %3 XP more if they capture that sector within %4 minutes.", SC_var_transportXp, SC_var_transportMinDistance, SC_var_transportCaptureXp, (SC_var_transportCaptureTime / 60)],
                format ["Defence: %1 XP for a kill in a sector of your side or up to %2 m around it.", SC_var_defenceXp, SC_var_defenceDistance],
                format ["Repair: up to %1 XP for repairing a vehicle with a toolkit, depending on the repaired damage (at most once per vehicle every %2 minutes).", SC_var_repairXp, (SC_var_repairXpCooldown / 60)]
            ]] call SC_fnc_infoList,
            ["With the Experience perk all of these give 50 % more XP, revives double XP."] call SC_fnc_infoParagraph,
            ["Perk slots"] call SC_fnc_infoHeading,
            [call SC_fnc_infoPerkSlotLines] call SC_fnc_infoList,
            ["A new slot is empty until you choose a perk for it at the Perks object in your base."] call SC_fnc_infoParagraph
        ] joinString ""
    }],
    ["perks", "Perks", {
        [
            ["Perks"] call SC_fnc_infoHeading,
            ["Perks unlock equipment or give a bonus. Choose them at the Perks object in your base; your rank decides how many perk slots you have (see Ranks &amp; XP) and which perks you can choose. Removing an equipment perk also removes the gear it unlocked from your loadout. Stored loadouts keep their perks."] call SC_fnc_infoParagraph,
            [SC_var_perkConfig apply {
                _x params ["_name", "_abbreviation", "_rank"];

                format ["%1 [%2], rank %3: %4", ([_name] call SC_fnc_infoBold), _abbreviation, _rank, (SC_var_infoPerkTexts getOrDefault [_abbreviation, ""])]
            }] call SC_fnc_infoList
        ] joinString ""
    }],
    ["equipment", "Equipment & Arsenal", {
        [
            ["Arsenal"] call SC_fnc_infoHeading,
            [[
                "Change Loadout at the Loadout object in your base opens the arsenal with everything your rank and perks unlock. Every rank unlocks more items; the Equipment List on the information board shows all items with their required rank, per perk.",
                "When you close the arsenal, your loadout is saved and you respawn with it. Load last saved Loadout restores it, Fill magazines refills your magazines.",
                "Items you carry but haven't unlocked (picked up from enemies or airdrops) are locked: in the arsenal you can keep, reduce or remove them, but not add more or put them into another slot. A loadout with locked items is not saved as your respawn loadout.",
                "Without the Medic perk you always carry 4 first aid kits, with it a Medikit."
            ]] call SC_fnc_infoList,
            ["Explosives"] call SC_fnc_infoHeading,
            [format ["With the Explosives perk you can carry at most: %1 (in uniform, vest and backpack together).", (call SC_fnc_infoMaxItemCountsText)]] call SC_fnc_infoParagraph,
            ["Stored loadouts"] call SC_fnc_infoHeading,
            [[
                "Store/Load Loadouts at the Loadout object keeps any number of loadouts together with their perks: store your current loadout in a new row or overwrite one, load or delete one. The last row loads the base loadout.",
                "Loadouts are stored per map family (the vanilla maps and Chernarus have their own).",
                "A loadout stored on another side is converted when you load it: uniform, vest, helmet, backpack and night vision become the equivalent of your side with the same rank; gear without an equivalent is kept."
            ]] call SC_fnc_infoList
        ] joinString ""
    }],
    ["vehicles", "Vehicles & Airdrops", {
        private _limitText = if SC_var_hugeMap then {
            "There is no vehicle limit on this map."
        } else {
            format ["Every side can have at most %1 vehicles; the vehicle spawn menu shows your side's count.", SC_var_maximumVehicleAmount]
        };
        private _placesText = if ((missionNamespace getVariable ["SC_var_planeSpawnIds", []]) isNotEqualTo []) then {
            ", on huge maps also at the airfields inside the play zone (planes only at the base and the airfields)"
        } else {
            ""
        };
        private _spawnVehiclesText = call SC_fnc_infoSpawnVehiclesText;
        private _spawnVehiclesInfo = if (_spawnVehiclesText == "") then {
            ["There are no spawn vehicles on this map: every side gets them on medium and bigger maps, unless the server turned them off."] call SC_fnc_infoParagraph
        } else {
            [[
                format ["On this map your side has %1. They start at the base: drive or fly them forward.", _spawnVehiclesText],
                format ["A spawn vehicle is a respawn position of your side while it stands still outside the bases and inside the play zone, upright and (a helicopter) landed, the engine may run, with no enemy within %1 m and not hit in the last %2 s. The respawn menu lists it; the map and a 3D icon show it with its name and, while it is no respawn position, why not.", SC_var_spawnVehicleEnemyRadius, SC_var_spawnVehicleHitCooldown],
                "You respawn in a free cargo seat, else next to it.",
                "Enemies can't get in. Nobody can lock it, and it doesn't count for the vehicle limit. It can't be damaged until it leaves the base for the first time.",
                format ["When it is destroyed, a new one is ready at the base after %1 min. An empty one that can't move or is outside the play zone for %2 min is replaced the same way.", (SC_var_spawnVehicleRespawnTime / 60), (SC_var_spawnVehicleAbandonTime / 60)]
            ]] call SC_fnc_infoList
        };

        [
            ["Spawning"] call SC_fnc_infoHeading,
            [[
                format ["Spawn vehicles at the Vehicles object in your base, at the flag of a sector your side owns (if the server allows it)%1.", _placesText],
                "Better vehicles unlock with your rank. Vehicles that are too big for this map are marked red.",
                format ["After spawning a vehicle you have to wait %1 minutes until your next one (the cooldown survives a reconnect; it is reset if no spawn position was found).", (SC_var_vehicleSpawnCooldown / 60)],
                "A vehicle spawned at the base can't be damaged until it leaves the base. Every spawned vehicle carries a toolkit, a Medikit and 10 first aid kits; everybody can repair with a toolkit."
            ]] call SC_fnc_infoList,
            ["Limit and ownership"] call SC_fnc_infoHeading,
            [_limitText + " A vehicle counts for the side that used it last: its ownership timer stays full while units of that side sit in it and runs down while none of them are near. When it runs out, the vehicle is free and counts for whoever takes it next. Vehicles that nobody uses are removed after a while."] call SC_fnc_infoParagraph,
            ["Locking"] call SC_fnc_infoHeading,
            [[
                "Players of the vehicle's side (and the player who spawned it) can lock an unlocked vehicle with J (in it or looking at it); AI that were assigned to it leave it.",
                "Only the player who locked it can unlock it (J) or order AI out of it (Shift+J). It is unlocked when he leaves the server.",
                "Group mates can respawn in the free seats of your vehicle."
            ]] call SC_fnc_infoList,
            ["Spawn vehicles"] call SC_fnc_infoHeading,
            _spawnVehiclesInfo,
            ["Service"] call SC_fnc_infoHeading,
            [format ["Vehicles of your side that stand still or move slowly in the service area of your base (wrench marker on the map, at the vehicle spawn point, on huge maps also at the plane spawn point) are repaired, rearmed and refueled step by step, completely in about %1 s. Aircraft have to land there, the engine may run. The crew is told when the service starts and when it is complete.", SC_var_serviceDuration]] call SC_fnc_infoParagraph,
            ["Airdrops"] call SC_fnc_infoHeading,
            [(call SC_fnc_infoAirdropRules) + [
                "A crate holds random weapons with magazines, optics, suppressors and other gear, also items you haven't unlocked yet (locked in the arsenal), but no explosives. It disappears after a few minutes; the map and its 3D icon show the remaining time."
            ]] call SC_fnc_infoList
        ] joinString ""
    }],
    ["groups", "Groups & AI", {
        [
            ["Groups"] call SC_fnc_infoHeading,
            [[
                format ["Everybody is in a group: by default squads of 4 (the rest in squads of 3, never more than 4), players and AI of the same side; a group whose size was set, that is locked or that a player joined via the menu stays as it is. Press %1 for the group menu: join another group (if it is full, one of its AI makes room) or leave yours for a new one of your own; the leader of a group (a player) sets its size, can lock it for players or AI and kick members.", ([["TeamSwitch", "U"] call SC_fnc_infoActionKey] call SC_fnc_infoBold)],
                "The group overview at the bottom left shows every group mate with role, rank, health, vehicle and distance, while unconscious the bleed out time and when dead the respawn time.",
                "You can respawn at a group mate who is alive and conscious, also in a free seat of his vehicle.",
                "Group mates can revive each other without the Medic perk."
            ]] call SC_fnc_infoList,
            ["AI"] call SC_fnc_infoHeading,
            [[
                "AI fill every side up to the same strength, which depends on the map size (at least the number of players of the biggest side). When players join, AI leave; when players leave, AI come back. A joining player can take over an AI.",
                "AI capture sectors, use vehicles and revive their group mates; AI medics revive every teammate.",
                "The player who locked a vehicle can order the AI out of it."
            ]] call SC_fnc_infoList
        ] joinString ""
    }],
    ["revive", "Revive", {
        private _bleedOutTime = missionNamespace getVariable ["AIS_BLEEDOUT_TIME", 120];

        [
            ["Unconscious"] call SC_fnc_infoHeading,
            [format ["Heavy damage knocks you unconscious instead of killing you, but more damage (e.g. an explosion) can still kill you. You bleed out after %1 s unless a teammate stabilizes you. Press Space to give up and respawn.", _bleedOutTime]] call SC_fnc_infoParagraph,
            ["Helping teammates"] call SC_fnc_infoHeading,
            [[
                "Stabilize: every teammate can stop the bleeding of an unconscious unit; a stabilized unit doesn't bleed out.",
                "Revive: medics (Medic perk) can revive every teammate, everybody else only his group mates. Medics stabilize and revive 1.5 times faster. A revive gives 50 XP (100 with the Experience perk).",
                "Drag an unconscious teammate out of the line of fire, carry him over longer distances, release him, or load him into a vehicle (and unload him there).",
                "AI medics and AI group mates nearby come to help; while you wait, the screen shows whether a medic is coming."
            ]] call SC_fnc_infoList,
            ["Healing"] call SC_fnc_infoHeading,
            ["First aid kits heal you or a teammate partly, a Medikit (Medic perk) heals completely. Spawned vehicles carry a Medikit and 10 first aid kits. Your statistics count the units you revived and healed."] call SC_fnc_infoParagraph
        ] joinString ""
    }]
];

// ---- info dialog ----

// client (base action "Show Information"): info dialog with the topic _topicKey selected, by default the one viewed
// last
SC_fnc_openInfoDialog = {
    params [["_topicKey", (missionNamespace getVariable ["SC_var_lastInfoTopic", ""])]];

    createDialog "infoDialog";

    private _display = uiNamespace getVariable ["SC_var_infoDialog", displayNull];

    if (isNull _display) exitWith {};

    private _list = _display displayCtrl 1500;

    {
        _list lbAdd (_x select 1);
    } forEach SC_var_infoTopics;

    private _index = 0 max (SC_var_infoTopics findIf {(_x select 0) == _topicKey});
    _list lbSetCurSel _index;
    [_index] call SC_fnc_showInfoTopic;
};

// client (topic list selection): title and text of a topic; the text control is as high as its text, the controls
// group around it scrolls
SC_fnc_showInfoTopic = {
    params ["_index"];

    private _display = uiNamespace getVariable ["SC_var_infoDialog", displayNull];

    if ((isNull _display) || {_index < 0}) exitWith {};

    (SC_var_infoTopics select _index) params ["_key", "_title", "_textCode"];

    SC_var_lastInfoTopic = _key;
    (_display displayCtrl 1002) ctrlSetText _title;

    private _group = _display displayCtrl 2300;
    private _text = _display displayCtrl 1100;

    // a small reserve for the inner margin of the text control and bold words (measured in the normal font)
    SC_var_infoWrapWidth = 0.96 * ((ctrlPosition _text) select 2);
    _text ctrlSetStructuredText parseText (call _textCode);

    private _pos = ctrlPosition _text;
    _pos set [3, ctrlTextHeight _text];
    _text ctrlSetPosition _pos;
    _text ctrlCommit 0;

    _group ctrlSetScrollValues [0, -1];
};
