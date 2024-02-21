stage1 = ["stage1_1","stage1_2","stage1_3"];
stage2 = ["stage2_1","stage2_2","stage2_3"];

stages = [stage1,stage2];

stage1_1Amount = 5;
stage1_2Amount = 2;
stage1_3Amount = 4;
stage2_1Amount = 5;
stage2_2Amount = 5;
stage2_3Amount = 5;

{
    _stage = _x;
    {
        _innerStage = _x;

        _spawnPos = getpos (missionNamespace getVariable (_innerStage + "Start"));
        _targetPos = getpos (missionNamespace getVariable (_innerStage + "End"));
        _amount = (missionNamespace getVariable (_innerStage + "Amount"));
        _sightPos = getpos (missionNamespace getVariable (_innerStage + "SightPos"));
        _sightDir = getdir (missionNamespace getVariable (_innerStage + "SightPos"));

        currentPos = _sightPos;
        player setDir _sightDir;

        [[["3","<t align = 'center' shadow = '1' size = '0.7' font='PuristaBold'>%1</t>"]]] spawn BIS_fnc_typeText;
        sleep 1;
        [[["2","<t align = 'center' shadow = '1' size = '0.7' font='PuristaBold'>%1</t>"]]] spawn BIS_fnc_typeText;
        sleep 1;
        [[["1","<t align = 'center' shadow = '1' size = '0.7' font='PuristaBold'>%1</t>"]]] spawn BIS_fnc_typeText;
        sleep 1;
        [[["0","<t align = 'center' shadow = '1' size = '0.7' font='PuristaBold'>%1</t>"]]] spawn BIS_fnc_typeText;

        _group = [_spawnPos, EAST, _amount] call BIS_fnc_spawnGroup;

        _group setBehaviour "CARELESS";
        _group setCombatMode "BLUE";

        _playerArray = [];

        {
            _x setSkill 0;
            _x setSkill ["spotDistance", 0];
            _x setSkill ["courage", 1];
            _x disableAI "TARGET";
            _x disableAI "AUTOTARGET";
            _x disableAI "AIMINGERROR";
            _x disableAI "SUPPRESSION";
            _x disableAI "AUTOCOMBAT";

            _playerArray = _playerArray + [_x];
            [_x] join grpNull;
            _x commandMove _targetPos;
        } forEach units _group;

        while {{(alive _x) && !((_x distance _targetPos) < 5)} count _playerArray > 0} do {
        {
            _unit = _x;

            if (random [0,0.5,1] < 0.24) then {
                _unit commandMove ([_unit,5,(random [0, 180, 360])] call BIS_fnc_relPos);
            } else {
                _unit commandMove _targetPos;
            };
        } forEach _playerArray;

            sleep 1;
        };

        {if (_x != player) then {deleteVehicle _x;};} forEach allUnits;

        sleep 1;
    } forEach _stage;
} forEach stages;

["end1",true,true] call BIS_fnc_endMission;
