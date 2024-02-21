J_var_ehId = -1;
J_var_canJump = true;

J_fnc_keyDown = {
    params ["", "_key"];

    if ((_key == 47) || {_key == 0x2F}) then {
        if (
            J_var_canJump &&
            {alive player} &&
            {(speed player) > 8.5} &&
            {isNull (objectParent player)} &&
            {isTouchingGround player} &&
            {(currentWeapon player) in [(primaryWeapon player), (handgunWeapon player), ""]}
        ) then {
            _velocity = velocity player;
            _dir = direction player;
            _velocity set [2, 0];
            _velocity = _velocity vectorAdd ([(sin _dir), (cos _dir), 0] vectorMultiply (0.4 * J_var_JumpSpeed));
            _velocity = _velocity vectorMultiply (1 min ((5 * J_var_JumpSpeed) / (vectorMagnitude _velocity)));
            _velocity set [2, (3.5 * (J_var_JumpSpeed ^ 0.4))];
            player setVelocity _velocity;

            [[player, _velocity], {_this remoteExecCall ["setVelocity", -remoteExecutedOwner];}] remoteExecCall ["call", 2];

            if ((currentWeapon player) != "") then {
                player switchmove "AovrPercMrunSrasWrflDf";
                [[player, "AovrPercMrunSrasWrflDf"], {_this remoteExecCall ["switchmove", -remoteExecutedOwner];}] remoteExecCall ["call", 2];
            };

            J_var_canJump = false;
            
            [] spawn {
                sleep 1.2;
                J_var_canJump = true;
            };
        };

        true
    };
};

J_fnc_startJumpClient = {
    if (J_var_ehId == -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            J_var_ehId = (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call J_fnc_keyDown;}];

            if !isMultiplayer then {
                J_var_loadedEhId = addMissionEventHandler ["Loaded", {
                    call J_fnc_stopJumpClient;
                    
                    [] spawn {
                        waitUntil {J_var_ehId == -1};
                        call J_fnc_startJumpClient;
                    };
                }];
            };
        };
    };
};

J_fnc_stopJumpClient = {
    if (J_var_ehId != -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            (findDisplay 46) displayRemoveEventHandler ["KeyDown", J_var_ehId];

            if !isMultiplayer then {
                removeMissionEventHandler ["Loaded", J_var_loadedEhId];
                J_var_loadedEhId = nil;
            };
            
            J_var_ehId = -1;
        };
    };
};

J_var_clientInitDone = true;