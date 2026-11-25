// AIS events: own event system, per-frame and next-frame handlers, wait-and-execute.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
Arma Mission Enhancement - Core\Events\fn_bindEventHandler.sqf

Author: NetFusion

Description:
Bind an EH for a custom event. This EH will be called when the event is triggered.

Parameter(s):
- 0: STRING - the name of the event
- 1: CODE   - the code which get called (_this select 0 will be the data, _this select 1 will be the params)
- 2: ARRAY  - the params passed to the code (optional)

Returns:
-
Example:

["playerChanged", { hint "Player has changed"; }] call AIS_Core_fnc_bindEventHandler;
*/
AIS_Core_fnc_bindEventHandler = {

    params ["_name", "_code", ["_params", []]];

    // Form the name of the EH storage
    _name = format ["AIS_Core_eventHandlersFor%1", _name];

    // Push the data on the EH array (specific by name).
    private _eventHandlers = missionNamespace getVariable [_name, []];
    _eventHandlers pushBack [_code, _params];
    missionNamespace setVariable [_name, _eventHandlers];
};

/*
Arma Mission Enhancement - Core\Events\fn_initEvents.sqf
Author: NetFusion
Changed: Psycho - expand function with "next-frame" and "waitUntil" elements

Description:
Adds a loop which call all OEF EHs. Will be called by autoload for client and server. There is no need to call it manually.

Parameter(s):
-

Returns:
-

Example:
-
*/
AIS_Core_fnc_initEvents = {

    AIS_nextFrameNo = diag_frameNo + 1;
    // PostInit can be 2 frames after preInit, need to manually set AIS_nextFrameNo, so new items get added to buffer B while processing A for the first time:
    AIS_nextFrameBufferA = [[[], {AIS_nextFrameNo = diag_frameNo;}]];
    AIS_nextFrameBufferB = [];
    AIS_waitUntilAndExecArray = [];

    AIS_Core_eachFrameHandlerId = addMissionEventHandler ["EachFrame", {

        // Execute per frame handlers
        // Fetch all OEF EHs from missionNamespace.
        private _onEachFrameHandler = missionNamespace getVariable ["AIS_Core_onEachFrameData", []];
        {
            _x params ["_code", "_delay", "_nextExecTime", "_params"];

            // If the execution time is up call the function.
            if (diag_tickTime > _nextExecTime) then {
                // Set the new execution time depending on the provided delay.
                _x set [2, _nextExecTime + _delay];

                [_forEachIndex, _params] call _code; //@todo if an EH removed itself the next EH may be skipped
            };
        } forEach _onEachFrameHandler;

        // Execute the exec next frame functions (from CBA)
        if (count AIS_nextFrameBufferA > 0) then {
            {
                (_x select 0) call (_x select 1);
                false
            } count AIS_nextFrameBufferA;
            // Swap double-buffer:
            AIS_nextFrameBufferA = AIS_nextFrameBufferB;
            AIS_nextFrameBufferB = [];
            AIS_nextFrameNo = diag_frameNo + 1;
        };

        // handle the waitUntil and execute function (from CBA)
        if (count AIS_waitUntilAndExecArray > 0) then {
            private _delete = false;
            {
                // if condition is satisfied call statement
                if ((_x select 2) call (_x select 0)) then {
                    (_x select 2) call (_x select 1);
                    AIS_waitUntilAndExecArray set [_forEachIndex, objNull];
                    _delete = true;
                };
            } forEach AIS_waitUntilAndExecArray;
            if (_delete) then {
                AIS_waitUntilAndExecArray = AIS_waitUntilAndExecArray - [objNull];
            };
        };

        // remove the pfh if client left the mission
        if (getClientState == "GAME FINISHED") then {
            removeMissionEventHandler ["EachFrame", AIS_Core_eachFrameHandlerId];
        };
    }];
};

/*
Arma Mission Enhancement - Core\Events\fn_onEachFrame.sqf

Author: NetFusion

Description:
Adds an OEF EHs. The EH will be called on each frame with a custom delay between the calls.

Parameter(s):
- 1: CODE   - the code which is called (_this select 0 will be the EH id, _this select 1 will be the params)
- 2: SCALAR - the delay between two code calls in seconds (optional)
- 3: ARRAY  - the parameters which get passed to the code on call (optional)

Returns:
-

Example:
[{ hint (str diagFrameNo); }] call AIS_Core_fnc_onEachFrame;
*/
AIS_Core_fnc_onEachFrame = {

    params [
        "_code",
        ["_delay", 0],
        ["_params", []]
    ];

    // Push the data on the OEF EH array.
    private _onEachFrameData = missionNamespace getVariable ["AIS_Core_onEachFrameData", []];
    _onEachFrameData pushBack [_code, _delay, diag_tickTime + _delay, _params];
    missionNamespace setVariable ["AIS_Core_onEachFrameData", _onEachFrameData];
};

