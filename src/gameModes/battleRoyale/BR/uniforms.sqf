// Uniforms from any faction: right-click and drag onto the uniform slot; left double-click keeps vanilla inspection.
// A swap never moves pocket contents: the old uniform drops to the ground with its own contents as
// loot, the new one is worn with exactly the contents it had. The server arbitrates the source (locks, take, restore);
// the unit's own uniform is changed only where the unit is local (player: its client, AI: the server), in one frame.

BR_var_uniformActionDistance = 4;           // m, reach for a uniform in a holder, crate or on a body
BR_var_uniformTimeout = 20;                 // s, the server gives up on an owner that never answers (disconnect, error)
BR_var_inventoryDisplay = 602;
BR_var_inventoryLists = [632, 640, 633, 638, 619];
BR_var_inventoryUniformSlot = 6331;
BR_var_uniformTransactions = createHashMap; // server: token -> open swap

BR_fnc_initUniforms = {
    if (player getVariable ["BR_var_uniformHooksInstalled", false]) exitWith {};

    player setVariable ["BR_var_uniformHooksInstalled", true];

    // No scroll-wheel Wear uniform action: the normal inventory is the interface.
    player addEventHandler ["InventoryOpened", {
        params ["", "_container", "_secondContainer"];

        [[_container, _secondContainer] select {!isNull _x}] spawn BR_fnc_hookInventory;
        false
    }];

    player addEventHandler ["InventoryClosed", {
        BR_var_draggedClass = "";
        BR_var_inventoryDragging = false
    }];

    if !(missionNamespace getVariable ["BR_var_inventoryRespawnHook", false]) then {
        BR_var_inventoryRespawnHook = true;

        addMissionEventHandler ["EntityRespawned", {
            params ["_new", "_old"];

            if (_new isEqualTo player || {_old isEqualTo player}) then {
                [_new] spawn {
                    params ["_unit"];

                    waitUntil {
                        uiSleep 0.01;
                        player isEqualTo _unit || {isNull _unit}
                    };

                    if (isNull _unit) exitWith {};

                    _unit setVariable ["BR_var_uniformHooksInstalled", false];
                    _unit setVariable ["BR_var_itemHooksInstalled", false];
                    call BR_fnc_initUniforms;
                    call BR_fnc_initItems;
                };
            };

        }];
    };
};

BR_fnc_isUniform = {
    params ["_class"];

    getNumber (configFile >> "CfgWeapons" >> _class >> "ItemInfo" >> "type") == 801
};

BR_fnc_uniformContainer = {
    params ["_class", ["_preferred", []]];

    private _sources = _preferred + [uniformContainer player, vestContainer player, backpackContainer player] +
    (player nearSupplies BR_var_uniformActionDistance);

    (_sources select {
        !isNull _x && {_x isNotEqualTo player} && {
            ((itemCargo _x) findIf {toLowerANSI _x == toLowerANSI _class}) >= 0 ||
                {_x isKindOf "CAManBase" && {!alive _x} && {toLowerANSI uniform _x == toLowerANSI _class}}
        }

    }) param [0, objNull]
};

// A cargo snapshot (BR_fnc_aiReadCargo) with anything in it; a uniform entry without nested data reads as [].
BR_fnc_uniformHasCargo = {
    params ["_contents"];

    (_contents findIf {_x isNotEqualTo []}) >= 0
};

BR_fnc_uniformGroundHolder = {
    params ["_unit"];

    private _foot = getPosASL _unit;
    private _position = _foot vectorAdd [0, 0, 0.1];
    private _floor = lineIntersectsSurfaces [_foot vectorAdd [0, 0, 0.75], _foot vectorAdd [0, 0, -0.75], _unit, objNull, true, -1, "GEOM", "NONE"];
    _floor = _floor select {((_x select 0) select 2) <= (_foot select 2) + 0.1 && {((_x select 1) select 2) > 0.5}};
    if (_floor isNotEqualTo []) then {_position = ((_floor select 0) select 0) vectorAdd [0, 0, 0.05]};
    private _holder = createVehicle ["GroundWeaponHolder", ASLToAGL _position, [], 0, "CAN_COLLIDE"];
    _holder setPosASL _position;
    _holder
};

