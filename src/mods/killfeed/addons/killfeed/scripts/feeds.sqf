// Killfeed feeds (server): kill feed for everybody, mid feed for the involved players, death feed for the victim.
// Included by fnc_server.sqf; the clients draw them (fnc_client.sqf).

// ---- kill feed: "victim <weapon> killer + assistant" for everybody ----

KF_fnc_sendKillFeed = {
    params ["_unit", "_killer", "_isTeamKill", "_hitData", "_killData", "", "", "", "_isUnitDeath"];
    _killData params ["", "_killerCauses", "_killDistance"];

    if (!KF_var_killFeedEnabled || {_isUnitDeath && !KF_var_showUnitDeathsInKillfeed}) exitWith {};

    private _assistants = (_hitData apply {_x select 0}) - [_killer];
    private _killerTags = [[_killer] call KF_fnc_unitTag];

    if (_assistants isNotEqualTo []) then {
        _killerTags pushBack ([_assistants select 0] call KF_fnc_unitTag);
    };

    if (count _assistants > 1) then {
        _killerTags pushBack str (count _assistants - 1);
    };

    // a self-kill (zone, fall, own grenade) shows the dead one only, on the right in either order,
    // not the same name on both sides
    private _selfKill = isNull _killer || {_killer isEqualTo _unit};
    // the zone and tombstone icons fill their square (weapon pictures have a margin): a wider gap to the name
    private _line = format [
        if (_selfKill) then {"%2 %4 %1"} else {["%3 %2 %1", "%1 %2 %3"] select KF_var_killFeedInversed},
        [_unit] call KF_fnc_unitTag,
        [_killerCauses, 1, true] call KF_fnc_formatHitsPicture,
        _killerTags joinString " + ",
        format ["<t size='%1'> </t>", KF_var_textSizeCells]
    ];
    private _extraInfo = (KF_var_addKillFeedInfo apply {[_unit, _killer, _isTeamKill, _killDistance, _killerCauses] call _x}) joinString "";

    // font, size and alignment come from the clients (KF_fnc_formatEntry)
    ["KF_fnc_addKillFeedLine", [_line + _extraInfo], 0] call KF_fnc_callClients;
};

// ---- mid feed: "You killed X" / "You assisted Y to kill X" for every player who hit the victim ----
// A player who died at the same moment (trade kill) gets the line in his death feed. The player leading an AI that
// hit the victim gets "Your J. Doe (AI) killed X".

// the player leading an AI unit, objNull if none
KF_fnc_getAiLeader = {
    params ["_unit"];

    private _leader = leader group _unit;

    if (isPlayer _leader && {_leader isNotEqualTo _unit}) then {_leader} else {objNull}
};

KF_fnc_formatMidFeedLine = {
    params ["_subject", "_action", "_victimTag", "_details"];

    ([_subject, _action, _victimTag] + (_details select {_x != ""})) joinString " "
};

KF_fnc_sendMidFeed = {
    params ["_unit", "_killer", "", "_hitData", "_killData", "_killedVehicleType", "_isExternal", "", "_isUnitDeath", "", "", ["_killedVehicle", objNull]];

    if (!KF_var_midFeedEnabled || {_isUnitDeath && !KF_var_showUnitDeathsInMidfeed}) exitWith {};

    private _youColor = ["kf:text", "kf:you"] select KF_var_midFeedYouColorYellow;
    private _isFinal = _isUnitDeath && KF_var_showFinallyKilledForUnitDeaths;
    private _victimTag = [_unit] call KF_fnc_unitTag;

    {
        _x params ["_hitter", "_causes", "_distance"];

        private _isPlayer = isPlayer _hitter;
        private _receiver = switch (true) do {
            case (_hitter isEqualTo _unit): {objNull};   // own hits, suicide
            case (_isPlayer): {_hitter};
            default {[_hitter] call KF_fnc_getAiLeader};
        };

        if (!isNull _receiver) then {
            private _isKill = _hitter isEqualTo _killer;
            private _isTeamKill = [_hitter, _unit] call KF_fnc_isTeamKill;
            private _action = if (_isKill) then {
                ["killed", "finally killed"] select _isFinal
            } else {
                format ["assisted %1 to%2 kill", [_killer] call KF_fnc_unitTag, ["", " finally"] select _isFinal]
            };
            private _details = [[_distance, [], _isTeamKill, false] call KF_fnc_formatHitsText];

            if (_isPlayer) then {
                // the game modes' additions (e.g. XP for the hitter) only for players
                _details append (KF_var_addMidFeedInfo apply {
                    [_unit, _hitter, _isKill, _isTeamKill, _distance, _causes, _killedVehicleType, _isExternal, _killedVehicle] call _x
                });

                [
                    ["KF_fnc_addDeathFeedLine", "KF_fnc_addMidFeedLine"] select (alive _hitter || !KF_var_deathFeedEnabled),
                    [[format ["<t color='%1'>You</t>", _youColor], _action, _victimTag, _details] call KF_fnc_formatMidFeedLine],
                    _hitter
                ] call KF_fnc_callClients;
            } else {
                private _subject = format [
                    "<t color='%1'>Your</t> %2%3",
                    _youColor,
                    ["AI ", ""] select KF_var_showAiInNames,
                    [_hitter] call KF_fnc_unitTag
                ];

                ["KF_fnc_addMidFeedLine", [[_subject, _action, _victimTag, _details] call KF_fnc_formatMidFeedLine], _receiver] call KF_fnc_callClients;
            };
        };
    } forEach ([[_killData], _hitData] select KF_var_midFeedAssists);
};

