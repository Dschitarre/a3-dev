// Battle Royale downed state (team modes, every machine): instead of dying a combatant goes down - the AIS revive system
// (src\shared\ais, copied to AIS\ by the build, cfg\sharedLibs.txt). A downed player crawls, downed units bleed out,
// still take zone damage and can be finished off. Team mates revive them: players with the AIS actions (stabilize,
// then revive), the AI only while no enemy is near. A team without a standing combatant is out: its downed die.
// Solo matches never load AIS: dead is dead. HUD: the public unit variables ais_unconscious, ais_stabilized and
// ais_unconscious_since (the owner's time; bleed-out after AIS_BLEEDOUT_TIME).
// AIS was written for Sector Control: the SC_* names it calls get stand-ins here, its side checks (everyone is
// independent here) are narrowed to the own team and its bleed-out camera gives way to the own view (crawling).

BR_var_aisFiles = [
    "AIS\setup.sqf",
    "AIS\core.sqf",
    "AIS\events.sqf",
    "AIS\interaction.sqf",
    "AIS\system.sqf",
    "AIS\unconscious.sqf",
    "AIS\revive.sqf",
    "AIS\transport.sqf",
    "AIS\effects.sqf",
    "AIS\bleeding.sqf",
    "AIS\damage.sqf"
];
BR_var_downedDamage = 0.8;              // overall damage of a downed unit (AIS_Damage_fnc_handleDamage goes down there)
BR_var_downedBleedOutTime = 90;         // s until a downed player bleeds out (AI: AIS varies it by the damage)
BR_var_reviveHelpRadius = 200;          // AI team mates this close come to revive ...
BR_var_reviveSafeRadius = 100;          // ... only while they know no enemy this close to them or to the downed mate ...
BR_var_reviveEnemyMaxAge = 30;          // ... seen within this many seconds
BR_var_reviveCheckInterval = 5;         // s between two searches for a helper
BR_var_teamWipeDelay = 1;               // s: the downed of a team that is out die after this
// AIS messages (SC_fnc_showNotificationIfHudIsEnabled) in short
BR_var_aisMessages = createHashMapFromArray [
    ["First you have to revive the injured.", "Revive them first"],
    ["He is not with us anymore.", "Too late"],
    ["You have been stabilized.", "You were stabilized"],
    ["This action is only allowed while carrying a primary weapon.", "Needs a primary weapon"],
    ["You are not able to carry anyone else while carrying a launcher on your back.", "Not with a launcher"]
];

BR_fnc_downedEnabled = {
    ("teamSize" call BIS_fnc_getParamValue) > 1
};

// ---- start-up (every machine: BR_fnc_initServer, BR_fnc_initClient) ----

BR_fnc_initDowned = {
    if (!(call BR_fnc_downedEnabled) || {!isNil "AIS_var_initDone"}) exitWith {};

    AIS_var_initDone = true;

    {
        call compile preprocessFileLineNumbers _x;
    } forEach BR_var_aisFiles;

    call BR_fnc_aisSettings;
    call BR_fnc_aisStandIns;
    call BR_fnc_aisOverrides;

    [] call AIS_Core_fnc_preInit;

    // set by the server's preInit; a client that starts before it arrived needs it as well
    if (isNil "ais_ace_shutDown") then {
        ais_ace_shutDown = isClass (configFile >> "CfgPatches" >> "ace_medical");
    };

    [] call AIS_Effects_fnc_preInit;
    [] spawn AIS_Core_fnc_postInit;
    [] spawn AIS_System_fnc_postInit;
};

// changes of AIS\setup.sqf
BR_fnc_aisSettings = {
    AIS_REVIVE_INIT_UNITS = "allPlayers";   // players only: the AI gets AIS at the roster lock (BR_fnc_initDownedAi)
    AIS_MEDICAL_EDUCATION = 0;              // every team mate may revive (the team check: BR_fnc_aisOverrides)
    AIS_BLEEDOUT_TIME = BR_var_downedBleedOutTime;
    AIS_TOGGLE_RADIO = false;
};

// the Sector Control names AIS calls
BR_fnc_aisStandIns = {
    SC_var_launcherAmmos = createHashMap;   // AIS_Damage_fnc_handleDamage: SC's extra damage factor for vehicle crews ...
    SC_var_vehicleDamageFactor = 1;         // ... is not used here

    SC_fnc_showNotificationIfHudIsEnabled = {
        params ["_template", ["_arguments", []]];

        private _text = switch (_template) do {
            case "medicSystem": {_arguments param [0, ""]};
            case "bledOut": {"You bled out"};
            case "finallyKilled": {"You were finished off"};
            default {""};
        };

        _text = BR_var_aisMessages getOrDefault [_text, _text];

        if (_text != "") then {
            ["brInfo", [_text]] call BIS_fnc_showNotification;
        };
    };

    // SC's revive rewards (XP, revive counters, mid feed line): none here
    SC_fnc_addXp = {};
    SC_fnc_midFeedHeal = {};
    SC_fnc_addRevive = {};
    SC_fnc_addRevived = {};
};

