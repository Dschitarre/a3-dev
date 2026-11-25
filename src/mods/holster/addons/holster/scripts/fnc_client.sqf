// Holster (client): the H key holsters the current weapon and takes it out again. Acts on the unit the player
// controls (the unit remote controlled by Zeus while remote controlling).

H_var_running = false;
H_var_ehIds = [];                  // [KeyDown, KeyUp] handler IDs on display 46 while added
H_var_keyHeld = false;             // H is down: the key repeats while held, only the first press acts
H_var_holstered = [objNull, ""];   // [unit, weapon] holstered last; another unit (respawn) starts without
H_var_holsterCheckDelay = 0.3;     // seconds after which a weapon still in the hands is put away by switching the move
H_var_movingSpeed = 2;             // km/h from which the unit counts as moving (the normal switch is ignored then)

H_fnc_controlledUnit = {
    private _remoteControlled = missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", objNull];

    [_remoteControlled, player] select (isNull _remoteControlled)
};

// stance "UNDEFINED": swimming, diving, on a ladder, ...
H_fnc_canHolster = {
    params ["_unit"];

    alive _unit &&
    {isNull objectParent _unit} &&
    {!(lifeState _unit in ["INCAPACITATED", "UNCONSCIOUS"])} &&
    {!(_unit getVariable ["ais_unconscious", false])} &&
    {stance _unit != "UNDEFINED"}
};

H_fnc_keyDown = {
    params ["", "_key", "", "_ctrl", "_alt"];

    // DIK_H without Ctrl / Alt; with Shift too, which is held while sprinting
    if (_key != 35 || {_ctrl || _alt}) exitWith {};

    if (H_var_keyHeld) exitWith {};

    H_var_keyHeld = true;

    private _unit = call H_fnc_controlledUnit;

    if !([_unit] call H_fnc_canHolster) exitWith {};

    private _currentWeapon = currentWeapon _unit;

    // take out the weapon holstered last, else the first one the unit has: primary, handgun, launcher
    if (_currentWeapon == "") exitWith {
        private _weapons = [primaryWeapon _unit, handgunWeapon _unit, secondaryWeapon _unit] select {_x != ""};
        H_var_holstered params ["_holsterUnit", "_weapon"];

        if (_holsterUnit isNotEqualTo _unit || {!(_weapon in _weapons)}) then {
            _weapon = _weapons param [0, ""];
        };

        if (_weapon != "") then {
            _unit selectWeapon _weapon;
            [_unit, _weapon] spawn H_fnc_drawWhileMoving;
        };

        H_var_holstered = [objNull, ""];
    };

    // the launcher can only be holstered while standing still
    if (_currentWeapon != secondaryWeapon _unit || {speed _unit == 0}) then {
        H_var_holstered = [_unit, _currentWeapon];
        _unit action ["SwitchWeapon", _unit, _unit, 100];
        [_unit, _currentWeapon] spawn H_fnc_holsterWhileMoving;
    };
};

// a moving unit ignores the switch above (there is no move from running with a weapon to running without one): then
// it switches to the same move without a weapon, which puts the weapon on the back at once. Without resetting the aim
// (switchMove [move, start, blend, reset aim]), so the view doesn't jump; switchMove has a local effect.
H_fnc_holsterWhileMoving = {
    params ["_unit", "_weapon"];

    sleep H_var_holsterCheckDelay;

    // standing still the normal switch (with its animation) works
    if ((currentWeapon _unit) != _weapon || {(speed _unit) < H_var_movingSpeed} || {!([_unit] call H_fnc_canHolster)}) exitWith {};

    // "amovpercmrunslowwrfldf" -> "amovpercmrunsnonwnondf"
    [_unit, "snonwnon"] call H_fnc_switchMoveWeapon;
};

// the same for taking the weapon out while moving (also sprinting): the move with the weapon, lowered while sprinting
// ("eva"), else raised; selected again, so the weapon is in the hands
H_fnc_drawWhileMoving = {
    params ["_unit", "_weapon"];

    sleep H_var_holsterCheckDelay;

    if ((currentWeapon _unit) == _weapon || {(speed _unit) < H_var_movingSpeed} || {!([_unit] call H_fnc_canHolster)}) exitWith {};

    private _weaponCode = switch (_weapon) do {
        case (primaryWeapon _unit): {"rfl"};
        case (handgunWeapon _unit): {"pst"};
        default {""};
    };

    if (_weaponCode == "") exitWith {};

    private _isSprinting = "meva" in (toLowerANSI (animationState _unit));

    if ([_unit, format ["s%1w%2", (["ras", "low"] select _isSprinting), _weaponCode]] call H_fnc_switchMoveWeapon) then {
        _unit selectWeapon _weapon;
    };
};

// switches the unit to its current move with another weapon state ("s<stance>w<weapon>" of the move name, e.g.
// "snonwnon"), without resetting the aim (switchMove [move, start, blend, reset aim]), so the view doesn't jump;
// switchMove has a local effect, so it is played everywhere. False if the game has no such move.
H_fnc_switchMoveWeapon = {
    params ["_unit", "_weaponState"];

    private _move = (toLowerANSI (animationState _unit)) regexReplace ["s[a-z]{3}w[a-z]{3}", _weaponState];

    if !(isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _move)) exitWith {false};

    private _switch = [_move, 0, 1, false];

    _unit switchMove _switch;

    if (isMultiplayer) then {
        [_unit, _switch] remoteExecCall ["switchMove", -clientOwner];
    };

    true
};

H_fnc_keyUp = {
    params ["", "_key"];

    if (_key == 35) then {
        H_var_keyHeld = false;
    };

    false
};

// Adds / removes the key handlers on display 46 to match H_var_running. Runs scheduled (waits for the display);
// the change itself runs unscheduled, so a start and a stop in quick succession cannot double or lose them.
// _reload: a loaded singleplayer savegame has a new display 46, so the handlers are added again.
H_fnc_syncKeyHandlers = {
    params [["_reload", false]];

    waitUntil {!isNull player && {!isNull findDisplay 46}};

    isNil {
        private _display = findDisplay 46;

        if (H_var_ehIds isNotEqualTo [] && {_reload || {!H_var_running}}) then {
            H_var_ehIds params ["_keyDownEhId", "_keyUpEhId"];

            _display displayRemoveEventHandler ["KeyDown", _keyDownEhId];
            _display displayRemoveEventHandler ["KeyUp", _keyUpEhId];
            H_var_ehIds = [];
        };

        if (H_var_running && {H_var_ehIds isEqualTo []}) then {
            H_var_keyHeld = false;
            H_var_ehIds = [
                _display displayAddEventHandler ["KeyDown", {_this call H_fnc_keyDown}],
                _display displayAddEventHandler ["KeyUp", {_this call H_fnc_keyUp}]
            ];
        };
    };
};

H_fnc_startHolsterClient = {
    if (H_var_running) exitWith {};

    H_var_running = true;

    if (!isMultiplayer) then {
        H_var_loadedEhId = addMissionEventHandler ["Loaded", {[true] spawn H_fnc_syncKeyHandlers}];
    };

    [] spawn H_fnc_syncKeyHandlers;
};

H_fnc_stopHolsterClient = {
    if (!H_var_running) exitWith {};

    H_var_running = false;

    if (!isMultiplayer) then {
        removeMissionEventHandler ["Loaded", H_var_loadedEhId];
        H_var_loadedEhId = nil;
    };

    [] spawn H_fnc_syncKeyHandlers;
};

H_var_clientInitDone = true;
