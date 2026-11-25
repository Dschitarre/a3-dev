// Magazine repack (client): a "REPACK MAGAZINES" button in the vanilla inventory (display 602) with a progress bar.
// The repack moves the rounds step by step (each step fills one magazine, MR_var_secondsPerRound per round) and writes
// every step when it is done, so closing the inventory or pressing the button again stops it and keeps what is done.

MR_var_buttonWidth = 11;        // grid cells: room for "REPACK MAGAZINES" in the vanilla button font
MR_var_textSize = 0.8;          // grid cells: the bar text, as the vanilla side info
MR_var_refreshInterval = 0.25;  // seconds between two checks whether something can be repacked (inventory open)

MR_var_clientRunning = false;
MR_var_watchScript = scriptNull;
MR_var_ehUnit = objNull;        // the unit with the InventoryOpened handler
// the inventory with the button and the controls ([bar background, bar, bar text, button]) are kept in uiNamespace
// (MR_var_display, MR_var_controls): UI elements can't be serialized with the mission namespace (savegames, the error
// "Variable 'mr_var_display' does not support serialization")
uiNamespace setVariable ["MR_var_display", displayNull];
MR_var_uiUnit = objNull;        // whose inventory it is
uiNamespace setVariable ["MR_var_controls", []];
MR_var_frameEhId = -1;          // EachFrame handler while the inventory is open
MR_var_nextRefresh = 0;
MR_var_repacking = false;
MR_var_repackUnit = objNull;
MR_var_step = [];               // [type, slots before, slots after, rounds, start time, end time] of the running step
MR_var_lastType = "";           // type of the last step: the repack stays with it until it is done
MR_var_roundsDone = 0;          // rounds moved by this repack (progress bar)
MR_var_roundsTotal = 0;
MR_var_typeStepsDone = createHashMap;   // type -> steps done by this repack (bar text)

// ---- inventory handler on the controlled unit ----

// the unit remote controlled by Zeus while remote controlling, else the player
MR_fnc_controlledUnit = {
    private _remoteControlled = missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", objNull];

    [_remoteControlled, player] select (isNull _remoteControlled)
};

// Keeps the InventoryOpened handler on the controlled unit (respawn, team switch, Zeus); unscheduled. A respawned unit
// gets copies of its predecessor's handlers: only the handler added last (MR_var_inventoryEhId) acts, copies remove
// themselves.
MR_fnc_syncInventoryHandler = {
    private _unit = [objNull, call MR_fnc_controlledUnit] select MR_var_clientRunning;

    if (_unit isEqualTo MR_var_ehUnit) exitWith {};

    if (!isNull MR_var_ehUnit) then {
        MR_var_ehUnit removeEventHandler ["InventoryOpened", MR_var_ehUnit getVariable ["MR_var_inventoryEhId", -1]];
        MR_var_ehUnit setVariable ["MR_var_inventoryEhId", nil];
    };

    MR_var_ehUnit = _unit;

    if (isNull _unit) exitWith {};

    _unit setVariable ["MR_var_inventoryEhId", _unit addEventHandler ["InventoryOpened", {
        params ["_unit"];

        if ((_unit getVariable ["MR_var_inventoryEhId", -1]) != _thisEventHandler) exitWith {
            _unit removeEventHandler ["InventoryOpened", _thisEventHandler];
            false
        };

        [_unit] spawn MR_fnc_waitForInventory;
        false
    }]];
};

MR_fnc_watchLoop = {
    while {MR_var_clientRunning} do {
        isNil {call MR_fnc_syncInventoryHandler};
        sleep 1;
    };
};

// the handler fires before the display exists; it never comes if another handler blocked the inventory
MR_fnc_waitForInventory = {
    params ["_unit"];

    private _timeout = diag_tickTime + 5;

    waitUntil {!isNull findDisplay 602 || {diag_tickTime > _timeout}};

    isNil {[_unit, findDisplay 602] call MR_fnc_openInventoryUi};
};

// ---- controls ----