/* ----------------------------------------------------------------------------
Function: AIS_Core_fnc_onNextFrame

Description:
Executes a code once in non sched environment on the next frame.
Parameters:

_function - The function to run. <CODE>
_args     - Parameters passed to the function executing. This will be the same array every execution. [optional] <ANY>
Returns:
Nothing

Examples:
(begin example)
    [{player sideChat format ["This is frame %1, not %2", diag_frameno, _this select 0];}, [diag_frameno]] call AIS_Core_fnc_onNextFrame;
(end)

Author:
esteldunedain and PabstMirror, donated from ACE3
---------------------------------------------------------------------------- */
AIS_Core_fnc_onNextFrame = {

    params [
        ["_function", {}, [{}]],
        ["_args", []]
    ];

    if (diag_frameNo != AIS_nextFrameNo) then {
        AIS_nextFrameBufferA pushBack [_args, _function];
    } else {
        AIS_nextFrameBufferB pushBack [_args, _function];
    };
};

/*
Arma Mission Enhancement - Core\Events\fn_removeOnEachFrame.sqf

Author: NetFusion

Description:
Remove an OEF EH by its id. Ids are not persistent but unique inside one frame.

Parameter(s):
- SCALAR - the id of the OEF EH

Returns:
-

Example:
_id call AIS_Core_fnc_removeOnEachFrame;
*/

// Deletes the OEF EH with the given id.
AIS_Core_fnc_removeonEachFrame = {
    private _onEachFrameData = missionNamespace getVariable ["AIS_Core_onEachFrameData", []];
    _onEachFrameData deleteAt _this;
    missionNamespace setVariable ["AIS_Core_onEachFrameData", _onEachFrameData];
};

/*
Arma Mission Enhancement - Core\Events\fn_triggerEvent.sqf

Author: NetFusion

Description:
Triggers an custom event. This should call all previously bound EH for the specific event.

Parameter(s):
- 1: STRING - the name of the event
- 2: ARRAY  - the data which gets passed to all EH (optional)

Returns:
-

Example:
["myEvent", [1, 2, 3]] call AIS_Core_fnc_triggerEvent;
*/
AIS_Core_fnc_triggerEvent = {

    params ["_name", ["_data", []]];

    // Form the name of the EH storage
    _name = format ["AIS_Core_eventHandlersFor%1", _name];
    private _eventHandlers = missionNamespace getVariable [_name, []];

    // Set the default return value to false.
    AIS_Core_eventReturn = nil;

    // Cycle through all EHs and call them with the given data and their params
    {
        _x params ["_code", "_params"];

        [_data, _params] call _code;
        nil
    } count _eventHandlers;

    //@todo find a better way for returning stuff
    if (!isNil "AIS_Core_eventReturn") then {
        AIS_Core_eventReturn
    } else {
        nil
    };
};

/* ----------------------------------------------------------------------------
Function: AIS_Core_fnc_waitUntilAndExecute

Description:
Executes a code once in unscheduled environment after a condition is true.

Parameters:
_condition - The function to evaluate as condition. <CODE>
_statement - The function to run once the condition is true. <CODE>
_args      - Parameters passed to the functions (statement and condition) executing. (optional) <ANY>

Passed Arguments:
_this      - Parameters passed by this function. Same as '_args' above. <ANY>

Returns:
Nothing

Examples:
(begin example)
    [{(_this select 0) == vehicle (_this select 0)}, {(_this select 0) setDamage 1;}, [player]] call AIS_Core_fnc_waitUntilAndExecute;
(end)

Author:
joko // Jonas, donated from ACE3
---------------------------------------------------------------------------- */
AIS_Core_fnc_waitUntilAndExecute = {

    params [
        ["_condition", {}, [{}]],
        ["_statement", {}, [{}]],
        ["_args", []]
    ];

    AIS_waitUntilAndExecArray pushBack [_condition, _statement, _args];

    nil
};
