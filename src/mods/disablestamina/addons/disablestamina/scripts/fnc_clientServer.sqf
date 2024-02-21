DS_fnc_disableStamina = {
    params ["_unit"];

    if (alive _unit) then {
        if (isStaminaEnabled _unit) then {
            _unit enableStamina false;
            _unit enableFatigue false;
        };

        if ((getCustomAimCoef _unit) != DS_var_weaponSwayDisabled) then {
            _unit setCustomAimCoef DS_var_weaponSwayDisabled;
        };
    };
};

DS_fnc_enableStamina = {
    params ["_unit"];

    if (alive _unit) then {
        if !(isStaminaEnabled _unit) then {
            _unit enableStamina true;
            _unit enableFatigue true;
        };
        
        if ((getCustomAimCoef _unit) != DS_var_weaponSwayEnabled) then {
            _unit setCustomAimCoef DS_var_weaponSwayEnabled;
        };
    };
};

DS_var_clientServerInitDone = true;