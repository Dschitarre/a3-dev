// Jump (client): while running (standing or crouched), the "step over" key (V by default) jumps instead of climbing
// over; otherwise it keeps its normal function. After the landing the unit takes its stance from before the jump again,
// switched once per press of the crouch key (X) during the jump. Acts on the unit the player controls (the unit remote
// controlled by Zeus while remote controlling).

J_var_running = false;
J_var_ehId = -1;
J_var_nextJumpTime = 0;
J_var_minSpeed = 8.5;     // km/h needed to jump
J_var_cooldown = 1.2;     // seconds between two jumps
J_var_jumpAnimation = "AovrPercMrunSrasWrflDf";
J_var_keyUpEhId = -1;
J_var_crouchPresses = -1;   // presses of the crouch key during the current jump, -1 while not jumping
J_var_crouchKeyHeld = false; // held keys repeat KeyDown: only the first one counts

J_fnc_controlledUnit = {
    private _remoteControlled = missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", objNull];

    [_remoteControlled, player] select (isNull _remoteControlled)
};

J_fnc_canJump = {
    params ["_unit"];

    time >= J_var_nextJumpTime &&
    {alive _unit} &&
    {local _unit} &&
    {stance _unit in ["STAND", "CROUCH"]} &&
    {speed _unit > J_var_minSpeed} &&
    {isNull objectParent _unit} &&
    {isTouchingGround _unit} &&
    {currentWeapon _unit in [primaryWeapon _unit, handgunWeapon _unit, ""]}
};

// after the landing (and the end of the jump animation): the stance from before the jump, switched between standing
// and crouched when the crouch key was pressed an odd number of times during the jump
J_fnc_restoreStance = {
    params ["_unit", "_crouched"];

    private _start = time;

    waitUntil {!(isTouchingGround _unit) || {time > _start + 0.5}};
    waitUntil {isTouchingGround _unit || {time > _start + 3}};

    private _crouch = _crouched isNotEqualTo ((J_var_crouchPresses % 2) == 1);
    J_var_crouchPresses = -1;

    if (!alive _unit || {!isNull objectParent _unit}) exitWith {};

    // crouch at once on landing: switching the move ends the jump animation (waiting for its end and then the normal
    // stance change took well over a second); switchMove has a local effect, so it is played everywhere. Without
    // resetting the aim / head direction (alternative syntax [move, start time, blend factor, reset aim]): the reset made
    // the first person view jump for a frame
    if (_crouch && {stance _unit != "CROUCH"}) exitWith {
        private _switch = [([_unit] call J_fnc_crouchMove), 0, 1, false];

        _unit switchMove _switch;
        _unit playActionNow "PlayerCrouch";

        if (isMultiplayer) then {
            [_unit, _switch] remoteExecCall ["switchMove", -clientOwner];
        };
    };

    if (!_crouch && {stance _unit == "CROUCH"}) then {
        _unit playActionNow "PlayerStand";
    };
};

// the crouched standing move for the unit's current weapon (rifle, pistol or none; a jump is not possible with a
// launcher)
J_fnc_crouchMove = {
    params ["_unit"];

    private _weapon = currentWeapon _unit;

    switch true do {
        case (_weapon == ""): {"AmovPknlMstpSnonWnonDnon"};
        case (_weapon == handgunWeapon _unit): {"AmovPknlMstpSrasWpstDnon"};
        default {"AmovPknlMstpSrasWrflDnon"};
    }
};

// during a jump the crouch key only counts its presses (the stance is set after the landing)
J_fnc_keyUp = {
    params ["", "_key"];

    if (_key in actionKeys "Crouch") then {
        J_var_crouchKeyHeld = false;
    };

    false
};

// consumes the key only when it jumps, so standing or walking units still climb over
J_fnc_keyDown = {
    params ["", "_key"];

    if ((J_var_crouchPresses >= 0) && {_key in actionKeys "Crouch"}) exitWith {
        if (!J_var_crouchKeyHeld) then {
            J_var_crouchKeyHeld = true;
            J_var_crouchPresses = J_var_crouchPresses + 1;
        };

        true
    };

    if !(_key in actionKeys "GetOver") exitWith {false};

    private _unit = call J_fnc_controlledUnit;

    if !([_unit] call J_fnc_canJump) exitWith {false};

    J_var_crouchPresses = 0;
    J_var_crouchKeyHeld = false;
    [_unit, (stance _unit == "CROUCH")] spawn J_fnc_restoreStance;

    private _dir = direction _unit;
    private _velocity = velocity _unit;
    _velocity set [2, 0];
    _velocity = _velocity vectorAdd ([sin _dir, cos _dir, 0] vectorMultiply (0.4 * J_var_jumpSpeed));
    _velocity = _velocity vectorMultiply (1 min ((5 * J_var_jumpSpeed) / vectorMagnitude _velocity));
    _velocity set [2, 3.5 * (J_var_jumpSpeed ^ 0.4)];
    _unit setVelocity _velocity; // local argument, global effect: no need to relay it

    // switchMove has a local effect: played here and on every other machine
    if (currentWeapon _unit != "") then {
        _unit switchMove J_var_jumpAnimation;

        if (isMultiplayer) then {
            [_unit, J_var_jumpAnimation] remoteExecCall ["switchMove", -clientOwner];
        };
    };

    J_var_nextJumpTime = time + J_var_cooldown;
    true
};

// Adds / removes the key handler on display 46 to match J_var_running. Runs scheduled (waits for the display);
// the change itself runs unscheduled, so a start and a stop in quick succession cannot double or lose it.
// _reload: a loaded singleplayer savegame has a new display 46, so the handler is added again.
J_fnc_syncKeyHandler = {
    params [["_reload", false]];

    waitUntil {!isNull player && {!isNull findDisplay 46}};

    isNil {
        private _display = findDisplay 46;

        if (J_var_ehId != -1 && {_reload || {!J_var_running}}) then {
            _display displayRemoveEventHandler ["KeyDown", J_var_ehId];
            _display displayRemoveEventHandler ["KeyUp", J_var_keyUpEhId];
            J_var_ehId = -1;
            J_var_keyUpEhId = -1;
        };

        if (J_var_running && {J_var_ehId == -1}) then {
            J_var_ehId = _display displayAddEventHandler ["KeyDown", {_this call J_fnc_keyDown}];
            J_var_keyUpEhId = _display displayAddEventHandler ["KeyUp", {_this call J_fnc_keyUp}];
        };
    };
};

J_fnc_startJumpClient = {
    if (J_var_running) exitWith {};

    J_var_running = true;

    if (!isMultiplayer) then {
        J_var_loadedEhId = addMissionEventHandler ["Loaded", {[true] spawn J_fnc_syncKeyHandler}];
    };

    [] spawn J_fnc_syncKeyHandler;
};

J_fnc_stopJumpClient = {
    if (!J_var_running) exitWith {};

    J_var_running = false;

    if (!isMultiplayer) then {
        removeMissionEventHandler ["Loaded", J_var_loadedEhId];
        J_var_loadedEhId = nil;
    };

    [] spawn J_fnc_syncKeyHandler;
};

J_var_clientInitDone = true;
