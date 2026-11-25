// Team GunGame (teamMode param; server, rating and loadout on every machine): two teams (west, east) climb one ladder
// per team together. Units are no renegades then; the AI fill is balanced per team (GG_fnc_aiTargets).

GG_var_teamSides = [west, east];
GG_var_teamNames = ["BLUFOR", "OPFOR"];
GG_var_teamUniforms = ["U_B_CombatUniform_mcam", "U_O_CombatUniform_ocamo"];

// server init: team progress and the team loadouts (the base loadout with the team's uniform)
GG_fnc_initTeamsServer = {
    call GG_fnc_resetTeams;

    GG_var_teamLoadouts = GG_var_teamUniforms apply {
        private _loadout = +GG_var_loadout;
        _loadout set [3, [_x, []]];
        _loadout
    };

    publicVariable "GG_var_teamLoadouts";
};

GG_fnc_resetTeams = {
    GG_var_teamWeaponNums = [0, 0];
    GG_var_teamStageKills = [0, 0];
};

// the team of a unit, sideUnknown in free for all; kept on the unit (server), so it is still known after its death
GG_fnc_teamOf = {
    params ["_unit"];

    _unit getVariable ["GG_var_team", sideUnknown]
};

/*
    Rating: renegades (-3000) are everyone's enemy in free for all; in team mode it stays neutral, so team kills do
    not turn a unit into a renegade. Set again after every kill.
*/
GG_fnc_setRating = {
    params ["_unit"];

    _unit addRating (([-3000, 0] select GG_var_teamMode) - rating _unit);
};

// base loadout of GG_fnc_applyWeapon: with the team's uniform in team mode
GG_fnc_baseLoadout = {
    params ["_unit"];

    private _teamIndex = GG_var_teamSides find (side group _unit);

    if (!GG_var_teamMode || {_teamIndex == -1}) exitWith {GG_var_loadout};

    GG_var_teamLoadouts select _teamIndex
};

// ---- membership (server) ----

// puts _unit into a group of its own on _side and onto the team's stage
GG_fnc_joinTeam = {
    params ["_unit", "_side"];

    if (side group _unit != _side || {count units group _unit > 1}) then {
        [_unit] joinSilent (createGroup [_side, true]);
    };

    _unit setVariable ["GG_var_team", _side];
    [_unit, GG_var_teamWeaponNums select (GG_var_teamSides find _side)] call GG_fnc_setWeaponNum;
    [_unit] call GG_fnc_setRating;
};

// the team of a joining player: fewer players, then fewer units, a tie at random
GG_fnc_teamForPlayer = {
    params ["_player"];

    private _others = (call GG_fnc_activeUnits) - [_player];
    private _counts = GG_var_teamSides apply {
        private _side = _x;
        private _members = _others select {([_x] call GG_fnc_teamOf) == _side};

        [{isPlayer _x} count _members, count _members]
    };

    _counts params ["_westCounts", "_eastCounts"];

    if (_westCounts isEqualTo _eastCounts) exitWith {selectRandom GG_var_teamSides};

    private _eastSmaller = (_eastCounts select 0) < (_westCounts select 0) ||
        {(_eastCounts select 0) == (_westCounts select 0) && {(_eastCounts select 1) < (_westCounts select 1)}};

    GG_var_teamSides select _eastSmaller
};

// ---- progress (server) ----

// a kill for the killer's team: after the kills of the stage the whole team gets the next weapon
GG_fnc_teamStageKill = {
    params ["_killer"];

    private _teamIndex = GG_var_teamSides find ([_killer] call GG_fnc_teamOf);
    if (_teamIndex == -1) exitWith {};

    private _weaponNum = GG_var_teamWeaponNums select _teamIndex;
    private _stageKills = (GG_var_teamStageKills select _teamIndex) + 1;
    private _killsNeeded = [_weaponNum] call GG_fnc_killsForStage;

    if (_stageKills < _killsNeeded) exitWith {
        GG_var_teamStageKills set [_teamIndex, _stageKills];
        [_killer, _weaponNum, format ["Enemy killed, your team needs %1 more for the next weapon", _killsNeeded - _stageKills]] call GG_fnc_notifyStage;
    };

    [GG_var_teamSides select _teamIndex, 1] call GG_fnc_changeTeamStage;
};

// moves a team _change stages: 1 up, -1 down (suicide with the demotion param)
GG_fnc_changeTeamStage = {
    params ["_side", "_change"];

    private _teamIndex = GG_var_teamSides find _side;
    if (_teamIndex == -1) exitWith {};

    private _oldWeaponNum = GG_var_teamWeaponNums select _teamIndex;
    private _weaponNum = (_oldWeaponNum + _change) max 0;
    if (_weaponNum == _oldWeaponNum) exitWith {};

    GG_var_teamWeaponNums set [_teamIndex, _weaponNum];
    GG_var_teamStageKills set [_teamIndex, 0];

    private _members = (call GG_fnc_activeUnits) select {([_x] call GG_fnc_teamOf) == _side};
    [_members, _weaponNum, GG_var_teamNames select _teamIndex, _change > 0] call GG_fnc_setStage;
};
