// Killfeed integration: killfeed mod setup, kill XP with the bounty on kill streaks, XP / sector / heal lines in the
// mid feed (server sends, client shows).

SC_var_bountyMinStreak = 3;     // kills in a row (without going down) from which a unit carries a bounty
SC_var_bountyXp = 50;           // bounty at SC_var_bountyMinStreak kills
SC_var_bountyXpPerKill = 25;    // more for every further kill
SC_var_bountyMaxXp = 150;
SC_var_bountyIcon = "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\kill_ca.paa";    // crosshair on a person: "wanted"

// ---- killfeed ----

// server: starts the killfeed mod and adds the SC xp / statistics hooks
SC_fnc_initKillFeedServer = {
    if (isNil "SC_var_spawnVehicleKillHandler") then {
        SC_var_spawnVehicleKillHandler = addMissionEventHandler ["EntityKilled", {
            _this call SC_fnc_spawnVehicleDestroyed;
        }];
    };
    [] spawn {
        waitUntil {!(isNil "KF_var_serverInitDone")};

        KF_var_addMidFeedInfo pushBack {
            params ["_unit", "_hitter", "_isKill", "_isTk", "_hitterDistance", "_hitterTypeSourceSelArr", "_typeOfKilledVehicle", "_externalUnitDeathCall", ["_vehicle", objNull]];

            if _isTk then {""} else {
                private _message = "";
                private _xp = 0;
                // only the killer collects the bounty (no assists, nothing for the final death after going down)
                private _bounty = if (_isKill && _externalUnitDeathCall) then {[_unit] call SC_fnc_getBounty} else {0};

                if !(unitIsUAV _unit) then {
                    _xp = 100;
                };

                // Mobile spawns have their own fixed destruction reward, including when empty.
                if (_typeOfKilledVehicle != "" && {!(_vehicle getVariable ["SC_var_spawnVehicle", false])}) then {
                    private _posVehicle = SC_var_availableVehicles findIf {(_x select 0) == _typeOfKilledVehicle};

                    if (_posVehicle != -1) then {
                        if !((unitIsUAV _unit) || {[_typeOfKilledVehicle] call KF_fnc_isTypeUnmanned}) then {
                            _message = _message + "in <t color='" + ([_unit getVariable ["KF_var_side", civilian]] call KF_fnc_getSidesHexColor) + "'>" + ([_typeOfKilledVehicle] call KF_fnc_getDisplayName) + "</t> ";
                        };

                        _xp = _xp + (900 * (0.15 + ((((SC_var_availableVehicles select _posVehicle) select 1) ^ 0.8) / 35)));
                    };
                };

                _xp = _xp * (exp (_hitterDistance / 2000));

                if (_hitter getVariable ["SC_var_hasExprPerk", false]) then {
                    _xp = 1.5 * _xp;
                    _bounty = 1.5 * _bounty;
                };

                if !_isKill then {
                    _xp = _xp / 3;
                };

                if !_externalUnitDeathCall then {
                    _xp = _xp / 3;
                };

                _xp = 10 * (round (_xp / 10));
                _bounty = 5 * (round (_bounty / 5));
                [_hitter, (_xp + _bounty)] call SC_fnc_giveXp;

                if (_isKill && {_externalUnitDeathCall} && {!(unitIsUAV _unit)}) then {
                    [_hitter, "kills"] call SC_fnc_addRoundStat;
                    [_hitter, _unit] call SC_fnc_rewardDefence;
                };

                (_hitterTypeSourceSelArr select 0) params ["_type", "_source"];

                if (_source != "") then {
                    private _isHeadShot = "Headshot" in _type;
                    private _isRealKill = _externalUnitDeathCall && _isKill;

                    [_source, _hitterDistance, _isRealKill, _isHeadShot, (_xp + _bounty)] remoteExecCall ["SC_fnc_addToKillHistory", _hitter];
                };

                _message + (str _xp) + " XP" + (if (_bounty > 0) then {format [" + %1 bounty", _bounty]} else {""})
            }
        };

        // the bounty of a victim behind its name (all kills of enemies, also by AI, who collect no XP)
        KF_var_addKillFeedInfo pushBack {
            params ["_unit", "", "_isTeamKill"];

            private _bounty = [_unit] call SC_fnc_getBounty;

            if (_isTeamKill || {_bounty == 0}) then {""} else {
                format [" <img color='kf:dim' image='%1'/> %2 XP", SC_var_bountyIcon, _bounty]
            }
        };

        KF_var_addDeathFeedInfo pushBack {
            params ["_unit", "_killer", "", "", "_hitData", "", "", "_externalUnitDeathCall"];

            {
                _x params ["_hitter", "_hitterTypeSourceSelArr", "_distance"];

                _isRealKill = (_hitter isEqualTo _killer) && _externalUnitDeathCall;

                if _isRealKill then {
                    _source = (_hitterTypeSourceSelArr select 0) select 1;
                    private _isHeadshot = "Headshot" in ((_hitterTypeSourceSelArr select 0) select 0);

                    [_source, _distance, _isRealKill, _isHeadshot] remoteExecCall ["SC_fnc_addToDeathHistory", _unit];
                } else {
                    {
                        _x params ["_type", "_source"];
                        _isHeadShot = "Headshot" in _type;

                        [_source, _distance, _isRealKill, _isHeadshot] remoteExecCall ["SC_fnc_addToDeathHistory", _unit];
                    } forEach _hitterTypeSourceSelArr;
                };
            } forEach _hitData;

            ""
        };
    };

    // kill cam: the killer's rank before his name, none once the round is over
    KF_fnc_killCamRank = {
        params ["_unit"];

        _unit getVariable ["SC_var_rank", 1]
    };
    KF_fnc_killCamRoundOver = {missionNamespace getVariable ["SC_var_roundEnded", false]};
    // after the kill cam: through black to the own body, then through black to the respawn menu (user)
    KF_var_killCamOutro = "body";

    if (missionNamespace getVariable ["KF_cba_enabled", true]) then {
        call KF_fnc_startKillfeed;
    };
    KF_var_handleUnitDeaths = true;
    KF_var_showFinallyKilledForUnitDeaths = true;
    KF_var_addScoreForUnitDeaths = false;
    KF_var_showUnitDeathsInKillfeed = false;
    KF_var_showUnitDeathsInMidfeed = true;
    KF_var_showUnitDeathsInDeathFeed = false;
    KF_var_showUnitDeathsInKillInfo = false;
};