// ---- death feed: detailed report for the victim (or the operators of a killed UAV) ----

KF_fnc_sendDeathFeed = {
    params ["_unit", "_killer", "_isTeamKill", "_hitData", "_killData", "", "_isExternal", "_isUav", "_isUnitDeath", "_uavOperators", ["_killerHealth", -1]];
    _killData params ["", "_killerCauses", "_killDistance"];

    if (!KF_var_deathFeedEnabled || {_isUnitDeath && !KF_var_showUnitDeathsInDeathFeed}) exitWith {};

    private _receivers = ([[_unit], _uavOperators] select _isUav) select {isPlayer _x};

    if (_receivers isEqualTo []) exitWith {};

    // the receivers' own hits on the killer
    private _killerHits = if (_killer isEqualTo _unit) then {[]} else {[_killer, objectParent _killer] call KF_fnc_getHits};
    private _killerSelections = [];

    {
        _killerSelections insert [-1, _x select 2, true];
    } forEach _killerCauses;

    private _selectionsText = [_killerSelections, false] call KF_fnc_formatSelections;
    private _rank = "";

    // the rank of Sector Control
    if (!isNil "SC_var_serverInitDone") then {
        _rank = format ["[%1] ", _killer getVariable ["SC_var_rank", 1]];
    };

    // the report in short blocks: who, with what from where, where hit, own hits on the killer, assists, game mode info;
    // the header: "You were killed by [rank] name"
    private _header = format [
        "%1 by %2%3%4",
        ["<t color='kf:you'>You</t> were killed", format ["<t color='kf:you'>Your</t> %1 was destroyed", [_unit] call KF_fnc_unitTag]] select _isUav,
        _rank,
        [_killer] call KF_fnc_unitTag,
        ["", " <t color='kf:warning'>(friendly fire)</t>"] select (_isTeamKill && KF_var_showFriendlyFire)
    ];
    // the killer's remaining health as a bar entry (KF_fnc_drawEntries) under the header
    private _healthBar = ["", ["bar", _killerHealth]] select ((_killer isNotEqualTo _unit) && {_killerHealth >= 0});
    // pictures about 2.7 times as high as the text, the distance next to them
    private _weapon = ([
        [_killerCauses, 2.08, false] call KF_fnc_formatHitsPicture,
        ["", format ["%1 m", round _killDistance]] select (_killDistance != -1)
    ] select {_x != ""}) joinString "  ";
    private _bodyParts = ["", format ["Hit at: %1", _selectionsText]] select (_selectionsText != "");

    {
        private _receiver = _x;

        ([_killerHits, _receiver, _receiver] call KF_fnc_aggregateHits) params [["_counterData", [objNull, [], -1]]];
        _counterData params ["", "_counterCauses", "_counterDistance"];

        private _ownHits = "";
        private _assists = [];

        // the heading with the distance, below it one line per kind of hit, so the block is only as wide as needed
        if (_counterCauses isNotEqualTo []) then {
            _ownHits = format [
                "<t color='kf:you'>Your</t> hits on %1%2:<br/>%3",
                [_killer] call KF_fnc_unitTag,
                ["", format [" (%1 m)", floor _counterDistance]] select (_counterDistance != -1),
                ([_counterCauses, _isTeamKill] call KF_fnc_formatHitsLines) apply {KF_var_listBullet + " " + _x} joinString "<br/>"
            ];
        };

        {
            _x params ["_hitter", "_causes", "_distance"];

            if (_hitter isNotEqualTo _killer) then {
                private _isReceiver = _hitter isEqualTo _receiver;

                _assists pushBack format [
                    "%1: %2",
                    [[_hitter] call KF_fnc_unitTag, "<t color='kf:you'>You</t>"] select _isReceiver,
                    [_distance, _causes, !_isReceiver && {[_hitter, _unit] call KF_fnc_isTeamKill}, true] call KF_fnc_formatHitsText
                ];
            };
        } forEach _hitData;

        private _assistsText = ["", "<t font='RobotoCondensedBold'>Assists</t><br/>" + (_assists joinString "<br/>")] select (_assists isNotEqualTo []);
        private _extraInfo = KF_var_addDeathFeedInfo apply {
            [_receiver, _killer, _isTeamKill, _killDistance, _hitData, _counterDistance, _counterCauses, _isExternal] call _x
        };

        // only the parts with content, each one is a block on the clients; font, size and alignment come from the
        // clients (KF_fnc_formatEntry)
        private _parts = ([_header, _healthBar, _weapon, _bodyParts, _ownHits, _assistsText] + _extraInfo) select {_x isNotEqualTo ""};

        ["KF_fnc_addDeathFeed", [_parts], _receiver] call KF_fnc_callClients;
    } forEach _receivers;
};
