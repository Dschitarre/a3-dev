// GunGame weapon ladder (server and client): the ladder from weaponList[] (GG\weaponList.hpp) and the ladder params,
// kills, streaks and stage progress, the weapon of a unit's stage, endless ammo and spawn protection.

GG_var_magazineCount = 2;           // magazines per weapon; GG_fnc_firedMan adds one whenever the last spare is loaded
GG_var_spawnProtectionTime = 3;     // seconds, ends earlier with the first shot
GG_var_minThemeWeapons = 3;         // a weapon theme with fewer weapons falls back to the mixed ladder
GG_var_streakAnnouncements = [3, 5, 10, 15, 20, 25, 30];
GG_var_stagesLeftAnnouncement = 3;  // "X has 3 weapons left" (besides "X is on the grenade")

/*
    GG_var_weaponList (public, built by the server): ladder entries [weapon, magazine, optic]; the last two are the
    grenade stage and the end, which is reached by winning and never handed out. GG_var_weaponNum (public unit
    variable) is a unit's stage.
*/

// ---- ladder (server) ----

/*
    ladderTheme: 0 Mixed, 1 Assault rifles, 2 Sniper rifles, 3 Machine guns, 4 Close quarters, 5 Pistols - weaponList[]
    filtered by weapon type. ladderLength: 0 Full, 1 Half, 2 Short (a quarter), picked evenly over the list.
*/
GG_fnc_buildLadder = {
    private _list = getArray (missionConfigFile >> "weaponList");
    private _finale = _list select [count _list - 2, 2];
    private _weapons = _list select [0, count _list - 2];

    private _themeTypes = [
        [],
        ["AssaultRifle"],
        ["SniperRifle"],
        ["MachineGun"],
        ["SubmachineGun", "Shotgun", "Handgun"],
        ["Handgun"]
    ] select ("ladderTheme" call BIS_fnc_getParamValue);

    if (_themeTypes isNotEqualTo []) then {
        private _themeWeapons = _weapons select {(((_x select 0) call BIS_fnc_itemType) select 1) in _themeTypes};

        if (count _themeWeapons >= GG_var_minThemeWeapons) then {
            _weapons = _themeWeapons;
        };
    };

    private _stageCount = ceil (count _weapons / ([1, 2, 4] select ("ladderLength" call BIS_fnc_getParamValue)));

    if (_stageCount > 1 && {_stageCount < count _weapons}) then {
        private _step = (count _weapons - 1) / (_stageCount - 1);
        private _picked = [];

        for "_i" from 0 to (_stageCount - 1) do {
            _picked pushBack (_weapons select round (_i * _step));
        };

        _weapons = _picked;
    };

    _weapons + _finale
};

// kills needed on a stage: the killsPerStage param, the grenade stage always one
GG_fnc_killsForStage = {
    params ["_weaponNum"];

    [GG_var_killsPerStage, 1] select (_weaponNum >= count GG_var_weaponList - 2)
};

// ---- stats and progress (server) ----

// ladder stats of a unit: stage, kills, deaths (public, HUD), current and best kill streak (server)
GG_fnc_resetLadderStats = {
    params ["_unit", ["_weaponNum", 0], ["_kills", 0], ["_deaths", 0], ["_bestStreak", 0]];

    [_unit, _weaponNum] call GG_fnc_setWeaponNum;
    _unit setVariable ["GG_var_kills", _kills, true];
    _unit setVariable ["GG_var_deaths", _deaths, true];
    _unit setVariable ["GG_var_streak", 0];
    _unit setVariable ["GG_var_bestStreak", _bestStreak];
};

// the stage of a unit; restarts its kills on the stage and remembers when it got there (rank tie-break)
GG_fnc_setWeaponNum = {
    params ["_unit", "_weaponNum"];

    _unit setVariable ["GG_var_weaponNum", _weaponNum, true];
    _unit setVariable ["GG_var_stageKills", 0];
    _unit setVariable ["GG_var_stageTime", time];
};

