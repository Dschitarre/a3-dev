// Progress storage: XP, rank, perks and statistics (lists [[world group, value], ...] per variable) are kept in the
// client's profile, or with the param progressStorage = Server per player UID in the server's profile; the client
// then works on a copy of its data and sends every change to the server. The client's own profile data is taken
// over once, for a UID the server has no data for yet (client and server).

SC_var_progressVarNames = ["SC_var_playerData", "SC_var_killHistory", "SC_var_deathHistory", "SC_var_perks"];

// seconds between two saves of the server's profile (only when progress changed)
SC_var_progressSaveInterval = 60;

// seconds a joining client waits for its progress from the server
SC_var_progressLoadTimeout = 30;

// client: set by SC_fnc_receiveProgress once the data of the server arrived
SC_var_progressOnServer = false;

// ---- client ----

SC_fnc_getProgressList = {
    params ["_varName"];

    if (SC_var_progressOnServer && {_varName in SC_var_progressVarNames}) exitWith {
        SC_var_serverProgress getOrDefault [_varName, []]
    };

    profileNamespace getVariable [_varName, []]
};

SC_fnc_setProgressList = {
    params ["_varName", "_list"];

    if (SC_var_progressOnServer && {_varName in SC_var_progressVarNames}) exitWith {
        SC_var_serverProgress set [_varName, _list];
        [(getPlayerUID player), _varName, _list] remoteExecCall ["SC_fnc_storeProgress", 2];
    };

    profileNamespace setVariable [_varName, _list];
};

// client init (scheduled): with server storage, waits for the player's progress from the server (the request is
// repeated, as a joining player can be missing in allPlayers on the server for a moment); without an answer the
// client profile is used
SC_fnc_loadProgress = {
    if (("progressStorage" call BIS_fnc_getParamValue) != 1) exitWith {};

    SC_var_serverProgress = nil;
    private _request = [(getPlayerUID player), (SC_var_progressVarNames apply {[_x, (profileNamespace getVariable [_x, []])]})];
    private _timeout = time + SC_var_progressLoadTimeout;

    waitUntil {
        _request remoteExecCall ["SC_fnc_sendProgress", 2];

        private _resendTime = time + 5;
        waitUntil {sleep 0.1; !(isNil "SC_var_serverProgress") || {time > _resendTime}};

        !(isNil "SC_var_serverProgress") || {time > _timeout}
    };

    if (isNil "SC_var_serverProgress") then {
        diag_log "SC: no progress data from the server, the client profile is used";
    };
};

SC_fnc_receiveProgress = {
    params ["_data"];

    SC_var_serverProgress = createHashMapFromArray _data;
    SC_var_progressOnServer = true;
};

// ---- server ----

// sends a player his progress; for a UID without server data the client's profile data is stored first (migration)
SC_fnc_sendProgress = {
    params [["_uid", "", [""]], ["_clientData", [], [[]]]];

    if !([_uid] call SC_fnc_isRequestFromUid) exitWith {};

    private _data = SC_var_progressVarNames apply {
        private _varName = _x;
        private _key = _varName + "_" + _uid;
        private _list = profileNamespace getVariable _key;

        if (isNil "_list") then {
            private _clientIndex = _clientData findIf {(_x isEqualType []) && {(_x param [0, ""]) isEqualTo _varName}};
            _list = if (_clientIndex == -1) then {[]} else {(_clientData select _clientIndex) param [1, [], [[]]]};

            profileNamespace setVariable [_key, _list];
            SC_var_progressChanged = true;
        };

        [_varName, _list]
    };

    [_data] remoteExecCall ["SC_fnc_receiveProgress", (allPlayers select {(getPlayerUID _x) == _uid})];
};

// stores a progress list of a player (only accepted from that player's client)
SC_fnc_storeProgress = {
    params [["_uid", "", [""]], ["_varName", "", [""]], ["_list", [], [[]]]];

    if (!(_varName in SC_var_progressVarNames) || {!([_uid] call SC_fnc_isRequestFromUid)}) exitWith {};

    profileNamespace setVariable [(_varName + "_" + _uid), _list];
    SC_var_progressChanged = true;
};

SC_fnc_saveProgressNow = {
    if (missionNamespace getVariable ["SC_var_progressChanged", false]) then {
        SC_var_progressChanged = false;
        saveProfileNamespace;
    };
};

SC_fnc_progressSaveLoop = {
    waitUntil {
        sleep SC_var_progressSaveInterval;
        call SC_fnc_saveProgressNow;

        false
    };
};
