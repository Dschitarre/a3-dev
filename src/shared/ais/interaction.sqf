// AIS interaction: actions on injured units, interaction loop, progress bar and on-screen texts.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
Author: [C-L-F] NetFusion
Edited: Psychobastard

Description:
Add an action to an object or type(s) of object(s).

Parameter(s):
0: STRING - the title of the action.
1: OBJECT, ARRAY, STRING - the object (type) which the action should be added to.
2: NUMBER - the distance in which the action is visible.
3: STRING - the condition which is evaluated on every frame (if play is in range) to determine whether the action is visible.
4: CODE - the callback which gets called when the action is activated.
5: ARRAY - (optional) the arguments which get passed to the callback.

Remarks:
* '_target' is the object inside the condition string.
* [object, caller, ID, arguments] is _this in the callback

Returns:
-

Example:
["Hint Hello!", player, 0, "true", { hint format ["Hello %1", name player]; }] call AIS_Core_fnc_addAction;
["Hint Hello!", "Man", 3, "true", { hint format ["Hello %1", name (_this select 0)]; }] call AIS_Core_fnc_addAction;
*/
AIS_Core_fnc_addAction = {

    params ["_text", "_onObject", "_distance", "_condition", "_callback", ["_args", []], ["_formated", "", [""]]];

    if (_distance > 0) then {
        _condition = format ["([cursorTarget, %1] call AIS_Core_fnc_inRange) && {%2}", _distance, _condition];
    };

    // AIS_Core_realPlayer is set by AIS_Core_fnc_aisInit (core.sqf), possibly after the first actions are added on a
    // joining client: until then the player is the real player
    if (_onObject isEqualType objNull && {_onObject isEqualTo (missionNamespace getVariable ["AIS_Core_realPlayer", player])}) exitWith {
        private _action = _onObject addAction [_text, _callback, _args, 1.5, false, true, "", _condition, _distance];

        if (_formated != "") then {
            _onObject setUserActionText [
                _action,
                _text,
                format [_formated, _text],
                ""
            ];
        };

        [
            "AIS_playerChanged", {
                params ["_data", "_params"];
                _data params ["_currentPlayer", "_oldPlayer"];
                _params params ["_text", "_callback", "_distance", ["_args", []], "_condition", ["_formated", "", [""]]];

                private _action = _currentPlayer addAction [_text, _callback, _args, 1.5, false, true, "", _condition, _distance];

                if (_formated != "") then {
                    _currentPlayer setUserActionText [
                        _action,
                        _text,
                        format [_formated, _text],
                        ""
                    ];
                };
            },
            [_text, _callback, _distance, _args, _condition, _formated]
        ] call AIS_Core_fnc_bindEventHandler;

    };

    if (!(_onObject isEqualType [])) then {
        _onObject = [_onObject];
    };

    private _actionStorage = missionNamespace getVariable ["AIS_Core_actionStorage", []];
    {
        _actionStorage pushBack [_x, _text, _distance, _condition, _callback, _args, _formated];
        nil
    } count _onObject;
    missionNamespace setVariable ["AIS_Core_actionStorage", _actionStorage]; //@todo maybe init array and remove this line
};

AIS_var_textLayer = 1014;           // cut layer of AIS_Core_fnc_dynamicText (high number: no clash with named layers)
AIS_var_textDuration = 3;           // seconds

// a short note for the player, e.g. "First you have to revive the injured.": a screen text block (ui\ui.sqf) on the
// left edge of the screen
AIS_Core_fnc_dynamicText = {
    params [["_text", "", [""]]];

    (call UI_fnc_gridCell) params ["_cellW"];

    [AIS_var_textLayer, _text, [safeZoneX + 0.5 * _cellW, safeZoneY + 0.3], AIS_var_textDuration] call UI_fnc_showTextBlocks;

    true
};

/*
Author: [C-L-F] NetFusion

Description:
Checks whether an object is in a given range to player.

Parameter(s):
0: OBJECT - the object which should be checked.
1: NUMBER - the range to check.

Returns:
- BOOL - true if the object in in range, false if not.

Example:
[object, 10] call AIS_Core_fnc_inRange;
*/
AIS_Core_fnc_inRange = {

    params [
        ["_object", objNull, [player]],
        ["_distance", 15, [0]]
    ];

    _return = if (!isNull _object && {player distance2D _object < _distance}) then {
        true
    } else {
        false
    };

    _return
};

