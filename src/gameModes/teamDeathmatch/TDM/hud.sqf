// Team Deathmatch HUD (client): score, timer and alive counts on screen (earplugs: the earplugs mod).

// ---- HUD (client) ----

// RscTitles DM_rscHud (TDM\ui.hpp). Per frame only cheap reads; a text is only set when its value changes.
DM_fnc_guiLoop = {
    disableSerialization;
    private _hud = uiNamespace getVariable "DM_rscHud";
    private _hpBar = _hud displayCtrl 1200;
    private _hpText = _hud displayCtrl 1201;
    private _westPointsText = _hud displayCtrl 1100;
    private _timerText = _hud displayCtrl 1101;
    private _eastPointsText = _hud displayCtrl 1102;
    private _westAliveText = _hud displayCtrl 1000;
    private _eastAliveText = _hud displayCtrl 1001;
    private _hpBarFull = ctrlPosition _hpBar;      // layout of TDM\ui.hpp = 100 HP

    private _shownHp = -1;
    private _shownWestPoints = -1;
    private _shownEastPoints = -1;
    private _shownTimer = "";
    private _shownAlive = [];
    private _nextCountUpdate = 0;

    waitUntil {
        private _hp = ceil ((1 - damage focusOn) * 100);

        if (_hp != _shownHp) then {
            _shownHp = _hp;
            _hpText ctrlSetText format ["%1 HP", _hp];
            _hpBarFull params ["_barX", "_barY", "_barW", "_barH"];
            _hpBar ctrlSetPosition [_barX, _barY, (_hp / 100) * _barW, _barH];
            _hpBar ctrlCommit 0;
        };

        if (DM_var_westPoints != _shownWestPoints) then {
            _shownWestPoints = DM_var_westPoints;
            _westPointsText ctrlSetText str _shownWestPoints;
        };

        if (DM_var_eastPoints != _shownEastPoints) then {
            _shownEastPoints = DM_var_eastPoints;
            _eastPointsText ctrlSetText str _shownEastPoints;
        };

        if (DM_var_timerStr isNotEqualTo _shownTimer) then {
            _shownTimer = DM_var_timerStr;
            _timerText ctrlSetText _shownTimer;
        };

        // the alive counts scan all units: throttled
        if (time >= _nextCountUpdate) then {
            _nextCountUpdate = time + DM_var_hudCountInterval;

            private _alive = [west, east] apply {
                {!(isPlayer _x && {_x getVariable ["CMN_var_isLoading", false]})} count ([_x] call DM_fnc_unitsOfSide)
            };

            if (_alive isNotEqualTo _shownAlive) then {
                _shownAlive = _alive;
                _westAliveText ctrlSetText str (_alive select 0);
                _eastAliveText ctrlSetText str (_alive select 1);
            };
        };

        false
    };
};