/*
    The button sits right-aligned below the player's half of the inventory (CA_PlayerBackground, idc 1002), 0.1 cells
    below it like a vanilla button row: inside the panel there is no free spot (the total load bar fills its bottom).
    The progress bar goes above the button, as wide as the panel (room for long magazine names), when the screen has
    room below the inventory for both (the 40 x 25 grid ends one cell below the panel, smaller interface sizes leave
    more room), else left of the button in its row.
    Vanilla classes only (missions that integrate the mod have no config of it): RscButtonMenu (PuristaLight, upper
    case, vanilla button colors), RscProgress (bar color = the player's GUI accent GUI_BCG_RGB_*), RscTextNoShadow
    (RscText centered).
*/
MR_fnc_createControls = {
    params ["_display"];

    private _gridWidth = (safeZoneW / safeZoneH) min 1.2;
    private _cellW = _gridWidth / 40;
    private _cellH = _gridWidth / 1.2 / 25;
    private _panel = _display displayCtrl 1002;
    private _panelPos = if (isNull _panel) then {
        // its vanilla position (\a3\ui_f config, RscDisplayInventory)
        [
            safeZoneX + (safeZoneW - _gridWidth) / 2 + 14.6 * _cellW,
            safeZoneY + (safeZoneH - _gridWidth / 1.2) / 2 + 2 * _cellH,
            24.4 * _cellW,
            22 * _cellH
        ]
    } else {
        ctrlPosition _panel
    };

    _panelPos params ["_panelX", "_panelY", "_panelW", "_panelH"];

    private _gap = 0.1 * _cellH;
    private _rowH = _cellH;
    private _buttonW = MR_var_buttonWidth * _cellW;
    private _buttonX = _panelX + _panelW - _buttonW;
    private _top = _panelY + _panelH + _gap;
    private _screenBottom = safeZoneY + safeZoneH;
    private _stacked = (_top + 2 * _rowH + _gap) <= _screenBottom;
    private _buttonY = if (_stacked) then {_top + _rowH + _gap} else {_top min (_screenBottom - _rowH)};
    private _barPos = if (_stacked) then {
        [_panelX, _top, _panelW, _rowH]
    } else {
        [_panelX, _buttonY, _panelW - _buttonW - _gap, _rowH]
    };

    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7];   // as dark as the inventory's own panels

    private _bar = _display ctrlCreate ["RscProgress", -1];

    private _text = _display ctrlCreate ["RscTextNoShadow", -1];
    _text ctrlSetFontHeight (MR_var_textSize * _cellH);

    {
        _x ctrlSetPosition _barPos;
        _x ctrlShow false;
        _x ctrlCommit 0;
    } forEach [_background, _bar, _text];

    private _button = _display ctrlCreate ["RscButtonMenu", -1];
    _button ctrlSetText "REPACK MAGAZINES";
    _button ctrlSetTooltip "Repacks your partly filled magazines (uniform, vest, backpack and the loaded ones) into full ones. Press again or close the inventory to stop.";
    _button ctrlSetPosition [_buttonX, _buttonY, _buttonW, _rowH];
    _button ctrlCommit 0;
    _button ctrlAddEventHandler ["ButtonClick", {call MR_fnc_toggleRepack}];

    [_background, _bar, _text, _button]
};

MR_fnc_openInventoryUi = {
    params ["_unit", "_display"];

    if (!MR_var_clientRunning || {isNull _display} || {_display isEqualTo (uiNamespace getVariable ["MR_var_display", displayNull])}) exitWith {};

    [true] call MR_fnc_closeInventoryUi;

    uiNamespace setVariable ["MR_var_display", _display];
    MR_var_uiUnit = _unit;
    uiNamespace setVariable ["MR_var_controls", [_display] call MR_fnc_createControls];
    MR_var_frameEhId = addMissionEventHandler ["EachFrame", {call MR_fnc_eachFrame}];
    _display displayAddEventHandler ["Unload", {[false] call MR_fnc_closeInventoryUi}];

    call MR_fnc_refreshButton;
};

// The inventory closed or the mod stopped: a running step is dropped, the steps done stay. _deleteControls: false
// when the display closes (it deletes them itself), true when it stays open (mod stopped).
MR_fnc_closeInventoryUi = {
    params [["_deleteControls", true, [true]]];

    if (MR_var_repacking) then {
        call MR_fnc_stopRepack;
    };

    if (MR_var_frameEhId != -1) then {
        removeMissionEventHandler ["EachFrame", MR_var_frameEhId];
        MR_var_frameEhId = -1;
    };

    if (_deleteControls) then {
        {
            ctrlDelete _x;
        } forEach (uiNamespace getVariable ["MR_var_controls", []]);
    };

    uiNamespace setVariable ["MR_var_controls", []];
    uiNamespace setVariable ["MR_var_display", displayNull];
    MR_var_uiUnit = objNull;
};

MR_fnc_eachFrame = {
    if (isNull (uiNamespace getVariable ["MR_var_display", displayNull])) exitWith {
        [true] call MR_fnc_closeInventoryUi;
    };

    if (MR_var_repacking) exitWith {
        if (!MR_var_enabled) exitWith {
            call MR_fnc_stopRepack;
        };

        if (time >= (MR_var_step select 5)) then {
            call MR_fnc_finishStep;
        };

        if (MR_var_repacking) then {
            call MR_fnc_showProgress;
        };
    };

    if (time >= MR_var_nextRefresh) then {
        call MR_fnc_refreshButton;
    };
};

// enabled while something can be repacked; hidden while the mod is paused (MR_var_enabled)
MR_fnc_refreshButton = {
    MR_var_nextRefresh = time + MR_var_refreshInterval;

    private _button = (uiNamespace getVariable ["MR_var_controls", []]) select 3;

    _button ctrlShow MR_var_enabled;
    _button ctrlEnable (MR_var_enabled && {[MR_var_uiUnit] call MR_fnc_canRepack});
};

// at least two partly filled magazines of one type, the loaded ones included (one of them not loaded)
MR_fnc_canRepack = {
    params ["_unit"];

    if (!alive _unit || {!local _unit}) exitWith {false};

    private _magazines = [_unit] call MR_fnc_readMagazines;

    ((keys _magazines) findIf {([_magazines get _x, [_x] call MR_fnc_capacity] call MR_fnc_nextStep) isNotEqualTo []}) != -1
};