// "EntityKilled": deaths, kills, streaks and the stage progress (free for all: the killer, teams: his team)
GG_fnc_entityKilled = {
    params ["_unit", "_killer", "_instigator"];

    if (GG_var_ended || {!(_unit isKindOf "CAManBase")}) exitWith {};

    if (isNull _instigator) then {
        _instigator = (UAVControl objectParent _killer) select 0;
    };

    if (isNull _instigator) then {
        _instigator = _killer;
    };

    _unit setVariable ["GG_var_deaths", (_unit getVariable ["GG_var_deaths", 0]) + 1, true];
    _unit setVariable ["GG_var_streak", 0];

    // suicide (own grenade, fall, ...): no progress; with the demotion param one weapon back
    if (isNull _instigator || {_instigator == _unit}) exitWith {
        if (GG_var_demotion) then {
            [_unit] call GG_fnc_demote;
        };

        call GG_fnc_refreshLeaderBoardServer;
    };

    [_instigator] call GG_fnc_setRating;

    if (GG_var_teamMode && {([_instigator] call GG_fnc_teamOf) == ([_unit] call GG_fnc_teamOf)}) exitWith {};

    if (!GG_var_teamMode) then {
        _instigator addPlayerScores [2, 0, 0, 0, 0];
    };

    _instigator setVariable ["GG_var_kills", (_instigator getVariable ["GG_var_kills", 0]) + 1, true];

    private _streak = (_instigator getVariable ["GG_var_streak", 0]) + 1;
    _instigator setVariable ["GG_var_streak", _streak];
    _instigator setVariable ["GG_var_bestStreak", _streak max (_instigator getVariable ["GG_var_bestStreak", 0])];

    if (_streak in GG_var_streakAnnouncements) then {
        ["streak", name _instigator, _streak] call GG_fnc_announceGlobal;
    };

    if (GG_var_teamMode) then {
        [_instigator] call GG_fnc_teamStageKill;
    } else {
        [_instigator] call GG_fnc_stageKill;
    };

    call GG_fnc_refreshLeaderBoardServer;
};

// free for all: after the kills of its stage the killer gets the next weapon
GG_fnc_stageKill = {
    params ["_unit"];

    private _weaponNum = _unit getVariable ["GG_var_weaponNum", 0];
    private _stageKills = (_unit getVariable ["GG_var_stageKills", 0]) + 1;
    private _killsNeeded = [_weaponNum] call GG_fnc_killsForStage;

    if (_stageKills < _killsNeeded) exitWith {
        _unit setVariable ["GG_var_stageKills", _stageKills];
        [_unit, _weaponNum, format ["Enemy killed, %1 more for the next weapon", _killsNeeded - _stageKills]] call GG_fnc_notifyStage;
    };

    [[_unit], _weaponNum + 1, name _unit] call GG_fnc_setStage;
};

// demotion param: a suicide costs one weapon (in team mode the team's)
GG_fnc_demote = {
    params ["_unit"];

    if (GG_var_teamMode) exitWith {
        [[_unit] call GG_fnc_teamOf, -1] call GG_fnc_changeTeamStage;
    };

    private _weaponNum = _unit getVariable ["GG_var_weaponNum", 0];

    if (_weaponNum > 0) then {
        [[_unit], _weaponNum - 1, name _unit, false] call GG_fnc_setStage;
    };
};

/*
    New stage and weapon for _units (one unit, or the active members of a team). A promotion is announced on the last
    stages and wins the round at the end of the ladder; _displayName: the unit's or the team's name.
*/
GG_fnc_setStage = {
    params ["_units", "_weaponNum", "_displayName", ["_promoted", true]];

    private _lastWeaponNum = count GG_var_weaponList - 1;
    private _text = if (_promoted) then {
        format ["Next weapon, %1 left", _lastWeaponNum - _weaponNum]
    } else {
        "Suicide, one weapon back"
    };

    {
        [_x, _weaponNum] call GG_fnc_setWeaponNum;
        [_x] remoteExecCall ["GG_fnc_applyWeapon", _x];
        [_x, _weaponNum, _text] call GG_fnc_notifyStage;
    } forEach _units;

    if (!_promoted) exitWith {};

    switch (_lastWeaponNum - _weaponNum) do {
        case 0: {
            // at once: kills in the same frame must not count any more
            GG_var_ended = true;
            [_displayName] spawn GG_fnc_endRound;
        };
        case 1: {
            ["grenade", _displayName, 0] call GG_fnc_announceGlobal;
        };
        case GG_var_stagesLeftAnnouncement: {
            ["stagesLeft", _displayName, GG_var_stagesLeftAnnouncement] call GG_fnc_announceGlobal;
        };
    };
};

// stage notification for a player ("12/48" and _text)
GG_fnc_notifyStage = {
    params ["_unit", "_weaponNum", "_text"];

    if (!isPlayer _unit) exitWith {};

    ["gunGame", [format ["%1/%2", _weaponNum, count GG_var_weaponList - 1], "", _text]] remoteExecCall ["BIS_fnc_showNotification", _unit];
};

// announcement for everyone, formatted on each client (GG_fnc_announce)
GG_fnc_announceGlobal = {
    _this remoteExecCall ["GG_fnc_announce", [0, -2] select isDedicated];
};

// ---- weapons (on the unit's machine) ----

