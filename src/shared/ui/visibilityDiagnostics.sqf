// Structured, direction-independent culling diagnostics. No visibility rays on rendering clients.
// Slow audits are scheduled and yield in small chunks; they never gate camera transport or HC decisions.

CU_var_diagnosticRadii = createHashMap;
CU_var_latestDiagnostics = createHashMap;
CU_var_diagnosticAt = createHashMap;
CU_fnc_logFields = {
    params ["_role", "_owner", "_sequence", "_data"];

    {
        _x params ["_field", "_value"];

        private _serialized = str _value;
        private _parts = 1 max ceil (count _serialized / 650);
        for "_part" from 0 to (_parts - 1) do {diag_log format [
            "CULLING|DATA|%1|owner=%2|seq=%3|field=%4|part=%5/%6|%7", _role, _owner, _sequence, _field, _part + 1,
            _parts, _serialized select [_part * 650, 650]]};
    } forEach _data;
};

CU_fnc_inspectObjects = {
    params ["_viewer", "_rows"];

    if (isServer || {hasInterface} || {!isRemoteExecuted} || {remoteExecutedOwner != 2}) exitWith {};

    private _context = CU_var_contexts getOrDefault [str _viewer, []];

    {
        private _net = _x select 0;
        private _entity = objectFromNetId _net;
        private _state = [];
        if (!isNull _entity && {_context isNotEqualTo []}) then {_state = (_context select 0) getOrDefault [[_entity] call CU_fnc_key, []]};
        private _record = _state param [1, []];
        diag_log format ["CULLING|OBJECT|viewer=%1|%2", _viewer,
            [_net, typeOf _entity, getPosWorld _entity, simulationEnabled _entity, isObjectHidden _entity,
            _state param [4, "notDiscovered"], _state param [3, false], _record param [7, "noRecord"],
            _record param [9, -1], _entity getVariable ["BR_var_inMatch", "-"]]];
    } forEach (_rows select [0, 8]);
};

CU_fnc_diagnostic = {
    params ["_slot", "_role", "_sequence", "_data"];

    if (!isServer || {count _this != 4} || {isNull _slot}) exitWith {};

    private _sender = owner _slot;

    // Arma reports remoteExecutedOwner=0/isRemoteExecuted=false for HC-originated RPCs (BI T128522).
    // Match the registered HC slot and its real owner, as CU_fnc_register/workerStats already do.
    private _valid = if (_role == "HC") then {
        _slot isKindOf "HeadlessClient_F" && {_sender == CU_var_worker} && {remoteExecutedOwner in [0, _sender]}
    } else {

        _role == "CLIENT" && {isRemoteExecuted} && {_sender > 2} && {_sender == remoteExecutedOwner} && {isPlayer _slot} && {!(_slot isKindOf "HeadlessClient_F")}
    };

    if (!_valid || {diag_tickTime - (CU_var_diagnosticAt getOrDefault [str _sender, -100]) < 2}) exitWith {};

    CU_var_diagnosticAt set [str _sender, diag_tickTime];
    CU_var_latestDiagnostics set [str _sender, [_role, _sequence, _data]];
    diag_log format ["CULLING|%1_RELAY|owner=%2|seq=%3|%4", _role, _sender, _sequence, (str _data) select [0, 6000]];
    [_role, _sender, _sequence, _data] call CU_fnc_logFields;

    if (_role == "CLIENT" && {CU_var_worker > 2}) then {
        private _audit = _data select {((_x select 0) find "audit:candidates") == 0};

        if (_audit isNotEqualTo []) then {
            private _rows = ((_audit select 0) select 1) param [5, []];
            if (_rows isNotEqualTo []) then {[_sender, _rows] remoteExecCall ["CU_fnc_inspectObjects", CU_var_worker]}
        };
    };
};