// Server EntityKilled hook: one fixed reward for an enemy mobile spawn, independent of its crew and range.
SC_fnc_spawnVehicleDestroyed = {
    params ["_vehicle", "_killer", "_instigator"];
    if (!isServer || {alive _vehicle} || {!(_vehicle getVariable ["SC_var_spawnVehicle", false])} ||
        {_vehicle getVariable ["SC_var_destructionRewarded", false]}) exitWith {false};
    _vehicle setVariable ["SC_var_destructionRewarded", true];
    private _hitter = [_killer, _instigator, _vehicle] call KF_fnc_getInstigator;
    private _owner = _vehicle getVariable ["SC_var_spawnVehicleSide", sideUnknown];
    private _side = _hitter getVariable ["SC_var_side", side group _hitter];
    if (isNull _hitter || {!(_hitter isKindOf "CAManBase")} || {!(_owner in SC_var_sides)} ||
        {!(_side in SC_var_sides)} || {_side == _owner} || {_side getFriend _owner >= 0.6}) exitWith {false};
    private _name = _vehicle getVariable ["SC_var_spawnVehicleName", "Mobile spawn"];
    if (isPlayer _hitter) then {
        [_hitter, 1000] call SC_fnc_giveXp;
        [_hitter, "destroyed", _owner, _name, 1000] call SC_fnc_sendMidFeedXpLine;
    } else {
        [_hitter, "xp", 1000] call SC_fnc_addRoundStat;
    };
    private _line = format ["%1 destroyed <t color='%2'>%3</t> <img image='\A3\ui_f\data\IGUI\RscTitles\MPProgress\respawn_ca.paa'/> 1000 XP",
        [_hitter] call KF_fnc_unitTag, [_owner] call UI_fnc_sideColorHtml, [_name] call KF_fnc_formatName];
    ["KF_fnc_addKillFeedLine", [_line], 0] call KF_fnc_callClients;
    true
};

// server: "You <action> <target> <xp> XP" line in the receiver's midfeed (the text is built on the client)
SC_fnc_sendMidFeedXpLine = {
    params ["_receiver", "_action", "_targetSide", "_targetName", "_xp"];

    [_action, _targetSide, _targetName, _xp] remoteExecCall ["SC_fnc_addMidFeedXpLine", _receiver];
};

// client: the target in its side color; font, size and position come from the killfeed (like its own lines)
SC_fnc_addMidFeedXpLine = {
    params ["_action", "_targetSide", "_targetName", "_xp"];

    if (isNil "KF_fnc_addMidFeedLine") exitWith {};

    [format [
        "<t color='%1'>You</t> %2 <t color='%3'>%4</t> %5 XP",
        ["kf:text", "kf:you"] select KF_var_midFeedYouColorYellow,   // color keys, filled in by the killfeed
        _action,
        [_targetSide] call UI_fnc_sideColorHtml,
        [_targetName] call KF_fnc_formatName,   // cut and escaped like the killfeed's names
        _xp
    ]] call KF_fnc_addMidFeedLine;
};

// client: "<side> <sector icon> <sector>" killfeed line (the icon has the text's size)
SC_fnc_addSectorCapturedLine = {
    params ["_side", "_sector"];

    if (!hasInterface || {isNil "KF_fnc_addKillFeedLine"}) exitWith {};

    [format [
        "<t color='%1'>%2</t> %3 %4",
        [_side] call UI_fnc_sideColorHtml,
        [_side] call SC_fnc_getSideString,
        "<img image='\a3\ui_f\data\Map\VehicleIcons\iconLogic_ca.paa'/>",
        _sector
    ]] call KF_fnc_addKillFeedLine;
};

// server: a player revived a unit (the healer got the XP from AIS already)
SC_fnc_midFeedHeal = {
    params ["_healer", "_injured", "_xp"];

    [_healer, "revives"] call SC_fnc_addRoundStat;
    [_healer, "xp", _xp] call SC_fnc_addRoundStat;

    [
        _healer, "revived",
        (_injured getVariable ["KF_var_side", sideUnknown]),
        (_injured getVariable ["KF_var_name", "Error: no unit"]),
        _xp
    ] call SC_fnc_sendMidFeedXpLine;
};

// ---- bounty ----

// server: bounty XP on a unit, from its kill streak as the killfeed counts it (kills of enemies, also by AI, since the
// unit last went down or died; the same count as "Most kills in a row" on the end screen). The killfeed resets the
// victim's count only after its feeds, so the feed hooks still read the streak it had.
SC_fnc_getBounty = {
    params ["_unit"];

    private _streak = _unit getVariable ["KF_var_killsInARow", 0];

    if ((_streak < SC_var_bountyMinStreak) || {unitIsUAV _unit}) exitWith {0};

    SC_var_bountyMaxXp min (SC_var_bountyXp + (SC_var_bountyXpPerKill * (_streak - SC_var_bountyMinStreak)))
};
