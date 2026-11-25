// Shooting training (singleplayer): arsenal, then stages of passive enemy groups walking past the player, who is held
// at the stage's sight position. Editor objects per stage in mission.sqm: <stage>Start, <stage>End, <stage>SightPos.

// [stage name, group size] per stage, in order
TR_var_stages = [
["stage1_1", 5],
["stage1_2", 2],
["stage1_3", 4],
["stage2_1", 5],
["stage2_2", 5],
["stage2_3", 5]
];

TR_var_targetDisabledAi = ["TARGET", "AUTOTARGET", "AIMINGERROR", "SUPPRESSION", "AUTOCOMBAT"];
TR_var_stageTimeout = 120; // seconds; a stage ends anyway when a target got stuck

// ---- init ----

// scheduled (init.sqf)
TR_fnc_init = {
    if (missionNamespace getVariable ["E_cba_enabled", true]) then {
        call E_fnc_startEarplugsServer;
    };
    if (missionNamespace getVariable ["DTV_cba_enabled", true]) then {
        call DTV_fnc_startDisableTacticalViewServer;
    };

    enableSentences false;

    player allowDamage false;
    player enableFatigue false;
    player enableStamina false;
    player setCustomAimCoef 0.35;

    TR_var_killScore = 0;

    0 setOvercast 0;
    0 setFog 0.04;
    0 setRain 0;
    setDate [2035, 6, 3, 18, 25];
    forceWeatherChange;

    sleep 0.1;
    ["Open", true] call BIS_fnc_arsenal;
    sleep 1;

    player addEventHandler ["HandleRating", {call TR_fnc_onKill}];

    waitUntil {isNull (uiNamespace getVariable "RSCDisplayArsenal")};

    player addEventHandler ["Fired", {_this call TR_fnc_refillAmmo}];

    TR_var_holdPos = getPos player;
    (["ScoreDisplay"] call BIS_fnc_rscLayer) cutRsc ["ScoreDisplay", "PLAIN", 0, true];

    [] spawn TR_fnc_runStages;
    [] spawn TR_fnc_holdPositionLoop;
};

/*
"Fired": infinite ammo - the fired muzzle's magazine is filled up to its own capacity (CfgMagazines count), so every
weapon works (handgun, launcher, grenade launcher muzzle); a thrown grenade or placed charge is replaced.
*/
TR_fnc_refillAmmo = {
    params ["_unit", "_weapon", "_muzzle", "", "", "_magazine"];

    if (_weapon in ["Throw", "Put"]) exitWith {
        _unit addMagazine _magazine;
    };

    _unit setAmmo [_muzzle, getNumber (configFile >> "CfgMagazines" >> _magazine >> "count")];
};

// keeps the player at TR_var_holdPos; teleports only when he actually moved
TR_fnc_holdPositionLoop = {
    waitUntil {
        if (player distance2D TR_var_holdPos > 0.1) then {
            player setPos TR_var_holdPos;
        };

        false
    };
};

// ---- score ----

// "HandleRating": fires when the player kills a target; returns nothing, so the rating itself is unchanged
TR_fnc_onKill = {
    playSound ["kill", false];
    TR_var_killScore = TR_var_killScore + 1;
    ((uiNamespace getVariable "ScoreDisplay") displayCtrl 1100) ctrlSetText format ["Score: %1", TR_var_killScore];
};

// ---- stages ----

TR_fnc_runStages = {
    {
        _x call TR_fnc_runStage;
        sleep 1;
    } forEach TR_var_stages;

    ["end1", true, true] call BIS_fnc_endMission;
};

// countdown, then a passive group walks from <stage>Start to <stage>End with random sidesteps
TR_fnc_runStage = {
    params ["_stageName", "_groupSize"];

    private _spawnPos = getPos (missionNamespace getVariable (_stageName + "Start"));
    private _targetPos = getPos (missionNamespace getVariable (_stageName + "End"));
    private _sightObject = missionNamespace getVariable (_stageName + "SightPos");

    TR_var_holdPos = getPos _sightObject;
    player setDir getDir _sightObject;

    {
        // bold vanilla GUI font (GUI_FONT_BOLD)
        [[[_x, "<t align='center' shadow='1' size='0.7' font='RobotoCondensedBold'>%1</t>"]]] spawn BIS_fnc_typeText;

        if (_x != "0") then {
            sleep 1;
        };
    } forEach ["3", "2", "1", "0"];

    private _group = [_spawnPos, east, _groupSize] call BIS_fnc_spawnGroup;
    _group setBehaviour "CARELESS";
    _group setCombatMode "BLUE";
    _group deleteGroupWhenEmpty true;

    private _targets = units _group;

    {
        private _target = _x;

        _target setSkill 0;
        _target setSkill ["spotDistance", 0];
        _target setSkill ["courage", 1];

        {
            _target disableAI _x;
        } forEach TR_var_targetDisabledAi;

        [_target] join grpNull;
        (group _target) deleteGroupWhenEmpty true;
        _target commandMove _targetPos;
    } forEach _targets;

    private _stageEnd = time + TR_var_stageTimeout;

    while {time < _stageEnd && {({alive _x && {_x distance _targetPos >= 5}} count _targets) > 0}} do {
        {
            // about a quarter of the time a random sidestep, otherwise on towards the end point
            if (random [0, 0.5, 1] < 0.24) then {
                _x commandMove ([_x, 5, random [0, 180, 360]] call BIS_fnc_relPos);
            } else {
                _x commandMove _targetPos;
            };
        } forEach _targets;

        sleep 1;
    };

    call TR_fnc_cleanUpStage;
};

// targets alive or dead and their dropped weapons; their groups delete themselves once empty (deleteGroupWhenEmpty)
TR_fnc_cleanUpStage = {
    {
        deleteVehicle _x;
    } forEach ((allUnits + allDeadMen) - [player]);

    {
        deleteVehicle _x;
    } forEach (allMissionObjects "WeaponHolderSimulated");

    // leftovers, e.g. groups emptied before deleteGroupWhenEmpty was set
    {
        deleteGroup _x;
    } forEach (allGroups select {units _x isEqualTo []});
};