BR_fnc_aisOverrides = {
    // the player's actions: AIS checks the side (everyone is independent here), the team counts
    BR_fnc_aisAllowReviveBase = AIS_System_fnc_allowRevive;
    BR_fnc_aisAllowStabilizeBase = AIS_System_fnc_allowStabilize;
    BR_fnc_aisAllowDragBase = AIS_System_fnc_allowDrag;

    AIS_System_fnc_allowRevive = {
        [player, _this] call BR_fnc_isTeammate && {_this call BR_fnc_aisAllowReviveBase}
    };
    AIS_System_fnc_allowStabilize = {
        [player, _this] call BR_fnc_isTeammate && {_this call BR_fnc_aisAllowStabilizeBase}
    };
    AIS_System_fnc_allowDrag = {
        [player, _this] call BR_fnc_isTeammate && {_this call BR_fnc_aisAllowDragBase}
    };

    // help from AI team mates: the server picks the helper (BR_fnc_findReviveHelper); AIS left out renegades (everyone)
    AIS_System_fnc_callHelp = {
        params ["_unit"];

        if (!isNull (_unit getVariable ["ais_hasHelper", objNull])) exitWith {false};
        if ((_unit getVariable ["callHelpDelay", 0]) > diag_tickTime) exitWith {false};

        _unit setVariable ["callHelpDelay", diag_tickTime + BR_var_reviveCheckInterval];
        [_unit] remoteExecCall ["BR_fnc_findReviveHelper", 2];
        true
    };
    AIS_System_fnc_findAIHelper = {
        params ["_injured"];

        [_injured] remoteExecCall ["BR_fnc_findReviveHelper", 2];
    };

    // a downed AI keeps asking (AIS asked once): a helper may get free or the fight end
    AIS_System_fnc_AIselfCheck = {
        params ["_injured"];

        if (!alive _injured || {!(_injured getVariable ["ais_unconscious", false])}) exitWith {};

        [_injured] remoteExecCall ["BR_fnc_findReviveHelper", 2];

        if ((_injured getVariable ["BR_var_reviveCheckAt", 0]) > diag_tickTime) exitWith {};

        private _next = diag_tickTime + BR_var_reviveCheckInterval;

        _injured setVariable ["BR_var_reviveCheckAt", _next];
        [
            {diag_tickTime > (_this select 1)},
            {[_this select 0] call AIS_System_fnc_AIselfCheck},
            [_injured, _next]
        ] call AIS_Core_fnc_waitUntilAndExecute;
    };

    // an AI helper on its way gives up when an enemy shows up (it fights, BR's AI); the downed mate asks again later
    BR_fnc_aisMoveAIHelperBase = AIS_System_fnc_moveAIHelper;
    AIS_System_fnc_moveAIHelper = {
        params ["_injured", "_helper"];

        if (alive _helper && {alive _injured} && {!([_helper, _injured] call BR_fnc_reviveSafe)}) exitWith {
            _helper setVariable ["AIS_isHelper", objNull, true];
            _injured setVariable ["AIS_plannedHelper", objNull, true];
            _helper enableAI "AUTOCOMBAT";
        };

        _this call BR_fnc_aisMoveAIHelperBase;
    };

    // an AI reviving: BR's AI leaves it alone meanwhile (BR_fnc_aiReviveBusy)
    BR_fnc_aisReviveAIBase = AIS_System_fnc_ReviveAI;
    AIS_System_fnc_ReviveAI = {
        params ["_healer"];

        _healer setVariable ["BR_var_reviving", true];
        _this call BR_fnc_aisReviveAIBase;
        _healer setVariable ["BR_var_reviving", false];
    };

    // the bleed-out view: the own view (the player crawls) with the AIS HUD, without SC's camera and map
    AIS_Effects_fnc_startUnconsciousView = {
        params ["_unit"];

        if (!AIS_SHOW_COUNTDOWN || {!scriptDone AIS_var_unconsciousHudScript}) exitWith {};

        AIS_var_unconsciousHudScript = [_unit] spawn AIS_Effects_fnc_unconsciousHud;
    };

    // who downed the unit (AIS forgets it for players) and the team check go to the server
    BR_fnc_aisSetUnconsciousBase = AIS_System_fnc_setUnconscious;
    AIS_System_fnc_setUnconscious = {
        params ["_unit"];

        private _downedBy = _unit getVariable ["AIS_downedBy", [objNull, objNull]];

        _this call BR_fnc_aisSetUnconsciousBase;
        [_unit, _downedBy] remoteExecCall ["BR_fnc_unitDowned", 2];
    };
};

// server, at the roster lock: an AI combatant goes down instead of dying
BR_fnc_initDownedAi = {
    params ["_unit"];

    if (isNil "AIS_var_initDone" || {!local _unit} || {isPlayer _unit}) exitWith {};

    [_unit] call AIS_Core_fnc_aisInitHost;
};

// ---- going down and dying (where the unit is local) ----