// Called on the server only; remote callers may request a swap for their own player, never for somebody else.
BR_fnc_swapUniform = {
    params [["_unit", objNull, [objNull]], ["_source", objNull, [objNull]], ["_class", "", [""]], ["_request", ""]];

    if (!isServer || {isNull _unit} || {isNull _source}) exitWith {false};

    if (isRemoteExecuted && {remoteExecutedOwner != owner _unit || {!isPlayer _unit}}) exitWith {false};

    private _started = false;
    isNil {_started = [_unit, _source, _class, _request] call BR_fnc_swapUniformNow};

    // A started swap answers the requester from BR_fnc_finishUniform, exactly once.
    if (!_started && {_request != ""}) then {[_unit, _request, false] remoteExecCall ["BR_fnc_uniformResult", owner _unit]};
    _started
};

BR_fnc_uniformResult = {
    params ["_unit", "_request", "_success"];

    if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};

    if (_unit isNotEqualTo player || {_request isNotEqualTo (missionNamespace getVariable ["BR_var_uniformPending", ""])}) exitWith {};

    BR_var_uniformPending = "";
    if (!_success) then {systemChat "Uniform change failed. Reopen the inventory and try again."};

    // the inventory again, on the container the uniform came from if it is still in reach (the old
    // uniform now lies at the feet: the ground shows in the inventory anyway)
    if (alive player && {isNull findDisplay BR_var_inventoryDisplay}) then {
        private _source = missionNamespace getVariable ["BR_var_uniformReopenSource", objNull];

        // a ground holder, crate or vehicle; the own pockets and bodies open with the plain inventory
        if (
            !isNull _source && {player distance _source < 5} &&
            {(["WeaponHolder", "WeaponHolderSimulated", "ReammoBox_F", "LandVehicle", "Air", "Ship"] findIf {_source isKindOf _x}) >= 0}
        ) then {
            player action ["Gear", _source];
        } else {
            player action ["Gear", objNull];
        };
    };
};

/*
    Server, unscheduled. Locks unit and source, takes the uniform out of a foreign source (holder, crate, vehicle, body)
    in this same frame, and hands the change of the worn uniform to the machine where the unit is local. True once the
    swap is started; BR_fnc_finishUniform closes it. The unit's own pockets are not touched here: the server's copy of a
    remote player's containers lags behind the client, so only the owner reads and changes them.
*/
BR_fnc_swapUniformNow = {
    params [["_unit", objNull, [objNull]], ["_source", objNull, [objNull]], ["_class", "", [""]], ["_request", ""]];

    if (!isServer || {isNull _unit} || {isNull _source}) exitWith {false};

    if (isRemoteExecuted && {remoteExecutedOwner != owner _unit || {!isPlayer _unit}}) exitWith {false};

    // One swap per unit and per source at a time: a double click or a second looter cannot interleave.
    if (!isNil {_unit getVariable "BR_var_uniformTransaction"}) exitWith {false};

    if (!isNil {_source getVariable "BR_var_uniformReservation"}) exitWith {false};

    if(!alive _unit || {_unit getVariable ["ais_unconscious", false]} || {!isNull objectParent _unit} ||
        {!([_class] call BR_fnc_isUniform)}) exitWith {false};

    private _own = _source in [uniformContainer _unit, vestContainer _unit, backpackContainer _unit];
    if (!_own && {_unit distance _source > BR_var_uniformActionDistance}) exitWith {false};

    if (!_own && {!([_unit, _source, BR_var_uniformActionDistance] call BR_fnc_aiCanReachLoot)}) exitWith {false};

    private _body = _source isKindOf "CAManBase";

    if (_body && {alive _source || {_source getVariable ["BR_var_uniformRemoved", false]} ||
        {toLowerANSI uniform _source != toLowerANSI _class}}) exitWith {false};

    private _cargo = [];
    private _index = -1;

    if (!_own && {!_body}) then {
        _cargo = [_source] call BR_fnc_aiReadCargo;
        _index = (_cargo select 2) findIf {toLowerANSI (_x select 0) == toLowerANSI _class};
    };

    if (!_own && {!_body} && {_index < 0}) exitWith {false};

    // Take before equipping: the worn copy may never exist while the source copy still does.
    private _contents = [];

    if (!_own) then {
        if (_body) then {
            _contents = [uniformContainer _source] call BR_fnc_aiReadCargo;

            // removeUniform takes a local argument; a dead player's body stays local to that player's client. The mark
            // keeps the server's stale view of that body from offering the same uniform twice.
            if (local _source) then {removeUniform _source} else {_source remoteExecCall ["removeUniform", _source]};
            _source setVariable ["BR_var_uniformRemoved", true];
        } else {

            _contents = ((_cargo select 2) deleteAt _index) select 1;
            [_source, _cargo] call BR_fnc_aiWriteCargo;
        };
    };

    private _owner = owner _unit;
    BR_var_uniformTokenNumber = 1 + (missionNamespace getVariable ["BR_var_uniformTokenNumber", 0]);
    private _token = format ["%1:%2", _owner, BR_var_uniformTokenNumber];
    BR_var_uniformTransactions set [_token, [_unit, _request, _source, _class, _contents, _own, _body, _owner]];
    _unit setVariable ["BR_var_uniformTransaction", _token];
    if (!_own) then {_source setVariable ["BR_var_uniformReservation", _token]};
    private _ownSource = [objNull, _source] select _own;

    // Server-local units (AI, a hosting player) change right here, within this transaction.
    if (local _unit) exitWith {
        [_unit, _token, _class, _contents, _ownSource] call BR_fnc_applyUniform;
        true
    };

    [_unit, _token, _class, _contents, _ownSource] remoteExecCall ["BR_fnc_applyUniform", _owner];

    // A connected owner always answers (remoteExec is ordered and reliable). This only closes swaps whose owner is gone.
    [_unit, _token, _owner] spawn {
        params ["_unit", "_token", "_owner"];

        private _until = diag_tickTime + BR_var_uniformTimeout;

        waitUntil {
            sleep 0.5;
            !(_token in BR_var_uniformTransactions) || {isNull _unit} || {owner _unit != _owner} || {diag_tickTime > _until}
        };

        // Judge by what the unit wears now. A vanished unit took the uniform along: restoring it would duplicate it.
        isNil {
            private _transaction = BR_var_uniformTransactions get _token;

            if (!isNil "_transaction") then {
                [_token, isNull _unit || {toLowerANSI uniform _unit == toLowerANSI (_transaction select 3)}] call BR_fnc_finishUniform;
            };
        };
    };

    true
};

