SC_fnc_updateMapIconsDrawArray = {
    params ["_sleep"];

    {
        if (!MM_var_gpsOpened || {[(uiNamespace getVariable "MM_var_currentDisplay"), (getPosWorldVisual _x)] call MM_fnc_isPosVisibleOnGPS}) then {
            MM_var_preDrawArray pushBack [
                _x, true, 0, false, "iconParachute", MM_var_colorWhite, 16,
                (" " + (_x getVariable "SC_var_timeRemaining")), 2, 0.06, true
            ];
        };

        if _sleep then {
            sleep 0.0015;
        };
    } forEach (entities "box_NATO_equip_F");

    _playerSide = side (group player);
    _alivePlayer = alive player;

    {
        _owner = missionNamespace getVariable ("SC_var_owner" + _x);

        if (
            (_alivePlayer || {!visibleMap} || {_owner != _playerSide}) &&
            {!MM_var_gpsOpened || {[(uiNamespace getVariable "MM_var_currentDisplay"), (getMarkerPos ("SC_var_sector" + _x))] call MM_fnc_isPosVisibleOnGPS}}
        ) then {
            _holder = missionNamespace getVariable ("SC_var_holder" + _x);
            _flag3d = missionNamespace getVariable ("SC_var_flag" + _x + "3d");

            MM_var_preDrawArray pushBack [
                _flag3d, true, 0, false, "iconLogic",
                ([
                    (missionNamespace getVariable ("SC_var_holder" + _x)), 1,
                    ((missionNamespace getVariable ("SC_var_flag" + _x)) / 100)
                ] call SC_fnc_getSectorColor),
                20, "", 2, 0, true
            ];
            MM_var_preDrawArray pushBack [_flag3d, true, 50, false, "iconLogic", MM_var_colorWhite, 0, _x, 2, 0.085, true];
        };

        if _sleep then {
            sleep 0.0015;
        };
    } forEach SC_var_sectors;
};