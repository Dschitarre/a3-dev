// Disable stamina (server, clients and headless clients): enableStamina / setCustomAimCoef only work on local
// units, so every machine handles the units local to it: players, AI (also led by players or on headless clients)
// and units that change locality (slot taken over / handed back, Zeus remote control).

DS_var_running = false;
DS_var_entityCreatedEhId = -1;
DS_var_entityRespawnedEhId = -1;

DS_fnc_disableStamina = {
    params ["_unit"];

    if (!alive _unit) exitWith {};

    if (isStaminaEnabled _unit) then {
        _unit enableStamina false;
        _unit enableFatigue false;
    };

    if (getCustomAimCoef _unit != DS_var_weaponSwayDisabled) then {
        _unit setCustomAimCoef DS_var_weaponSwayDisabled;
    };
};

DS_fnc_enableStamina = {
    params ["_unit"];

    if (!alive _unit) exitWith {};

    if (!isStaminaEnabled _unit) then {
        _unit enableStamina true;
        _unit enableFatigue true;
    };

    if (getCustomAimCoef _unit != DS_var_weaponSwayEnabled) then {
        _unit setCustomAimCoef DS_var_weaponSwayEnabled;
    };
};

// the "Local" event handler sits on every unit on every machine, so it fires wherever the unit becomes local
DS_fnc_initUnit = {
    params ["_unit"];

    if (isNull _unit) exitWith {};

    if (isNil {_unit getVariable "DS_var_localEhId"}) then {
        _unit setVariable ["DS_var_localEhId", _unit addEventHandler ["Local", {
            params ["_unit", "_isLocal"];

            if (_isLocal) then {
                [_unit] call DS_fnc_disableStamina;
            };
        }]];
    };

    if (local _unit) then {
        [_unit] call DS_fnc_disableStamina;
    };
};

DS_fnc_startDisableStaminaClientServer = {
    if (DS_var_running) exitWith {};

    DS_var_running = true;

    {
        [_x] call DS_fnc_initUnit;
    } forEach entities [["CAManBase"], [], true, false];

    // applied a moment later, once the engine has set the new unit up
    DS_var_entityCreatedEhId = addMissionEventHandler ["EntityCreated", {
        params ["_entity"];

        if (_entity isKindOf "CAManBase") then {
            [_entity] spawn DS_fnc_initUnit;
        };
    }];

    DS_var_entityRespawnedEhId = addMissionEventHandler ["EntityRespawned", {
        params ["_entity"];

        if (_entity isKindOf "CAManBase" && {local _entity}) then {
            [_entity] call DS_fnc_disableStamina;
        };
    }];

    // a loaded singleplayer savegame has reset stamina: apply everything again
    if (!isMultiplayer) then {
        DS_var_loadedEhId = addMissionEventHandler ["Loaded", {
            call DS_fnc_stopDisableStaminaClientServer;

            [] spawn {
                waitUntil {!DS_var_running};
                call DS_fnc_startDisableStaminaClientServer;
            };
        }];
    };
};

DS_fnc_stopDisableStaminaClientServer = {
    if (!DS_var_running) exitWith {};

    DS_var_running = false;

    removeMissionEventHandler ["EntityCreated", DS_var_entityCreatedEhId];
    removeMissionEventHandler ["EntityRespawned", DS_var_entityRespawnedEhId];
    DS_var_entityCreatedEhId = -1;
    DS_var_entityRespawnedEhId = -1;

    {
        private _localEhId = _x getVariable "DS_var_localEhId";

        if (!isNil "_localEhId") then {
            _x removeEventHandler ["Local", _localEhId];
            _x setVariable ["DS_var_localEhId", nil];
        };

        if (local _x) then {
            [_x] call DS_fnc_enableStamina;
        };
    } forEach entities [["CAManBase"], [], true, false];

    if (!isMultiplayer) then {
        removeMissionEventHandler ["Loaded", DS_var_loadedEhId];
        DS_var_loadedEhId = nil;
    };
};

DS_var_clientServerInitDone = true;