/*
    Runs where the unit is local, unscheduled: removeUniform/forceAddUniform take local arguments, and only this machine
    knows the unit's current pockets. Reads, removes, equips and drops in one frame, so neither the engine nor another
    script sees a half-done state. Always reports to the server, which releases the locks or restores the source.
*/
BR_fnc_applyUniform = {
    params ["_unit", "_token", "_class", "_contents", "_ownSource"];

    if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};

    private _ok = local _unit && {alive _unit} && {isNull objectParent _unit} && {!(_unit getVariable ["ais_unconscious", false])};
    private _oldClass = uniform _unit;
    private _oldContents = if (isNull uniformContainer _unit) then {[[], [], [], []]} else {[uniformContainer _unit] call BR_fnc_aiReadCargo};
    private _oldOriginal = +_oldContents;
    private _ownOriginal = [];

    // A uniform carried in the unit's own pockets is taken here, from the only current copy of that container.
    if (_ok && {!isNull _ownSource}) then {
        private _fromOld = _ownSource isEqualTo uniformContainer _unit;
        private _cargo = if (_fromOld) then {_oldContents} else {[_ownSource] call BR_fnc_aiReadCargo};
        private _index = (_cargo select 2) findIf {toLowerANSI (_x select 0) == toLowerANSI _class};

        if (_index < 0) then {_ok = false} else {
            if (!_fromOld) then {_ownOriginal = +_cargo};

            // From the worn uniform itself: the entry leaves _oldContents, so the dropped uniform no longer holds it.
            _contents = ((_cargo select 2) deleteAt _index) select 1;
            if (!_fromOld) then {[_ownSource, _cargo] call BR_fnc_aiWriteCargo};
        };
    };

    if (_ok) then {

        // Explicit removal first: forceAddUniform over a worn uniform would drop it wherever the engine likes.
        removeUniform _unit;
        _unit forceAddUniform _class;

        if (toLowerANSI uniform _unit == toLowerANSI _class) then {
            if ([_contents] call BR_fnc_uniformHasCargo) then {[uniformContainer _unit, _contents] call BR_fnc_aiWriteCargo};

            // The old uniform keeps its own pockets and lies at the unit's feet as loot for anyone.
            if (_oldClass != "") then {
                private _keep = [[], _oldContents] select ([_oldContents] call BR_fnc_uniformHasCargo);
                [[_unit] call BR_fnc_uniformGroundHolder, [[], [], [[_oldClass, _keep]], []]] call BR_fnc_aiWriteCargo;
            };
        } else {

            // The engine refused the uniform: back to exactly what was worn and carried before.
            _ok = false;
            removeUniform _unit;

            if (_oldClass != "") then {
                _unit forceAddUniform _oldClass;
                if ([_oldOriginal] call BR_fnc_uniformHasCargo) then {[uniformContainer _unit, _oldOriginal] call BR_fnc_aiWriteCargo};
            };

            if (_ownOriginal isNotEqualTo []) then {[_ownSource, _ownOriginal] call BR_fnc_aiWriteCargo};
        };
    };

    if (isServer) then {[_token, _ok] call BR_fnc_finishUniform} else {[_token, _ok] remoteExecCall ["BR_fnc_finishUniform", 2]};
};