// ---- repack ----

MR_fnc_toggleRepack = {
    if (MR_var_repacking) exitWith {
        call MR_fnc_stopRepack;
    };

    if (!MR_var_enabled || {!([MR_var_uiUnit] call MR_fnc_canRepack)}) exitWith {};

    MR_var_repacking = true;
    MR_var_repackUnit = MR_var_uiUnit;
    MR_var_lastType = "";
    MR_var_roundsDone = 0;
    MR_var_typeStepsDone = createHashMap;

    {
        _x ctrlShow true;
    } forEach ((uiNamespace getVariable ["MR_var_controls", []]) select [0, 3]);

    call MR_fnc_beginStep;
};

MR_fnc_stopRepack = {
    MR_var_repacking = false;
    MR_var_step = [];
    MR_var_nextRefresh = 0;   // the button state right away

    {
        _x ctrlShow false;
    } forEach ((uiNamespace getVariable ["MR_var_controls", []]) select [0, 3]);
};

// Plans the next step from the magazines as they are now (they may have changed since the last step), staying with
// the type of the last step; ends the repack when nothing is left. The last step of a type also gives the weapon a
// full magazine (MR_fnc_swapLoaded).
MR_fnc_beginStep = {
    private _unit = MR_var_repackUnit;

    if (!MR_var_enabled || {!alive _unit} || {!local _unit}) exitWith {
        call MR_fnc_stopRepack;
    };

    private _magazines = [_unit] call MR_fnc_readMagazines;
    private _types = keys _magazines;
    private _lastIndex = _types find MR_var_lastType;

    if (_lastIndex > 0) then {
        _types deleteAt _lastIndex;
        _types = [MR_var_lastType] + _types;
    };

    private _next = [];   // [type, slots, capacity, step, steps left]
    private _roundsLeft = 0;

    {
        private _slots = _magazines get _x;
        private _capacity = [_x] call MR_fnc_capacity;
        private _step = [_slots, _capacity] call MR_fnc_nextStep;

        if (_step isNotEqualTo []) then {
            ([_slots, _capacity] call MR_fnc_countSteps) params ["_steps", "_rounds"];

            _roundsLeft = _roundsLeft + _rounds;

            if (_next isEqualTo []) then {
                _next = [_x, _slots, _capacity, _step, _steps];
            };
        };
    } forEach _types;

    if (_next isEqualTo []) exitWith {
        call MR_fnc_stopRepack;
    };

    _next params ["_type", "_slots", "_capacity", "_step", "_steps"];

    private _newSlots = [_slots, _step] call MR_fnc_applyStep;

    if (([_newSlots, _capacity] call MR_fnc_nextStep) isEqualTo []) then {
        _newSlots = [_newSlots, _capacity] call MR_fnc_swapLoaded;
    };

    private _rounds = _step select 2;
    private _stepsDone = MR_var_typeStepsDone getOrDefault [_type, 0];

    MR_var_lastType = _type;
    MR_var_roundsTotal = MR_var_roundsDone + _roundsLeft;
    MR_var_step = [_type, _slots, _newSlots, _rounds, time, time + _rounds * MR_var_secondsPerRound];

    ((uiNamespace getVariable ["MR_var_controls", []]) select 2) ctrlSetText format [
        "%1: %2/%3",
        getText (configFile >> "CfgMagazines" >> _type >> "displayName"),
        _stepsDone + 1,
        _stepsDone + _steps
    ];

    call MR_fnc_showProgress;
};

// writes the finished step; if the magazines changed meanwhile nothing is written and the step is planned anew
MR_fnc_finishStep = {
    MR_var_step params ["_type", "_slots", "_newSlots", "_rounds"];

    if ([MR_var_repackUnit, _type, _slots, _newSlots] call MR_fnc_writeMagazines) then {
        MR_var_roundsDone = MR_var_roundsDone + _rounds;
        MR_var_typeStepsDone set [_type, (MR_var_typeStepsDone getOrDefault [_type, 0]) + 1];
    };

    call MR_fnc_beginStep;
};

// the bar shows the rounds moved of all types, the running step by its time
MR_fnc_showProgress = {
    MR_var_step params ["", "", "", "_rounds", "_start", "_end"];

    private _share = if (_end > _start) then {((time - _start) / (_end - _start)) min 1} else {1};

    ((uiNamespace getVariable ["MR_var_controls", []]) select 1) progressSetPosition ((MR_var_roundsDone + _rounds * _share) / (MR_var_roundsTotal max 1));
};

// ---- start / stop ----

MR_fnc_startMagRepackClient = {
    if (MR_var_clientRunning) exitWith {};

    MR_var_clientRunning = true;
    MR_var_watchScript = [] spawn MR_fnc_watchLoop;
};

MR_fnc_stopMagRepackClient = {
    if (!MR_var_clientRunning) exitWith {};

    MR_var_clientRunning = false;
    terminate MR_var_watchScript;
    call MR_fnc_syncInventoryHandler;
    [true] call MR_fnc_closeInventoryUi;
};

MR_var_clientInitDone = true;