/*
Author: NetFusion
Description:
Continuously checks whether an action should be added to the cursorTarget.
Parameter(s):
-
Remarks:
* Should only be called once per mission.

Returns:
-
Example:
-
*/
AIS_Core_fnc_interaction_loop = {

    AIS_Core_lastCursorTarget = objNull;

    [{
        _cursorTarget = cursorTarget;
        if(_cursorTarget isEqualTo AIS_Core_lastCursorTarget ||
            {player distance _cursorTarget > 15}) exitWith {};
            // psycho: prevent cycling trough cursorTargets more than 15m away (engine limitation is 15m for every action)
        AIS_Core_lastCursorTarget = _cursorTarget;

        private _objActions = _cursorTarget getVariable ["AIS_Core_actionStorage", []];
        {
            _x params ["_onObject", "_text", "_distance", "_condition", "_callback", "_args", "_formated"];

            if (!(_x in _objActions)) then {
                if((_onObject isEqualType "" && {_cursorTarget isKindOf _onObject}) ||
                    (_onObject isEqualType objNull && {_cursorTarget isEqualTo _onObject})) then {
                    private _action = _cursorTarget addAction [_text, _callback, _args, 1.5, true, true, "", _condition, _distance];
                    _objActions pushBack _x;

                    if (_formated != "") then {
                        _cursorTarget setUserActionText [
                            _action,
                            _text,
                            format [_formated, _text],
                            ""
                        ];
                    };
                };
            };
            nil
        } count (missionNamespace getVariable ["AIS_Core_actionStorage", []]);

        _cursorTarget setVariable ["AIS_Core_actionStorage", _objActions]; //@todo maybe init array and remove this line - this requires module dependencies
    }] call AIS_Core_fnc_onEachFrame;
};

/*
 * Author: NetFusion
 * modified/changed by Psycho
 * Generate progress bar dialog and pass trough the code what's to do after finish or abort the progress.
 * Arguments:
    0: Title (String)
    1: duration in sec (Integer)
    2: callback (Code)
    3: arguments for callback (Object or Array)
    4: onAbort (optional) (Code)
    5: doAbort (optional) (Bool)
 * Return value:
    nothing
*/
AIS_Core_fnc_progress_showBar = {
    private _title = _this select 0;
    _duration = _this select 1;
    _callback = _this select 2;
    _arguments = _this select 3;
    _onAbort = if (count _this > 4) then {_this select 4} else {{}};
    _doAbort = if (count _this > 5) then {_this select 5} else {false};        // added by Psycho
    _endTime = time + _duration;
    _affectingObject = if (typeName _arguments == "ARRAY") then {_arguments select 0} else {_arguments};

    if (typeName _affectingObject == "OBJECT") then {
        if (_affectingObject getVariable ["AIS_Core_Progress_inUse", false]) exitWith {
        };

        _affectingObject setVariable ["AIS_Core_Progress_inUse", true, true];
    };

    closeDialog 0;
    createDialog "AIS_Core_Progress_BarDlg";

    _texts = player getVariable ["AIS_Core_displayText", []];
    _texts pushBack ("(" + _title + ")");
    player setVariable ["AIS_Core_displayText", _texts, true];

    disableSerialization;
    _progressBar = uiNamespace getVariable "AIS_Core_Progress_ProgressBar";

    _progressBar ctrlSetPosition [safeZoneX + 0.298906 * safeZoneW, safeZoneY + 0.082 * safeZoneH, 0.407344 * safeZoneW, 0.011 * safeZoneH];
    _progressBar ctrlCommit (_duration / accTime);

    _time = time;

    while {dialog && {time < _endTime} && {alive player} && {!_doAbort}} do {
        sleep 0.5;
        [_title, ((time - _time) / (_duration)) min 1] spawn AIS_Core_fnc_progress_showBarText;
    };

    closeDialog 0;

    _texts = _texts - ["(" + _title + ")"];
    player setVariable ["AIS_Core_displayText", _texts, true];

    if (time > _endTime) then {
        _arguments spawn _callback;
    } else {
        _arguments spawn _onAbort;
    };

    if (typeName _affectingObject == "OBJECT") then {
        _affectingObject setVariable ["AIS_Core_Progress_inUse", false, true];
    };
};

// by psycho
AIS_Core_fnc_progress_showBarText = {
    private _title = _this select 0;
    _value = _this select 1;

    disableSerialization;
    private _progressTitle = uiNamespace getVariable "AIS_Core_Progress_ProgressTitle";

    _sitrepArray = toArray format [" ....%1", str (round (_value * 100)) + "%"];
    {_sitrepArray set [_foreachindex, toString [_x]]} forEach _sitrepArray;
    _sitrep = "";
    _sitrepFormat = "<t align='left' shadow='1'>" + _title + ":%1</t>";

    for "_i" from 0 to (count _sitrepArray - 1) do {
        _letter = _sitrepArray select _i;
        _delay = if (_letter == "|") then {_letter = "<br />"; 1} else {0.02};
        _sitrep = _sitrep + _letter;
        _text = parseText format [_sitrepFormat, _sitrep + "_"];

        _progressTitle ctrlSetText str(_text);
        sleep _delay;
    };
};