// Server: closes a swap exactly once. Only the unit's owner (or the server itself) may report the result.
BR_fnc_finishUniform = {
    params [["_token", "", [""]], ["_success", false, [false]]];

    if (!isServer) exitWith {};

    private _transaction = BR_var_uniformTransactions get _token;
    if (isNil "_transaction") exitWith {};

    _transaction params ["_unit", "_request", "_source", "_class", "_contents", "_own", "_body", "_owner"];
    if (isRemoteExecuted && {remoteExecutedOwner != _owner}) exitWith {};

    BR_var_uniformTransactions deleteAt _token;

    // A failed change gives the taken uniform back. A body cannot be redressed reliably and a ground holder emptied by
    // the take may already be deleted, so those get a fresh holder at the same spot; crates and vehicles get it back.
    if (!_success && {!_own}) then {
        private _entry = [_class, [[], _contents] select ([_contents] call BR_fnc_uniformHasCargo)];

        private _loose = _body || {isNull _source} || {_source isKindOf "WeaponHolder"} ||
            {_source isKindOf "WeaponHolderSimulated"};

        if (_loose) then {
            private _at = [_source, _unit] select (isNull _source);
            if (!isNull _at) then {[[_at] call BR_fnc_uniformGroundHolder, [[], [], [_entry], []]] call BR_fnc_aiWriteCargo};
        } else {

            private _cargo = [_source] call BR_fnc_aiReadCargo;
            (_cargo select 2) pushBack _entry;
            [_source, _cargo] call BR_fnc_aiWriteCargo;
        };
    };

    if (!isNull _unit) then {_unit setVariable ["BR_var_uniformTransaction", nil]};
    if (!_own && {!isNull _source}) then {_source setVariable ["BR_var_uniformReservation", nil]};
    if (_request != "") then {[_unit, _request, _success] remoteExecCall ["BR_fnc_uniformResult", _owner]};
};

BR_fnc_wearUniform = {
    params ["_source", "_class"];

    if (isNull _source || {!alive player}) exitWith {false};

    if ((missionNamespace getVariable ["BR_var_uniformPending", ""]) != "") exitWith {false};

    BR_var_uniformRequestNumber = 1 + (missionNamespace getVariable ["BR_var_uniformRequestNumber", 0]);
    private _request = format ["%1:%2:%3", clientOwner, diag_frameNo, BR_var_uniformRequestNumber];
    BR_var_uniformPending = _request;
    BR_var_uniformReopenSource = _source;
    player setVariable ["BR_var_bandageInterrupted", true];

    // Close before dispatch and consume the UI event, so vanilla cannot transfer the same item concurrently.
    private _inventory = findDisplay BR_var_inventoryDisplay;
    if (!isNull _inventory) then {_inventory closeDisplay 2};
    [player, _source, _class, _request] remoteExecCall ["BR_fnc_swapUniform", 2];

    // Only a lost answer leaves the request pending; the server's own lock outlives this by design.
    [_request] spawn {
        params ["_request"];

        uiSleep (BR_var_uniformTimeout + 5);
        if ((missionNamespace getVariable ["BR_var_uniformPending", ""]) == _request) then {BR_var_uniformPending = ""};
    };

    true
};

BR_fnc_uniformDragClass = {
    params ["_rows"];

    private _class = "";

    {
        if (_x isEqualType []) then {_class = [_x] call BR_fnc_uniformDragClass} else {
            if (_x isEqualType "" && {[_x] call BR_fnc_isUniform}) then {_class = _x};
        };

        if (_class != "") exitWith {};

    } forEach _rows;

    _class
};

// Prefer the clicked pocket over another uniform of the same class on the ground.
BR_fnc_inventoryUniformSource = {
    params ["_list", "_class"];

    private _preferred = +BR_var_inventoryContainers;
    private _ownIndex = [633, 638, 619] find (ctrlIDC _list);

    if (_ownIndex >= 0) then {
        private _own = [uniformContainer player, vestContainer player, backpackContainer player];
        _preferred = [_own select _ownIndex] + _preferred;
    };

    [_class, _preferred] call BR_fnc_uniformContainer
};

BR_fnc_inventoryWear = {
    params ["_list", "_index"];

    if (_index < 0) exitWith {false};

    private _class = _list lbData _index;
    if !([_class] call BR_fnc_isUniform) exitWith {false};
    private _source = [_list, _class] call BR_fnc_inventoryUniformSource;
    if (isNull _source) exitWith {false};

    [_source, _class] call BR_fnc_wearUniform;
    true
};