CU_fnc_auditCatalogue = {
    private _known = createHashMapFromArray (CU_var_entities apply {[[_x] call CU_fnc_key, true]});
    private _reference = 0;
    private _missing = 0;
    private _types = createHashMap;
    private _samples = [];
    private _i = 0;
    private _seen = createHashMap;

    {
        private _entity = _x;
        private _key = [_entity] call CU_fnc_key;

        if (!isNull _entity && {isNil {_seen get _key}} && {_entity call CU_fnc_renderable}) then {
            _seen set [_key, true];
            _reference = _reference + 1;

            if (isNil {_known get([_entity] call CU_fnc_key)}) then {
                _missing = _missing + 1;
                private _class = typeOf _entity;
                _types set [_class, 1 + (_types getOrDefault [_class, 0])];
                if (count _samples < 8) then {_samples pushBack [netId _entity, _class, simulationEnabled _entity, isObjectHidden _entity]};
            };
        };

        _i = _i + 1;
        if (_i mod 64 == 0) then {uiSleep 0.001};
    } forEach (allUnits + vehicles + allDead + (allMissionObjects "ReammoBox") + (allMissionObjects "ReammoBox_F") + (24 allObjects 0));

    [count _known, _reference, _missing, _types toArray false, _samples]
};

CU_fnc_auditContexts = {
    private _out = [];

    {
        private _owner = _x;
        private _context = CU_var_contexts getOrDefault [_owner, []];

        if (_context isNotEqualTo []) then {
            private _states = values(_context select 0);
            private _confirmed = 0;
            private _reasons = createHashMap;
            private _i = 0;

            {
                if (_x param [3, false]) then {_confirmed = _confirmed + 1};
                private _reason = _x param [4, (_x select 1) param [7, "visibleOrPending"]];
                _reasons set [_reason, 1 + (_reasons getOrDefault [_reason, 0])];
                _i = _i + 1;
                if (_i mod 64 == 0) then {uiSleep 0.001};
            } forEach _states;

            private _view = CU_var_views getOrDefault [_owner, []];
            _out pushBack [_owner, count _states, _confirmed, count (_context select 1), _reasons toArray false,
                if(_view isEqualTo []) then {-1} else {diag_tickTime -(_view select 10)}];
        };
    } forEach (keys CU_var_contexts);

    _out
};

CU_fnc_initDiagnostics = {
    diag_log format ["CULLING|START|schema=1|owner=%1|server=%2|interface=%3", clientOwner, isServer, hasInterface];

    [] spawn {
        private _sequence = 0;

        while {true} do {
            uiSleep 10;
            _sequence = _sequence + 1;
            private _counts = [];

            isNil {
                _counts = CU_var_logCounts toArray false;
                CU_var_logCounts = createHashMap
            };

            if (isServer) then {
                diag_log format ["CULLING|SERVER|seq=%1|worker=%2|fps=%3|players=%4|counts=%5", _sequence, CU_var_worker, diag_fps, allPlayers apply {[netId _x, owner _x, _x isKindOf "HeadlessClient_F"]}, _counts];
            } else {

                private _role = if (hasInterface) then {"CLIENT"} else {"HC"};

                private _data = if (hasInterface) then {

                    // Counters only: the client does no audits or proof checks (all on the HC).
                    private _gap = CU_var_logViewGap;
                    CU_var_logViewGap = 0;
                    [["worker", CU_var_worker], ["enabled", missionNamespace getVariable ["CU_var_enabled", true]], ["fps", diag_fps],
                    ["viewSequence", missionNamespace getVariable ["CU_var_sequence", 0]],
                    ["heartbeatAge", diag_tickTime - CU_var_heartbeat], ["maxViewGap", _gap], ["tracked", count CU_var_hidden],
                    ["counts", _counts], ["worstFrame:ms,renderChanges,focused", CU_var_worstRenderFrame]]
                } else {

                    private _audit = call CU_fnc_auditCatalogue;
                    private _contexts = call CU_fnc_auditContexts;
                    [["fps", diag_fps], ["catalogueRaw,eligible,excluded", CU_var_catalogueAudit], ["counts", _counts],
                    ["audit:catalogue,reference,missing,types,samples", _audit], ["contexts:owner,states,confirmed,heap,reasons,viewAge", _contexts]]
                };

                diag_log format ["CULLING|%1|owner=%2|seq=%3|%4", _role, clientOwner, _sequence, _data];
                [_role, clientOwner, _sequence, _data] call CU_fnc_logFields;
                [player, _role, _sequence, _data] remoteExecCall ["CU_fnc_diagnostic", 2];
                CU_var_worstRenderFrame = [];
            };
        };
    };
};
