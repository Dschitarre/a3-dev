// Unflip (client): the vanilla hold action "Unflip vehicle" on the player's unit, shown while the player looks at a
// flipped land vehicle or boat within reach that has no living crew. The hold takes longer the heavier the vehicle
// is; then the vehicle is turned upright where it is local (UF_fnc_unflip, fnc_clientServer.sqf).

UF_var_clientRunning = false;
UF_var_actionScript = scriptNull;  // keeps the action on the player's current unit
UF_var_actionUnit = objNull;       // unit the action is on
UF_var_actionId = -1;
UF_var_cursorVehicle = objNull;    // vehicle the action was shown for last
UF_var_holdVehicle = objNull;      // vehicle of the hold in progress
UF_var_actionTitle = "Unflip vehicle";
UF_var_actionIcon = "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\car_ca.paa";
UF_var_actionPriority = 100;       // above the vehicle's own actions (get in), so the hold shows in the screen centre

// ---- conditions ----

// the player can work on a vehicle: alive, conscious (also for the AIS revive) and on foot
UF_fnc_canPlayerAct = {
    alive player &&
    {isNull objectParent player} &&
    {!(player getVariable ["ais_unconscious", false])} &&
    {!(lifeState player in ["INCAPACITATED", "UNCONSCIOUS"])}
};

// the vehicle is within UF_var_maxDistance of the player's eyes, measured to its box (a truck or a tank on its side is
// big, its position can be metres away from the part the player stands at)
UF_fnc_inReach = {
    params ["_vehicle"];

    ([_vehicle] call UF_fnc_box) params ["_min", "_max"];

    private _eyes = _vehicle worldToModel (ASLToAGL (eyePos player));
    private _closest = [0, 1, 2] apply {((_eyes select _x) max (_min select _x)) min (_max select _x)};

    (_eyes vectorDistance _closest) <= UF_var_maxDistance
};

// the player may unflip this vehicle now; the condition while holding as well
UF_fnc_canPlayerUnflip = {
    params ["_vehicle"];

    UF_var_enabled &&
    {[_vehicle] call UF_fnc_canUnflip} &&
    {call UF_fnc_canPlayerAct} &&
    {[_vehicle] call UF_fnc_inReach}
};

// condition of the action (every frame): the vehicle under the cursor, remembered for the hold (which starts a few
// frames later, when the cursor may already be off the vehicle)
UF_fnc_canStart = {
    private _vehicle = cursorObject;

    if !([_vehicle] call UF_fnc_canPlayerUnflip) exitWith {false};

    UF_var_cursorVehicle = _vehicle;
    true
};

// ---- hold ----

// seconds of holding, linear in the mass from UF_var_durationMin (light vehicles) to UF_var_durationMax (heavy)
UF_fnc_holdDuration = {
    params ["_vehicle"];

    linearConversion [UF_var_massLight, UF_var_massHeavy, getMass _vehicle, UF_var_durationMin, UF_var_durationMax, true]
};

// start of a hold: the vehicle stays the same for the whole hold, and the hold gets the vehicle's duration.
// BIS_fnc_holdActionAdd takes one duration for all holds, but its progress script calls this start code and only then
// computes its steps from its local _duration: set here (not private, so it is the caller's), it applies to this hold.
UF_fnc_holdStarted = {
    private _vehicle = UF_var_cursorVehicle;

    if !([_vehicle] call UF_fnc_canPlayerUnflip) then {
        _vehicle = objNull;
    };

    UF_var_holdVehicle = _vehicle;

    if (!isNull _vehicle) then {
        _duration = [_vehicle] call UF_fnc_holdDuration;
    };
};

UF_fnc_holdCompleted = {
    private _vehicle = UF_var_holdVehicle;
    UF_var_holdVehicle = objNull;

    if (isNull _vehicle) exitWith {};

    [_vehicle] remoteExecCall ["UF_fnc_unflip", _vehicle];
};

// ---- action ----

UF_fnc_addAction = {
    UF_var_actionUnit = player;
    UF_var_actionId = [
        player,
        UF_var_actionTitle,
        UF_var_actionIcon,
        UF_var_actionIcon,
        "call UF_fnc_canStart",
        "[UF_var_holdVehicle] call UF_fnc_canPlayerUnflip",
        {call UF_fnc_holdStarted},
        {},
        {call UF_fnc_holdCompleted},
        {UF_var_holdVehicle = objNull},
        [],
        UF_var_durationMax,         // replaced per hold, see UF_fnc_holdStarted
        UF_var_actionPriority,
        false,                      // the action stays after a hold
        false                       // not while unconscious
    ] call BIS_fnc_holdActionAdd;
};

UF_fnc_removeAction = {
    if (UF_var_actionId != -1) then {
        [UF_var_actionUnit, UF_var_actionId] call BIS_fnc_holdActionRemove;
    };

    UF_var_actionUnit = objNull;
    UF_var_actionId = -1;
};

// keeps the action on the player's current unit: after a respawn (the action stays on the corpse), a team switch or
// selectPlayer the player has a new one. The change itself runs unscheduled, so the stop cannot come in between.
UF_fnc_actionLoop = {
    while {true} do {
        if (!isNull player && {player isNotEqualTo UF_var_actionUnit}) then {
            isNil {
                call UF_fnc_removeAction;
                call UF_fnc_addAction;
            };
        };

        sleep 1;
    };
};

// ---- start / stop ----

UF_fnc_startUnflipClient = {
    if (UF_var_clientRunning) exitWith {};

    UF_var_clientRunning = true;
    UF_var_actionScript = [] spawn UF_fnc_actionLoop;
};

// a hold in progress ends at once: its condition fails without the hold vehicle
UF_fnc_stopUnflipClient = {
    if (!UF_var_clientRunning) exitWith {};

    UF_var_clientRunning = false;
    terminate UF_var_actionScript;
    UF_var_actionScript = scriptNull;
    UF_var_holdVehicle = objNull;
    call UF_fnc_removeAction;
};

UF_var_clientInitDone = true;