BR_fnc_inventoryUniformDrop = {
    params ["_display", "_button"];

    private _class = missionNamespace getVariable ["BR_var_draggedClass", ""];
    BR_var_draggedClass = "";
    BR_var_inventoryDragging = false;
    if (!(_button in [0, 1]) || {_class == ""} || {!([_class] call BR_fnc_isUniform)}) exitWith {false};

    private _slot = _display displayCtrl BR_var_inventoryUniformSlot;
    if (isNull _slot) exitWith {false};

    (ctrlPosition _slot) params ["_x", "_y", "_w", "_h"];
    private _parent = ctrlParentControlsGroup _slot;

    while {!isNull _parent} do {
        private _position = ctrlPosition _parent;
        _x = _x + (_position select 0);
        _y = _y + (_position select 1);
        _parent = ctrlParentControlsGroup _parent;
    };

    getMousePosition params ["_mouseX", "_mouseY"];

    if (_mouseX < _x || {_mouseX > _x + _w} || {_mouseY < _y} || {_mouseY > _y + _h}) exitWith {false};

    [missionNamespace getVariable ["BR_var_draggedSource", objNull], _class] call BR_fnc_wearUniform;
    true
};

BR_fnc_hookInventory = {
    params ["_containers"];

    disableSerialization;
    private _until = diag_tickTime + 2;

    waitUntil {
        uiSleep 0.01;
        !isNull (findDisplay BR_var_inventoryDisplay) || {diag_tickTime > _until}
    };

    private _display = findDisplay BR_var_inventoryDisplay;
    if (isNull _display) exitWith {};

    BR_var_inventoryContainers = _containers;
    BR_var_draggedSource = objNull;
    BR_var_draggedClass = "";
    BR_var_inventoryDragging = false;
    if (_display getVariable ["BR_var_uniformHooked", false]) exitWith {};

    _display setVariable ["BR_var_uniformHooked", true];

    {
        private _list = _display displayCtrl _x;

        if (!isNull _list) then {

            // Left double-click retains vanilla inspection of a uniform's pockets, including corpses.
            // A single right-click wears it: the engine selects the clicked row only after this event, so the row is
            // read a frame later (at once it would still be the row selected before).
            _list ctrlAddEventHandler ["MouseButtonUp", {
                params ["_list", "_button"];

                if (_button == 1) then {
                    [_list] spawn {
                        disableSerialization;
                        params ["_list"];

                        uiSleep 0.01;

                        if (!isNull _list) then {[_list, lbCurSel _list] call BR_fnc_inventoryWear};
                    };
                };
            }];

            _list ctrlAddEventHandler ["MouseButtonDown", {
                params ["_list", "_button"];

                if (_button == 0) then {
                    BR_var_inventoryDragging = true;
                    BR_var_draggedClass = _list lbData (lbCurSel _list);
                    BR_var_draggedSource = [_list, BR_var_draggedClass] call BR_fnc_inventoryUniformSource
                };

                false
            }];

            _list ctrlAddEventHandler ["LBSelChanged", {
                params ["_list", "_index"];

                if (missionNamespace getVariable ["BR_var_inventoryDragging", false]) then {
                    BR_var_draggedClass = _list lbData _index;
                    BR_var_draggedSource = [_list, BR_var_draggedClass] call BR_fnc_inventoryUniformSource
                };

            }];

            _list ctrlAddEventHandler ["LBDrag", {
                params ["_list", "_rows"];

                BR_var_draggedClass = [_rows] call BR_fnc_uniformDragClass;
                BR_var_draggedSource = [_list, BR_var_draggedClass] call BR_fnc_inventoryUniformSource;

            }];
        };
    } forEach BR_var_inventoryLists;

    private _uniformSlot = _display displayCtrl BR_var_inventoryUniformSlot;

    if (!isNull _uniformSlot) then {
        _uniformSlot ctrlAddEventHandler ["MouseButtonUp", {[ctrlParent (_this select 0), _this select 1] call BR_fnc_inventoryUniformDrop}];
        private _dropControl = _uniformSlot;

        while {!isNull _dropControl} do {
            _dropControl ctrlAddEventHandler ["LBDrop", {[ctrlParent (_this select 0), 0] call BR_fnc_inventoryUniformDrop}];
            _dropControl = ctrlParentControlsGroup _dropControl;
        };
    };

    _display displayAddEventHandler ["MouseButtonUp", {_this call BR_fnc_inventoryUniformDrop}];
};
