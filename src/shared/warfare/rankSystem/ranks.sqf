// Ranks: XP per rank, gaining XP and rank ups (both).

// Rank system: xp and rank ups, perks and perk slots, items unlocked by rank and perks,
// arsenal content and the equipment / perk dialogs (both).

// ---- ranks ----

// xp needed for rank n + 1 at index n - 1 (the last rank needs 0)
SC_var_xpRanks = call {
    private _xpRanks = [3000];

    for "_i" from 2 to 1000 do {
        _xpRanks pushBack (1000 * (floor ((1000 + (2000 * (1.05 ^ _i))) / 1000)));
    };

    _xpRanks pushBack 0;
    _xpRanks
};

// server: gives a player XP (client: SC_fnc_addXp) and counts it in the round statistics
SC_fnc_giveXp = {
    params ["_unit", "_xp"];

    if (!(isPlayer _unit) || {_xp == 0}) exitWith {};

    [_xp] remoteExecCall ["SC_fnc_addXp", _unit];
    [_unit, "xp", _xp] call SC_fnc_addRoundStat;
};

SC_fnc_addXp = {
    params ["_xp"];

    private _data = call SC_fnc_getPlayerData;
    private _newXP = (_data select 0) + _xp;
    _data set [0, _newXP];
    [_data] call SC_fnc_setPlayerData;
};

SC_fnc_rankSystemLoop = {
    private _newName = "[" + (str (player getVariable "SC_var_rank")) + "] " + ([player] call SC_fnc_getName);
    player setVariable ["TDI_var_name", _newName, true];
    player setVariable ["MM_var_name", _newName, true];

    [SC_var_equip, (side (group player)), (player getVariable "SC_var_rank"), SC_var_perks] call SC_fnc_changePerks;
    waitUntil {!isNil {player getVariable "SC_var_rank"}};
    SC_var_neededXp = SC_var_xpRanks select ((player getVariable "SC_var_rank") - 1);

    if (SC_var_neededXp > 0) then {
        waitUntil {
            waitUntil {
                sleep 1;
                ((call SC_fnc_getPlayerData) select 0) >= SC_var_neededXp
            };

            call {
                private _rank = (player getVariable "SC_var_rank") + 1;
                player setVariable ["SC_var_rank", _rank, true];
                private _data = call SC_fnc_getPlayerData;
                _data set [1, _rank];
                [_data] call SC_fnc_setPlayerData;
                saveProfileNamespace;
                _newName = "[" + (str _rank) + "] " + ([player] call SC_fnc_getName);
                player setVariable ["TDI_var_name", _newName, true];
                player setVariable ["MM_var_name", _newName, true];
                [-SC_var_neededXp] call SC_fnc_addXp;
                SC_var_neededXp = SC_var_xpRanks select (_rank - 1);
                private _numPerkSlots = [_rank] call SC_fnc_getNumPerkSlots;

                while {(count SC_var_perks) < _numPerkSlots} do {
                    SC_var_perks pushBack "";
                };

                [SC_var_equip, (side (group player)), _rank, SC_var_perks] call SC_fnc_changePerks;

                if SC_var_hudEnabled then {
                    ["rankUp", [str _rank]] call BIS_fnc_showNotification;
                };
            };

            (SC_var_neededXp <= 0)
        };
    };
};