// what AIS_Damage_fnc_handleDamage does when a unit goes down, for scripted damage (zone)
BR_fnc_knockDown = {
    params ["_unit", ["_source", objNull], ["_instigator", objNull]];

    if (!alive _unit || {_unit getVariable ["ais_unconscious", false]}) exitWith {};

    _unit setVariable ["ais_protector_delay", diag_frameNo + 5];
    [_unit, _source, _instigator, true] remoteExecCall ["KF_fnc_entityKilled", 2];
    _unit setVariable ["AIS_downedBy", [_source, _instigator]];
    _unit setVariable ["ais_unconscious", true, true];
    _unit setVariable ["ais_unconscious_since", time, true];
    [{[_this select 0] call AIS_System_fnc_setUnconscious}, [_unit]] call AIS_Core_fnc_onNextFrame;
};

// a downed unit dies: AIS puts the first aid kits and magazines it took away back (loot), then the kill
BR_fnc_killDowned = {
    params ["_unit", "_killer"];

    if (!alive _unit) exitWith {};

    [_unit, _killer, _killer] call AIS_Damage_fnc_goToDead;
    _unit setDamage [1, true, _killer, _killer];
};

// ---- server ----

/*
    A combatant went down (AIS_System_fnc_setUnconscious on its owner). Who downed it gets the kill if it dies downed
    (BR_fnc_entityKilled). A team without a standing combatant is out: after BR_var_teamWipeDelay its downed die - unless
    one of them got up meanwhile.
*/
BR_fnc_unitDowned = {
    params ["_unit", "_downedBy"];

    if (!alive _unit || {!(_unit getVariable ["BR_var_inMatch", false])}) exitWith {};

    _downedBy params [["_source", objNull], ["_instigator", objNull]];

    private _knocker = [_instigator, _source] select (isNull _instigator);

    if (!isNull _knocker && {!(_knocker isKindOf "CAManBase")}) then {
        _knocker = effectiveCommander _knocker;
    };

    _unit setVariable ["BR_var_downedBy", _knocker];

    private _teamId = _unit getVariable ["BR_var_teamId", -1];

    if ([_teamId, _unit] call BR_fnc_teamStands) exitWith {};

    [_teamId] spawn {
        params ["_teamId"];

        sleep BR_var_teamWipeDelay;

        if ([_teamId, objNull] call BR_fnc_teamStands) exitWith {};

        {
            if (alive _x) then {
                [_x, _x getVariable ["BR_var_downedBy", objNull]] remoteExecCall ["BR_fnc_killDowned", _x];
            };
        } forEach ([_teamId] call BR_fnc_teamUnits);
    };
};

// a combatant of the team (other than _except) is alive and not down
BR_fnc_teamStands = {
    params ["_teamId", "_except"];

    (([_teamId] call BR_fnc_teamUnits) findIf {
        _x isNotEqualTo _except && {alive _x} && {!(_x getVariable ["ais_unconscious", false])}
    }) != -1
};

// the nearest AI team mate that is free and safe goes to revive the downed unit (AIS_System_fnc_moveAIHelper)
BR_fnc_findReviveHelper = {
    params ["_injured"];

    if (
        !alive _injured ||
        {!(_injured getVariable ["ais_unconscious", false])} ||
        {!isNull (_injured getVariable ["ais_hasHelper", objNull])}
    ) exitWith {};

    private _planned = _injured getVariable ["AIS_plannedHelper", objNull];

    if (alive _planned && {(_planned getVariable ["AIS_isHelper", objNull]) isEqualTo _injured}) exitWith {};

    private _helpers = ([_injured getVariable ["BR_var_teamId", -1]] call BR_fnc_teamUnits) select {
        alive _x &&
        {!isPlayer _x} &&
        {local _x} &&
        {isNull objectParent _x} &&
        {!(_x getVariable ["ais_unconscious", false])} &&
        {isNull (_x getVariable ["AIS_isHelper", objNull])} &&
        {!(_x getVariable ["BR_var_reviving", false])} &&
        {!((_x getVariable ["BR_var_aiState", ""]) in ["aboard", "falling"])} &&
        {_x distance2D _injured < BR_var_reviveHelpRadius}
    };

    _helpers = _helpers select {[_x, _injured] call BR_fnc_reviveSafe};

    if (_helpers isEqualTo []) exitWith {};

    private _distances = _helpers apply {_x distance2D _injured};
    private _helper = _helpers select (_distances find (selectMin _distances));

    _helper setVariable ["AIS_isHelper", _injured, true];
    _injured setVariable ["AIS_plannedHelper", _helper, true];
    [_injured, _helper] call AIS_System_fnc_moveAIHelper;
};

// the downed mate lies inside the current circle and the helper knows no standing enemy near itself or the mate (all
// are renegades: for the engine the own team are enemies as well)
BR_fnc_reviveSafe = {
    params ["_helper", "_injured"];

    if ([_injured] call BR_fnc_aiOutsideZone) exitWith {false};

    ([getPosATL _helper, getPosATL _injured] findIf {
        private _center = _x;

        ((_helper targets [true, BR_var_reviveSafeRadius, [], BR_var_reviveEnemyMaxAge, _center]) findIf {
            alive _x && {!([_x, _helper] call BR_fnc_isTeammate)} && {!(_x getVariable ["ais_unconscious", false])}
        }) != -1
    }) == -1
};