// inventory picture of a weapon, magazine or vehicle class
GG_fnc_getPicture = {
    params ["_class"];

    private _configRoot = switch (true) do {
        case (_class isKindOf "Car" || {_class isKindOf "Helicopter"} || {_class isKindOf "Tank"} || {_class isKindOf "StaticWeapon"}): {"CfgVehicles"};
        case (_class isKindOf [_class, configFile >> "CfgMagazines"]): {"CfgMagazines"};
        default {"CfgWeapons"};
    };

    getText (configFile >> _configRoot >> _class >> "picture")
};

// gives a local unit the weapon of its stage (remoteExec'd to the unit's owner after a stage change)
GG_fnc_applyWeapon = {
    params ["_unit"];

    if (_unit isEqualTo player) then {
        call GG_fnc_refreshNextWeapon;
    };

    if (!alive _unit) exitWith {};

    private _zeroing = (_unit currentZeroing [currentWeapon _unit, currentMuzzle _unit]) select 1;
    private _fireMode = (weaponState _unit) select 2;
    _unit setUnitLoadout ([_unit] call GG_fnc_baseLoadout);
    (GG_var_weaponList select (_unit getVariable ["GG_var_weaponNum", 0])) params ["_weapon", "_magazine", "_optic"];

    // the grenade stage is a magazine, not a weapon (GG_fnc_firedMan replaces every thrown grenade)
    if (!(_weapon isKindOf [_weapon, configFile >> "CfgWeapons"])) exitWith {
        _unit addMagazine _weapon;
    };

    _unit addMagazines [_magazine, GG_var_magazineCount];
    _unit addWeaponGlobal _weapon;
    private _muzzle = currentMuzzle _unit;
    _unit selectWeapon [_weapon, _muzzle, _fireMode];

    // keep the zeroing of the previous weapon as far as the new one allows
    private _newZeroing = _zeroing;

    while {!(_unit setWeaponZeroing [_weapon, _muzzle, _newZeroing]) && {_newZeroing > 0}} do {
        _newZeroing = _newZeroing - 1;
    };

    _newZeroing = _zeroing;

    while {!(_unit setWeaponZeroing [_weapon, _muzzle, _newZeroing]) && {_newZeroing < 7}} do {
        _newZeroing = _newZeroing + 1;
    };

    if (_optic != "") then {
        if (_weapon isKindOf ["Pistol", configFile >> "CfgWeapons"]) then {
            _unit addHandgunItem _optic;
        } else {
            _unit addPrimaryWeaponItem _optic;
        };
    };

    if (_unit isEqualTo player) then {
        call CMN_fnc_restoreNightVision;
    };
};

// "Take" (client): picked up magazines are re-added, which keeps them out of the inventory screen
GG_fnc_take = {
    params ["", "", "_item"];

    if (_item isKindOf [_item, configFile >> "CfgMagazines"]) then {
        player removeMagazine _item;
        player addMagazine _item;
    };
};

/*
    "FiredMan" (players: client, AI: server, GG_fnc_initAiUnit): endless ammo - a thrown grenade is replaced at once,
    a spare magazine is added when the last one gets loaded. The first shot ends the spawn protection.
*/
GG_fnc_firedMan = {
    params ["_unit", "_weapon", "", "", "", "_magazine"];

    if (!local _unit) exitWith {};

    [_unit] call GG_fnc_endSpawnProtection;

    if (_weapon == "Throw") exitWith {
        _unit addMagazine _magazine;
    };

    if (!(_magazine in magazines _unit)) then {
        _unit addMagazine _magazine;
    };
};

// ---- spawn protection (on the unit's machine) ----

// no damage until GG_var_spawnProtectionTime has passed or the unit fires
GG_fnc_startSpawnProtection = {
    params ["_unit"];

    _unit setVariable ["GG_var_spawnProtected", true];
    [_unit, false] call ADG_fnc_allowDamage;

    [_unit] spawn {
        params ["_unit"];

        sleep GG_var_spawnProtectionTime;
        [_unit] call GG_fnc_endSpawnProtection;
    };
};

GG_fnc_endSpawnProtection = {
    params ["_unit"];

    // a unit that changed hands meanwhile (AI taken over by a player) is protected by its new machine
    if (!local _unit || {!(_unit getVariable ["GG_var_spawnProtected", false])}) exitWith {};

    _unit setVariable ["GG_var_spawnProtected", false];

    if (!alive _unit) exitWith {};

    [_unit, true] call ADG_fnc_allowDamage;

    if (_unit isEqualTo player) then {
        ["spawnProtectionDisabled"] call BIS_fnc_showNotification;
    };
};
