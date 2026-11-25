// Battle Royale AI (server): a cheap state machine per AI combatant, one unit handled at a time. aboard -> falling ->
// loot (searches buildings for real loot, BR\aiLoot.sqf) -> move (into the next safe zone, on foot or by vehicle,
// BR\aiVehicles.sqf; holds there). Known enemies close by are attacked in every state; supply crates nearby are looted;
// team mates follow their team's player or first AI.

BR_var_aiTickInterval = 2;          // each AI is handled about this often ...
BR_var_aiFarTickInterval = 6;       // ... an idle one far from every player and from the zone edge less often
BR_var_aiNearPlayerDistance = 1200;
BR_var_aiNearZoneEdge = 300;        // metres to the edge of the current or the next circle
BR_var_groupCleanupInterval = 30;   // s between two removals of empty groups (BR_fnc_cleanUpGroups)
BR_var_aiEngageRange = 300;         // known or seen enemies closer than this are fought (also on the way into the zone) ...
BR_var_aiChaseRange = 150;          // ... closer than this the AI goes for them, farther it takes cover and fires
BR_var_aiSightRange = 150;          // ... and those this close in line of sight (whatever the engine knows of them)
BR_var_aiSightVisibility = 0.5;     // checkVisibility of their center from the AI's eyes
BR_var_aiThreatTime = 20;           // s: an enemy who hit, suppressed or fired near the AI is fought at least this long ...
BR_var_aiThreatRange = 800;         // ... at any distance up to this (BR_fnc_aiThreat; also when the AI gave up on him)
BR_var_aiFaceShotsTime = 5;         // s: shots from an unseen enemy stop the unit once per burst (BR_fnc_aiFaceShots)
BR_var_aiCoverDistance = 15;        // a fight at a distance: cover about this far away from the enemy ...
BR_var_aiCoverRadius = 20;          // ... the best spot within this radius around it (BR_var_aiCoverExpression)
BR_var_aiApproachDistance = 40;     // an AI walks towards its enemy until it is this close
BR_var_aiRearmMaxTime = 15;         // the engine's own rearming is cancelled after this long (BR_fnc_aiCheckRearm) ...
BR_var_aiDroppedRetry = 300;        // ... a primary without ammo then dropped is left alone by AI this long
BR_var_aiOrderRepeatTime = 10;      // the same destination is ordered again at most this often (stuck units)
BR_var_aiReorderShare = 0.25;       // a destination moved less than this share of the way counts as the same one
BR_var_aiLegLength = 300;           // on foot a far destination is ordered in legs this long (BR_fnc_aiLegTarget) ...
BR_var_aiLegReach = 60;             // ... the next one once the unit is this close to the end of the current one
BR_var_aiLegTurns = [0, 30, -30, 60, -60, 90, -90];    // a leg ending in water turns aside by these angles
BR_var_aiFollowDistance = 35;       // AI team mates stay this close to their leader ...
BR_var_aiFollowOffset = 10;         // ... and walk to a spot this far from it
BR_var_aiFollowMaxDistance = 800;   // a team player farther away than this is not followed
BR_var_aiFollowAiMaxDistance = 300; // an AI leader farther away than this is not followed (the mate acts on its own)
BR_var_aiZoneInnerShare = 0.35;     // zone destinations lie within this share of the next zone's radius (well inside:
                                    // ready for the next shift; 0.6 had a third more zone deaths on the whole map) ...
BR_var_aiEndPhaseInnerShare = 0.2;  // ... in the end phase (BR_var_aiEndPhaseRadius) closer to its middle: position
BR_var_aiZoneSpotSpread = 0.3;      // random spread of a zone destination, share of that inner radius
BR_var_aiOwnLandmassShare = 0.5;    // a zone over several landmasses: the own one is kept if it has this share of the largest
BR_var_aiTravelSpeed = 1.8;         // m/s an AI makes good on its way (detours, cover, loot on the way), for its zone timing
BR_var_aiZoneLeadTime = 90;         // an AI outside of the next zone leaves this long before the zone would reach it
BR_var_aiHealSafeTime = 30;         // s: an urgent AI still heals in the zone while its edge is at least this far away
BR_var_aiStuckTime = 20;            // an AI on its way that moved less than BR_var_aiStuckDistance in this time is stuck
BR_var_aiStuckDistance = 8;
BR_var_aiStuckCheckGap = 10;        // a move order after a longer pause starts a new progress measurement
BR_var_aiStuckIgnoreDistance = 15;  // this close to its destination an AI is never stuck
BR_var_aiDetourDistance = 30;
BR_var_aiUnstickRadius = 30;        // last resort for a stuck AI: a free spot within this distance
BR_var_aiTrapTime = 60;             // an AI ordered on its way that moved less than BR_var_aiTrapDistance for this long
BR_var_aiTrapDistance = 2;          // inside a building is caught in it (BR_fnc_aiCheckTrapped) ... (1 m: an AI crawling
                                    // with hurt legs on a container top jittered 1.4 m and was never counted - pd66)
BR_var_aiTrapOrderAge = 30;         // ... (its last move order at most this old) ...
BR_var_aiTrapExitRadius = 14;       // ... and is put on a free spot outside of it within this distance
BR_var_aiOpenTrapExit = [8, 12, 16];  // m: caught in the open (walls, sandbags, wire around it), it is put this far away
BR_var_aiWaterTrapExit = [8, 16, 24, 32, 48, 64]; // m: ... caught in the water, the nearest land this far
BR_var_aiHealDamage = 0.3;          // an AI out of a fight heals itself above this damage ...
BR_var_aiHealLegDamage = 0.5;       // ... or with legs hit this much (it limps) ...
BR_var_aiHealInterval = 20;         // ... at most this often
BR_var_aiHealItems = ["FirstAidKit", "Medikit"];
BR_var_aiMedikitDamage = 0.5;       // an AI this hurt uses a medikit first (else a first aid kit; user 2026-11-23)
BR_var_aiIdleTime = 30;             // an AI that moved less than BR_var_aiIdleMoveDistance for this long gets a new task
BR_var_aiIdleMoveDistance = 5;      // (not in a fight, not holding cover in the end phase) ...
BR_var_aiIdleUnstickCount = 2;      // ... and after this many new tasks in a row at the same spot it heads into the zone,
BR_var_aiUnstickLastTry = 3;        // freed with BR_fnc_aiUnstick's last try (a free spot nearby)
BR_var_aiEndPhaseRadius = 400;      // a next zone smaller than this is the end phase: hold in cover, move between covers
BR_var_aiRepositionTime = 60;       // big zone, nothing left to loot around: a new spot after holding this long
BR_var_aiCoverRepositionTime = 45;  // end phase: new cover after holding this long
BR_var_aiCoverSearchRadius = 40;    // zone spots move to the best cover within this distance ...
BR_var_aiCoverExpression = "(1 + houses) * (1 + forest + trees) - meadow - (10 * sea)";   // ... (selectBestPlaces)
BR_var_aiCoverPrecision = 10;
BR_var_aiFlankAngle = 80;           // a stalled fight is tried once from the side: this far around the enemy

// ---- setup ----

// roster lock: a fresh AI combatant (local to the server)
BR_fnc_prepareAi = {
    params ["_unit"];

    [_unit] call BR_fnc_applyBaseLoadout;
    _unit setVariable ["BR_var_aiState", "aboard"];
    _unit setVariable ["BR_var_lootStops", 0];
    [_unit] call BR_fnc_initAiCombatant;
};

// skill, hostility and combat mode; also when the AI takes over the unit of a player who left
BR_fnc_initAiCombatant = {
    params ["_unit"];

    private _range = (BR_var_aiLootStops select 1) - (BR_var_aiLootStops select 0);

    [_unit] call BR_fnc_makeRenegade;
    _unit setSkill ([_unit] call CMN_fnc_aiSkill);
    _unit setSkill ["courage", 1];
    _unit setVariable ["BR_var_lootStopsWanted", (BR_var_aiLootStops select 0) + floor random (_range + 1)];
    _unit setVariable ["BR_var_ignoresGroup", grpNull];
    _unit setVariable ["BR_var_aiTravelMode", nil];
    _unit setVariable ["BR_var_aiFollowAngle", random 360];
    _unit enableAI "ALL";
    _unit setUnitCombatMode "RED";
    [group _unit] call BR_fnc_aiGroupSettings;
    [_unit] call BR_fnc_aiAddThreatHandlers;
};

/*
    Hit, suppressed or fired near by an enemy (server, where the AI is local): the AI fights back at once, whatever it
    was doing (BR_fnc_aiThreat). Once per unit; they do nothing while a player controls it.
*/
BR_fnc_aiAddThreatHandlers = {
    params ["_unit"];

    if (_unit getVariable ["BR_var_aiThreatHandlers", false]) exitWith {};

    _unit setVariable ["BR_var_aiThreatHandlers", true];

    _unit addEventHandler ["FiredMan", {
        (_this select 0) setVariable ["BR_var_aiLastFired", time];
    }];

    _unit addEventHandler ["Hit", {
        params ["_unit", "_source", "", "_instigator"];

        [_unit, [_instigator, _source] select (isNull _instigator), "hit"] call BR_fnc_aiThreat;
    }];
    _unit addEventHandler ["FiredNear", {
        params ["_unit", "_firer", "", "", "", "", "", "_gunner"];

        [_unit, [_gunner, _firer] select (isNull _gunner), "firedNear"] call BR_fnc_aiThreat;
    }];
    _unit addEventHandler ["Suppressed", {
        params ["_unit", "", "_shooter", "_instigator"];

        [_unit, [_instigator, _shooter] select (isNull _instigator), "suppressed"] call BR_fnc_aiThreat;
    }];
};

/*
    Never fleeing: alone in its group and enemy of everyone, an AI lost its morale at once - nearly every AI that saw an
    enemy close by but did not fire was fleeing, weapon lowered (the engine's morale; also a fight it could win)
*/
BR_fnc_aiGroupSettings = {
    params ["_group"];

    _group setCombatBehaviour "AWARE";
    _group setCombatMode "RED";
    _group setSpeedMode "FULL";
    _group allowFleeing 0;
    // The fights are BR's (BR\aiCombat.sqf: doTarget/doFire, cover, approach, withdrawal). The engine's own ATTACK
    // orders (the AI leads its own group) override those moves like its rearming does, and with an enemy it could not
    // get at the AI stood in place for minutes (2 per Altis match, br389).
    _group enableAttack false;
};

// back in an own group (after a ride in a temporary group, BR\aiVehicles.sqf)
BR_fnc_aiOwnGroup = {
    params ["_unit"];

    private _group = createGroup [independent, true];

    // no group left (a side has at most 288): it stays with the driver's group
    if (isNull _group) exitWith {
        diag_log format ["BR AI: no own group for %1, group limit reached", _unit];
    };

    [_unit] joinSilent _group;
    [_group] call BR_fnc_aiGroupSettings;
    _unit setVariable ["BR_var_aiTravelMode", nil];
};

// the AI takes over the unit of a player who left during the match (unit local to the server)
BR_fnc_aiTakeOver = {
    params ["_unit"];

    [_unit] call BR_fnc_initAiCombatant;

    if (_unit getVariable ["BR_var_aboard", false]) exitWith {
        _unit setVariable ["BR_var_aiState", "aboard"];
        [[_unit]] call BR_fnc_aiChooseDrop;
    };

    _unit setVariable ["BR_var_aiState", ["loot", "move"] select (primaryWeapon _unit != "")];

    if (isNull objectParent _unit && {((getPosATL _unit) select 2) > BR_var_freefallMinHeight}) then {
        _unit setVariable ["BR_var_aiState", "falling"];
        [_unit] spawn BR_fnc_aiDescent;
    };
};

// ---- state machine ----

// spawned once the flight starts: the AI units that are due, spread over BR_var_aiTickInterval
BR_fnc_aiLoop = {
    private _nextGroupCleanup = time + BR_var_groupCleanupInterval;

    waitUntil {
        // ride groups and own groups after rides come and go (a side has at most 288 groups)
        if (time >= _nextGroupCleanup) then {
            _nextGroupCleanup = time + BR_var_groupCleanupInterval;
            call BR_fnc_cleanUpGroups;
        };

        private _dueUnits = BR_var_rosterUnits select {
            alive _x &&
            {!isPlayer _x} &&
            {local _x} &&
            {!(_x getVariable ["BR_var_aboard", false])} &&
            {time >= (_x getVariable ["BR_var_aiNextTick", 0])}
        };

        if (_dueUnits isEqualTo []) then {
            sleep (BR_var_aiTickInterval / 4);
        } else {
            private _sleepTime = BR_var_aiTickInterval / count _dueUnits;
            private _players = BR_var_rosterUnits select {alive _x && {isPlayer _x}};

            {
                if (alive _x && {!isPlayer _x}) then {
                    [_x] call BR_fnc_aiTick;
                    _x setVariable ["BR_var_aiNextTick", time + ([_x, _players] call BR_fnc_aiTickInterval)];
                };

                sleep _sleepTime;
            } forEach _dueUnits;
        };

        BR_var_state == "ended"
    };
};

/*
    Level of detail with many AI: BR_var_aiFarTickInterval for an AI that is busy with nothing urgent (no fight, loot run,
    crate or ride) and far from every player and from the edge of the current and the next circle, else
    BR_var_aiTickInterval. The engine keeps moving and fighting in between.
*/
BR_fnc_aiTickInterval = {
    params ["_unit", "_players"];

    if (
        !isNull objectParent _unit ||
        {(_unit getVariable ["BR_var_aiFight", []]) isNotEqualTo []} ||
        {!isNull (_unit getVariable ["BR_var_aiLootBuilding", objNull])} ||
        {!isNull (_unit getVariable ["BR_var_aiCrate", objNull])} ||
        {!isNull (_unit getVariable ["BR_var_aiRideVehicle", objNull])} ||
        {(_players findIf {_x distance2D _unit < BR_var_aiNearPlayerDistance}) != -1}
    ) exitWith {BR_var_aiTickInterval};

    ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];
    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];

    if (
        abs (_radius - (_unit distance2D _center)) < BR_var_aiNearZoneEdge ||
        {abs (_nextRadius - (_unit distance2D _nextCenter)) < BR_var_aiNearZoneEdge}
    ) exitWith {BR_var_aiTickInterval};

    BR_var_aiFarTickInterval
};

// downed, or on the way to revive a mate / reviving (BR\downed.sqf): AIS has the unit. Afterwards it starts afresh
// (AIS switched its AI features: the travel mode is set again).
BR_fnc_aiReviveBusy = {
    params ["_unit"];

    if (
        _unit getVariable ["ais_unconscious", false] ||
        {!isNull (_unit getVariable ["AIS_isHelper", objNull])} ||
        {_unit getVariable ["BR_var_reviving", false]}
    ) exitWith {
        _unit setVariable ["BR_var_aiReviveBusy", true];
        true
    };

    if (_unit getVariable ["BR_var_aiReviveBusy", false]) then {
        _unit setVariable ["BR_var_aiReviveBusy", false];
        _unit setVariable ["BR_var_aiTravelMode", nil];
        _unit setVariable ["BR_var_aiDestination", []];
        _unit setVariable ["BR_var_aiHoldSince", -1];
        _unit setVariable ["BR_var_aiIdlePos", []];
    };

    false
};

BR_fnc_aiTick = {
    params ["_unit"];

    if ((_unit getVariable ["BR_var_aiState", ""]) in ["aboard", "falling"]) exitWith {};
    if ([_unit] call BR_fnc_aiReviveBusy) exitWith {};

    if (!isNull objectParent _unit) exitWith {
        [_unit] call BR_fnc_aiRideTick;
    };

    [_unit] call BR_fnc_applyTeamIgnores;
    if ([_unit] call BR_fnc_aiCheckTrapped) exitWith {};
    [_unit] call BR_fnc_aiCheckRearm;

    private _urgent = [_unit] call BR_fnc_aiZoneUrgent;
    [_unit] call BR_fnc_aiObserve;
    private _safe = [_unit] call BR_fnc_aiSafeToHeal;
    private _hurry = ([_unit] call BR_fnc_aiOutsideZone) ||
        {_urgent && {(([getPosATL _unit] call BR_fnc_zoneEdgeTime) - serverTime) < BR_var_aiHealSafeTime}};
    if (_unit getVariable ["BR_var_bandaging", false] && {!_safe || {_hurry}}) then {
        _unit setVariable ["BR_var_bandageInterrupted", true];
    };
    // Use a safe opening to recover before choosing another optional fight. Under fire, first seek cover.
    if (_safe && {!_hurry}) exitWith {
        if (_unit getVariable ["BR_var_bandaging", false]) exitWith {};
        if ([_unit] call BR_fnc_aiHeal) exitWith {};
        if ([_unit, false] call BR_fnc_aiUseItems) exitWith {};
        [_unit, _urgent] call BR_fnc_aiGroundTask;
    };

    if ([_unit, _urgent] call BR_fnc_aiEngage) exitWith {
        if (_urgent && {(_unit getVariable ["BR_var_aiDecision", ""]) == "rotate"}) then {
            [_unit, [_unit] call BR_fnc_aiZoneDestination, false] call BR_fnc_aiMoveTo;
        };
    };
    [_unit, _urgent] call BR_fnc_aiGroundTask;
};

BR_fnc_aiGroundTask = {
    params ["_unit", "_urgent"];
    if ([_unit, _urgent] call BR_fnc_aiCheckIdle) exitWith {};
    if ([_unit, _urgent] call BR_fnc_aiLooseLootTick) exitWith {};
    if ([_unit, _urgent] call BR_fnc_aiLootRunTick) exitWith {};
    if ([_unit, _urgent] call BR_fnc_aiCrateTick) exitWith {};

    private _leader = [_unit] call BR_fnc_aiTeamLeader;

    if (!isNull _leader) exitWith {
        if ([_unit, _urgent] call BR_fnc_aiScavenge) exitWith {};

        if (_unit distance2D _leader > BR_var_aiFollowDistance) then {
            [_unit, _leader getPos [BR_var_aiFollowOffset, _unit getVariable ["BR_var_aiFollowAngle", 0]]] call BR_fnc_aiMoveTo;
        } else {
            [_unit] call BR_fnc_aiStartHold;
        };
    };

    // the zone first: an urgent unit only loots buildings right on its way (BR_fnc_aiScavenge), armed or not
    if ((_unit getVariable ["BR_var_aiState", ""]) == "loot" && {!_urgent}) exitWith {
        [_unit, _urgent] call BR_fnc_aiLootTick;
    };

    [_unit, _urgent] call BR_fnc_aiMoveTick;
};

// the unit an AI follows: a living player of its team nearby, else the team's first AI (none for that AI itself and
// none while it is far away, e.g. stuck: the mate acts on its own until it is close again)
BR_fnc_aiTeamLeader = {
    params ["_unit"];

    private _mates = ([_unit getVariable ["BR_var_teamId", -1]] call BR_fnc_teamUnits) select {
        alive _x && {!(_x getVariable ["BR_var_aboard", false])} && {!(_x getVariable ["ais_unconscious", false])}
    };
    private _playerIndex = _mates findIf {isPlayer _x && {_x distance2D _unit < BR_var_aiFollowMaxDistance}};

    if (_playerIndex != -1) exitWith {_mates select _playerIndex};

    private _aiIndex = _mates findIf {!isPlayer _x};

    if (_aiIndex == -1) exitWith {objNull};

    private _aiLeader = _mates select _aiIndex;

    if (_aiLeader isEqualTo _unit || {_aiLeader distance2D _unit > BR_var_aiFollowAiMaxDistance}) exitWith {objNull};

    _aiLeader
};

// the unit is outside of the next zone's inner part and, at the pace of an AI, would only get there after the
// shrinking circle reached it: no more looting
BR_fnc_aiZoneUrgent = {
    params ["_unit"];

    BR_var_zone params ["_phase", "", "", "", "_nextCenter", "_nextRadius", "_shrinkStart"];

    private _distance = _unit distance2D _nextCenter;
    private _endPhase = _nextRadius < BR_var_aiEndPhaseRadius;
    private _way = _distance - _nextRadius * ([BR_var_aiZoneInnerShare, BR_var_aiEndPhaseInnerShare] select _endPhase);

    // in the end phase everyone outside of the next zone goes at once (position before the circle closes); while
    // the zone shrinks everyone outside of it; before, who would not make it in time
    _phase > 0 &&
    {_way > 0} &&
    {
        (_endPhase && {_distance > _nextRadius}) ||
        {serverTime >= _shrinkStart && {_distance > _nextRadius}} ||
        {(serverTime + _way / BR_var_aiTravelSpeed + BR_var_aiZoneLeadTime) > ([getPosATL _unit] call BR_fnc_zoneEdgeTime)}
    }
};

// state "move": to the unit's spot in the next zone (on foot or by vehicle), loot runs on the way, then BR_fnc_aiHoldTick
BR_fnc_aiMoveTick = {
    params ["_unit", "_urgent"];

    private _destination = [_unit] call BR_fnc_aiZoneDestination;

    if ([_unit, _urgent] call BR_fnc_aiScavenge) exitWith {};

    if (_unit distance2D _destination <= BR_var_aiFollowDistance) exitWith {
        [_unit, _urgent] call BR_fnc_aiHoldTick;
    };

    if ([_unit, _destination] call BR_fnc_aiTryRide) exitWith {};

    [_unit, _destination] call BR_fnc_aiMoveTo;
};

/*
    At its zone spot an AI never just stands: while the zone is big it searches the houses around (inside the zone) and
    moves on to a new spot when none is left; in the end phase it holds in cover (the engine may crouch and lie down) and
    moves to new cover now and then.
*/
BR_fnc_aiHoldTick = {
    params ["_unit", "_urgent"];

    private _holdTime = time - ([_unit] call BR_fnc_aiStartHold);

    if ((BR_var_zone select 5) >= BR_var_aiEndPhaseRadius) exitWith {
        if (!_urgent && {[_unit] call BR_fnc_aiIdleLoot}) exitWith {};

        if (_holdTime > BR_var_aiRepositionTime && {[_unit] call BR_fnc_aiNeedsSupplies}) then {
            [_unit] call BR_fnc_aiNewZoneSpot;
        };
    };

    // A good end-phase position stays useful; elapsed time alone is not a reason to expose oneself.
    if (_holdTime > BR_var_aiCoverRepositionTime && {[_unit] call BR_fnc_aiZoneUrgent}) then {
        [_unit] call BR_fnc_aiNewZoneSpot;
    };
};

// holding (not travelling): the engine decides about stance and cover; returns the time the hold started
BR_fnc_aiStartHold = {
    params ["_unit"];

    [_unit, false] call BR_fnc_aiSetTravelMode;
    _unit setUnitCombatMode "YELLOW";
    (group _unit) setCombatMode "YELLOW";

    private _since = _unit getVariable ["BR_var_aiHoldSince", -1];

    if (_since < 0) then {
        _since = time;
        _unit setVariable ["BR_var_aiHoldSince", _since];
    };

    _since
};

// a new spot in the next zone (cover, BR_fnc_aiZoneSpot)
BR_fnc_aiNewZoneSpot = {
    params ["_unit"];

    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];

    _unit setVariable ["BR_var_aiZoneDestination", [_unit, _nextCenter, _nextRadius] call BR_fnc_aiZoneSpot];
    _unit setVariable ["BR_var_aiHoldSince", -1];
};

/*
    Idle watchdog: an AI that did not move BR_var_aiIdleMoveDistance for BR_var_aiIdleTime gets a new task
    (BR_fnc_aiNewTask) - unless it is in a fight (checked before) or holds cover in the end phase. True if it got one.
*/
BR_fnc_aiCheckIdle = {
    params ["_unit", "_urgent"];

    private _lastPos = _unit getVariable ["BR_var_aiIdlePos", []];

    if (_lastPos isEqualTo [] || {_unit distance2D _lastPos > BR_var_aiIdleMoveDistance}) exitWith {
        _unit setVariable ["BR_var_aiIdlePos", getPosATL _unit];
        _unit setVariable ["BR_var_aiIdleSince", time];
        _unit setVariable ["BR_var_aiIdleCount", 0];
        false
    };

    if (time - (_unit getVariable ["BR_var_aiIdleSince", time]) < BR_var_aiIdleTime) exitWith {false};

    _unit setVariable ["BR_var_aiIdleSince", time];

    if ((_unit getVariable ["BR_var_aiHoldSince", -1]) >= 0 &&
        {(BR_var_zone select 5) < BR_var_aiEndPhaseRadius || {!([_unit] call BR_fnc_aiNeedsSupplies)}} &&
        {!([_unit] call BR_fnc_aiZoneUrgent)}) exitWith {false};

    private _count = (_unit getVariable ["BR_var_aiIdleCount", 0]) + 1;

    _unit setVariable ["BR_var_aiIdleCount", _count];

    // a new task did not get it going either (no way to the loot, wedged in): into the zone, freed from the spot
    if (_count >= BR_var_aiIdleUnstickCount) exitWith {
        _unit setVariable ["BR_var_aiIdleCount", 0];
        [_unit, true] call BR_fnc_aiNewTask;
        [_unit, [_unit] call BR_fnc_aiZoneDestination, BR_var_aiUnstickLastTry] call BR_fnc_aiUnstick;
        true
    };

    [_unit, _urgent] call BR_fnc_aiNewTask;
    true
};

// drops what kept the unit (loot building, crate, vehicle it waited for) and gives it a fresh purpose: the nearest
// building to loot while there is time, else a new spot in the zone
BR_fnc_aiNewTask = {
    params ["_unit", "_urgent"];

    if (!isNull (_unit getVariable ["BR_var_aiLootBuilding", objNull])) then {
        [_unit] call BR_fnc_aiEndLootRun;
    };

    // a supply crate stays the task (the user wants the AI to use them): only the way there is ordered anew
    private _crate = _unit getVariable ["BR_var_aiCrate", objNull];

    if (!_urgent && {!isNull _crate} && {[_crate] call BR_fnc_aiCrateWanted}) exitWith {
        doStop _unit;
        _unit setVariable ["BR_var_aiDestination", []];
    };

    if (!isNull _crate) then {
        [_unit, _crate] call BR_fnc_aiLeaveCrate;
    };

    if (!isNull (_unit getVariable ["BR_var_aiRideVehicle", objNull])) then {
        [_unit, _unit getVariable "BR_var_aiRideVehicle"] call BR_fnc_aiDropVehicle;
    };

    doStop _unit;
    _unit setVariable ["BR_var_aiDestination", []];

    private _building = if (_urgent) then {objNull} else {[_unit, BR_var_aiLootRadius] call BR_fnc_aiLootableBuilding};

    if (!isNull _building) exitWith {
        [_unit, _building] call BR_fnc_aiStartLootRun;
    };

    [_unit] call BR_fnc_aiNewZoneSpot;
};

// the unit's spot in the next zone (BR_fnc_aiZoneSpot), a new one whenever the zone changes
BR_fnc_aiZoneDestination = {
    params ["_unit"];

    BR_var_zone params ["_phase", "", "", "", "_nextCenter", "_nextRadius"];

    private _destination = _unit getVariable ["BR_var_aiZoneDestination", []];

    if (_destination isEqualTo [] || {(_unit getVariable ["BR_var_aiZonePhase", -1]) != _phase}) then {
        _destination = [_unit, _nextCenter, _nextRadius] call BR_fnc_aiZoneSpot;
        _unit setVariable ["BR_var_aiZoneDestination", _destination];
        _unit setVariable ["BR_var_aiZonePhase", _phase];
    };

    _destination
};

/*
    A land spot in the zone (_center, _radius) on the unit's side, within BR_var_aiZoneInnerShare of the radius: a short
    way now, and close enough to the center that the zone after it (anywhere inside this one) can be reached on foot.
    Then the best cover nearby (houses, trees, rocks rather than open ground) if it is still well inside the zone.
*/
BR_fnc_aiZoneSpot = {
    params ["_unit", "_center", "_radius"];

    private _innerRadius = _radius * ([BR_var_aiZoneInnerShare, BR_var_aiEndPhaseInnerShare] select (_radius < BR_var_aiEndPhaseRadius));
    private _spot = _center getPos [((_unit distance2D _center) min _innerRadius) *(0.5 + random 0.5),
        (_center getDir _unit) + random 40 - 20];

    _spot = [_spot, _innerRadius * BR_var_aiZoneSpotSpread] call BR_fnc_randomLandPos;

    // a zone split over several pieces of land: stay on the own piece if it holds a fair part of the zone's land, else
    // the largest piece (not the small one that merely lies on the unit's side and strands it at the water)
    private _landmass = [_unit, _center, _innerRadius] call BR_fnc_aiZoneLandmass;

    if (_landmass >= 0 && {([_spot] call BR_fnc_landmassNear) != _landmass}) then {
        _spot = [_spot, _landmass, _center, _innerRadius] call BR_fnc_landmassSpot;
    };

    private _cover = selectBestPlaces [_spot, BR_var_aiCoverSearchRadius, BR_var_aiCoverExpression, BR_var_aiCoverPrecision, 1];

    if (_cover isEqualTo []) exitWith {_spot};

    private _coverPos = [(_cover select 0) select 0] call BR_fnc_groundPos;

    [_spot, _coverPos] select (
        !surfaceIsWater _coverPos && {(_coverPos distance2D _center) < (_radius max BR_var_aiCoverSearchRadius)} &&
        {_landmass < 0 || {([_coverPos] call BR_fnc_landmassNear) == _landmass}}
    )
};

/*
    The landmass the unit's spot in the circle goes on (-1: unknown, any): its own if that holds at least
    BR_var_aiOwnLandmassShare of the largest piece's land in the circle, else the largest piece.
*/
BR_fnc_aiZoneLandmass = {
    params ["_unit", "_center", "_radius"];

    private _land = [_center, _radius] call BR_fnc_landmassesInCircle;

    if (_land isEqualTo []) exitWith {-1};

    private _largest = _land select 0;
    private _own = [_unit] call BR_fnc_landmassNear;
    private _ownEntry = _land select {(_x select 0) == _own};

    if (_ownEntry isNotEqualTo [] && {((_ownEntry select 0) select 1) >= BR_var_aiOwnLandmassShare * (_largest select 1)}) exitWith {_own};

    _largest select 0
};

/*
    Out of a fight: a first aid kit or medikit against the damage (zone, hits), through the same timed use as players
    (BR\items.sqf, user 2026-11-23): a medikit when badly hurt (BR_var_aiMedikitDamage), else a first aid kit (up to
    75 %), the other kit if the preferred one is missing or cannot help. True while the unit heals.
*/
BR_fnc_aiHeal = {
    params ["_unit"];

    if (_unit getVariable ["BR_var_bandaging", false]) exitWith {true};
    // also for hit legs alone (it limps: 65 % on the legs with 3 % overall was never healed)
    if ((damage _unit < BR_var_aiHealDamage && {(_unit getHitPointDamage "hitLegs") < BR_var_aiHealLegDamage}) ||
        {time < (_unit getVariable ["BR_var_aiNextHeal", 0])}) exitWith {false};

    private _kits = [BR_var_fakClass, BR_var_medikitClass];
    if (([_unit] call BR_fnc_injury) > BR_var_aiMedikitDamage) then {reverse _kits};
    private _kit = (_kits select {[_unit, _x] call BR_fnc_canUseItem}) param [0, ""];
    if (_kit == "") exitWith {false};

    _unit setVariable ["BR_var_aiNextHeal", time + BR_var_aiHealInterval];
    [_unit, _kit] call BR_fnc_startItemUse
};

// the unit is outside of the current circle
BR_fnc_aiOutsideZone = {
    params ["_unit"];

    ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];

    _unit distance2D _center > _radius
};

// ---- movement ----

/*
    Out of fights an AI travels upright and does not switch to COMBAT by itself: everyone is the enemy of a renegade, so
    COMBAT (careful pace, cover, lying down) would last all match long and the zone would outrun the AI. In a fight the
    engine decides again.
*/
BR_fnc_aiSetTravelMode = {
    params ["_unit", "_travel"];

    if ((_unit getVariable ["BR_var_aiTravelMode", !_travel]) isEqualTo _travel) exitWith {};

    _unit setVariable ["BR_var_aiTravelMode", _travel];
    _unit setVariable ["BR_var_aiFightOnTheMove", nil];

    if (_travel) then {
        // a target kept from the fight would stop it: it raises and lowers its weapon instead of walking
        _unit doTarget objNull;
        _unit doWatch objNull;
        _unit disableAI "AUTOTARGET";
        _unit disableAI "AUTOCOMBAT";
        (group _unit) setCombatBehaviour "AWARE";
        (group _unit) setSpeedMode "FULL";
        _unit setUnitPos "UP";

        // it runs: by itself an AI walks most of the way (half the speed; the zone outran it)
        _unit forceSpeed (_unit getSpeed "FAST");
    } else {
        _unit enableAI "AUTOTARGET";
        _unit enableAI "AUTOCOMBAT";
        (group _unit) setSpeedMode "NORMAL";
        _unit setUnitPos "AUTO";
        _unit forceSpeed -1;
    };
};

/*
    The engine's own rearming (from bodies and loot lying around) loops for good when the magazines do not fit into the
    inventory or cannot be reached, and the unit stands still. It cannot be switched off: cancelled, the engine starts it
    again at once next to the magazines and within 3 minutes from 60 m away, also in a new group (probe rp383). So after
    BR_var_aiRearmMaxTime the unit takes what it can use around it (BR_fnc_aiRearmNearby); a primary still without any
    round cannot be supplied here (machine gunners without vest or backpack stood up to 18 minutes): it is dropped, and
    the unit looks for a weapon it can supply (BR_fnc_aiSeekWeapon, BR_fnc_aiCanFeed) - without one there is nothing
    left to rearm. Cancelling at once while the unit had ammo made it worse: the engine restarted every tick, our
    doStop answered every tick, and the unit froze for the rest of the match.
*/
BR_fnc_aiCheckRearm = {
    params ["_unit"];

    if (currentCommand _unit != "REARM") exitWith {
        _unit setVariable ["BR_var_aiRearmSince", nil];
    };

    private _since = _unit getVariable ["BR_var_aiRearmSince", time];

    _unit setVariable ["BR_var_aiRearmSince", _since];

    if (time - _since < BR_var_aiRearmMaxTime) exitWith {};

    [_unit] call BR_fnc_aiRearmNearby;

    if (([_unit] call BR_fnc_aiPrimaryRounds) == 0) then {
        [_unit] call BR_fnc_aiDropPrimary;
    };

    doStop _unit;
    _unit setVariable ["BR_var_aiRearmSince", nil];
    _unit setVariable ["BR_var_aiOrderTime", -1e9];
};

// rounds for the primary weapon, loaded and carried (0 without one)
BR_fnc_aiPrimaryRounds = {
    params ["_unit"];

    private _rounds = 0;
    private _compatible = [primaryWeapon _unit] call BR_fnc_weaponMagazines;
    {
        if ((toLowerANSI (_x select 0)) in _compatible) then {_rounds = _rounds + (_x select 1)};
    } forEach ([getUnitLoadout _unit] call BR_fnc_aiLoadoutMagazines);

    _rounds
};

// the primary weapon (with its attachments) onto the ground: for anyone who can supply it, not this unit for a while
BR_fnc_aiDropPrimary = {
    params ["_unit"];

    private _weapon = (getUnitLoadout _unit) select 0;

    if (_weapon isEqualTo []) exitWith {};

    private _holder = [_unit] call BR_fnc_uniformGroundHolder;

    if (isNull _holder) exitWith {};

    _holder addWeaponWithAttachmentsCargoGlobal [_weapon, 1];
    _unit removeWeapon (_weapon select 0);
    _holder setVariable ["BR_var_aiRetryAfter", time + BR_var_aiDroppedRetry];
};

/*
    Orders a move unless about the same destination was ordered a moment ago: every doMove makes the unit stop and plan
    its way again, so a destination that moves (leader, enemy) is only ordered anew when it moved noticeably. With
    _watchProgress a unit that makes no progress gets a recovery order instead (BR_fnc_aiCheckStuck).
*/
BR_fnc_aiMoveTo = {
    params ["_unit", "_destination", ["_watchProgress", true]];

    // on its way (not in a fight: those moves do not watch the progress): travel mode, no longer holding
    if (_watchProgress) then {
        [_unit, true] call BR_fnc_aiSetTravelMode;
        _unit setVariable ["BR_var_aiHoldSince", -1];
    };

    if (_watchProgress && {[_unit, _destination] call BR_fnc_aiCheckStuck}) exitWith {};

    private _lastDestination = _unit getVariable ["BR_var_aiDestination", []];
    private _leg = _unit getVariable ["BR_var_aiLeg", []];

    if (
        _lastDestination isNotEqualTo [] &&
        {(_lastDestination distance2D _destination) < (2 max (BR_var_aiReorderShare * (_unit distance2D _destination)))} &&
        {time - (_unit getVariable ["BR_var_aiOrderTime", 0]) < BR_var_aiOrderRepeatTime} &&
        {_leg isEqualTo [] || {_unit distance2D _leg > BR_var_aiLegReach}}
    ) exitWith {};

    private _target = [_unit, _destination, BR_var_aiLegLength] call BR_fnc_aiLegTarget;

    _unit doMove _target;
    _unit setVariable ["BR_var_aiLeg", [_target, []] select (_target isEqualTo _destination)];
    _unit setVariable ["BR_var_aiDestination", _destination];
    _unit setVariable ["BR_var_aiOrderTime", time];
};

/*
    The point _length along the way to a far destination, on land (_onWater: on water), turned aside if the straight
    leg ends on the wrong ground; the destination itself when it is closer. The engine plans no way over kilometres: a
    unit (or a car) ordered that far just stands - and every new order starts the planning again.
*/
BR_fnc_aiLegTarget = {
    params ["_unit", "_destination", "_length", ["_onWater", false]];

    if (_unit distance2D _destination <= _length) exitWith {_destination};

    private _direction = _unit getDir _destination;
    private _target = [];

    {
        private _pos = _unit getPos [_length, _direction + _x];

        if ((surfaceIsWater _pos) isEqualTo _onWater) exitWith {
            _target = _pos;
        };
    } forEach BR_var_aiLegTurns;

    if (_target isEqualTo []) then {
        _target = _unit getPos [_length, _direction];
    };

    [_target] call BR_fnc_groundPos
};

// true if the unit made no progress on its way for BR_var_aiStuckTime and got a recovery order (BR_fnc_aiUnstick)
BR_fnc_aiCheckStuck = {
    params ["_unit", "_destination"];

    private _lastCheck = _unit getVariable ["BR_var_aiStuckCheck", -1e9];
    private _progressPos = _unit getVariable ["BR_var_aiProgressPos", []];
    private _moved = _progressPos isNotEqualTo [] && {_unit distance2D _progressPos > BR_var_aiStuckDistance};

    _unit setVariable ["BR_var_aiStuckCheck", time];

    if (_moved) then {
        _unit setVariable ["BR_var_aiStuckTries", 0];
    };

    // progress, or the first order after a pause: the measurement starts again here
    if (_moved || {time - _lastCheck > BR_var_aiStuckCheckGap}) exitWith {
        _unit setVariable ["BR_var_aiProgressPos", getPosATL _unit];
        _unit setVariable ["BR_var_aiProgressTime", time];
        false
    };

    if (time - (_unit getVariable ["BR_var_aiProgressTime", time]) < BR_var_aiStuckTime) exitWith {false};
    if (_unit distance2D _destination < BR_var_aiStuckIgnoreDistance) exitWith {false};

    private _tries = (_unit getVariable ["BR_var_aiStuckTries", 0]) + 1;

    _unit setVariable ["BR_var_aiStuckTries", _tries];
    _unit setVariable ["BR_var_aiProgressPos", getPosATL _unit];
    _unit setVariable ["BR_var_aiProgressTime", time];
    [_unit, _destination, _tries] call BR_fnc_aiUnstick;
    true
};

/*
    Some small buildings catch an AI that walked in to loot (slum and cargo houses, ruins, some u_/i_ houses on Altis:
    3-6 per match stood there until the zone killed them). Nothing the engine offers gets it out again - doMove, direct
    planning, moveTo, a forced replan, the building's exit, nearer building positions, open doors (probes tp384/tp387: 9
    of 10 spots stayed shut). So an AI ordered on its way that did not move BR_var_aiTrapDistance for BR_var_aiTrapTime
    inside a building is put on the nearest free spot outside of it (user 2026-11-23: put it out and learn), and the
    building is closed to AI looting for the rest of the match (BR_var_aiTrap: no more AI goes in; players loot it as
    before). True if the unit was put out.
*/
BR_fnc_aiCheckTrapped = {
    params ["_unit"];

    private _pos = _unit getVariable ["BR_var_aiTrapPos", []];
    private _lastCheck = _unit getVariable ["BR_var_aiTrapCheck", time];

    _unit setVariable ["BR_var_aiTrapCheck", time];

    if (_pos isEqualTo [] || {_unit distance2D _pos > BR_var_aiTrapDistance}) exitWith {
        _unit setVariable ["BR_var_aiTrapPos", getPosATL _unit];
        _unit setVariable ["BR_var_aiTrapWait", 0];
        false
    };

    // only the time in which it should have moved counts: on its way with a fresh order, or rearming (walking to the
    // magazines; BR_fnc_aiCheckRearm cancels it now and then, which must not start the count again)
    private _destination = _unit getVariable ["BR_var_aiDestination", []];
    private _ordered = currentCommand _unit == "REARM" || {
        _unit getVariable ["BR_var_aiTravelMode", false] &&
        {_destination isNotEqualTo []} && {_unit distance2D _destination > BR_var_aiStuckIgnoreDistance} &&
        {time - (_unit getVariable ["BR_var_aiOrderTime", -1e9]) < BR_var_aiTrapOrderAge}
    };

    if (!_ordered) exitWith {false};

    private _wait = (_unit getVariable ["BR_var_aiTrapWait", 0]) + ((time - _lastCheck) min (2 * BR_var_aiFarTickInterval));

    _unit setVariable ["BR_var_aiTrapWait", _wait];

    if (_wait < BR_var_aiTrapTime) exitWith {false};

    _unit setVariable ["BR_var_aiTrapWait", 0];

    private _building = [_unit] call BR_fnc_aiEnclosingBuilding;
    // not in a building: walls, sandbags or wire around it in the open (a sandbag square of a DayZ site held an AI for
    // 6 minutes, its mate waiting beside it - PC test pd22): out to the nearest free spot towards its destination
    private _exit = if (isNull _building) then {[_unit, _destination] call BR_fnc_aiOpenTrapExit} else {
        [_unit, _building] call BR_fnc_aiTrapExit
    };

    if (_exit isEqualTo []) exitWith {false};

    if (!isNull _building) then {[_building, "BR_var_aiTrap", true] call BR_fnc_bSet};

    // its loot run ends with the building it was caught in; caught in the open, the run that led it there ends too
    private _runBuilding = _unit getVariable ["BR_var_aiLootBuilding", objNull];
    if (!isNull _runBuilding && {isNull _building || {_runBuilding isEqualTo _building}}) then {
        [_unit] call BR_fnc_aiEndLootRun;
    };

    doStop _unit;
    _unit setVehiclePosition [_exit, [], 0, "NONE"];
    _unit setVariable ["BR_var_aiTrapPos", getPosATL _unit];
    _unit setVariable ["BR_var_aiDestination", []];
    _unit setVariable ["BR_var_aiOrderTime", -1e9];
    _unit setVariable ["BR_var_aiStuckTries", 0];
    true
};

// the building whose bounds the unit stands in (objNull if none)
BR_fnc_aiEnclosingBuilding = {
    params ["_unit"];

    private _pos = getPosATL _unit;
    // houses only: loot holders and crates are "Building" in the config too
    private _buildings = (nearestObjects [_unit, ["House"], 30]) select {
        (boundingBoxReal _x) params ["_min", "_max"];
        private _local = _x worldToModel _pos;

        (_local select 0) > (_min select 0) && {(_local select 0) < (_max select 0)} &&
        {(_local select 1) > (_min select 1)} && {(_local select 1) < (_max select 1)}
    };

    _buildings param [0, objNull]
};

// the nearest free land spot outside of the building's bounds, around the unit ([] if none)
BR_fnc_aiTrapExit = {
    params ["_unit", "_building"];

    (boundingBoxReal _building) params ["_min", "_max"];

    private _exit = [];

    for "_radius" from 2 to BR_var_aiTrapExitRadius step 2 do {
        {
            private _spot = _unit getPos [_radius, _x];
            private _local = _building worldToModel _spot;

            if (
                ((_local select 0) < (_min select 0) - 1 || {(_local select 0) > (_max select 0) + 1} ||
                {(_local select 1) < (_min select 1) - 1} || {(_local select 1) > (_max select 1) + 1}) &&
                {!surfaceIsWater _spot}
            ) then {
                private _free = _spot findEmptyPosition [0, 2, typeOf _unit];

                if (_free isNotEqualTo [] && {_exit isEqualTo []}) then {_exit = _free};
            };
        } forEach [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];

        if (_exit isNotEqualTo []) exitWith {};
    };

    _exit
};

// caught in the open (BR_fnc_aiCheckTrapped): a free land spot BR_var_aiOpenTrapExit away, the direction to its
// destination first, then turning further aside ([] if none)
BR_fnc_aiOpenTrapExit = {
    params ["_unit", "_destination"];

    private _towards = if (_destination isEqualTo []) then {getDir _unit} else {_unit getDir _destination};
    private _exit = [];

    {
        private _radius = _x;
        {
            private _spot = _unit getPos [_radius, _towards + _x];
            if (!surfaceIsWater _spot) then {
                private _free = _spot findEmptyPosition [0, 2, typeOf _unit];
                if (_free isNotEqualTo [] && {_exit isEqualTo []}) then {_exit = _free};
            };
            if (_exit isNotEqualTo []) exitWith {};
        } forEach [0, 30, -30, 60, -60, 90, -90, 135, -135, 180];
        if (_exit isNotEqualTo []) exitWith {};
    // swimming in a harbour basin it cannot climb out of (Tanoa port, 10 minutes on one spot - pd66): land farther away
    } forEach ([BR_var_aiOpenTrapExit, BR_var_aiWaterTrapExit] select (surfaceIsWater getPosATL _unit));

    _exit
};

// Replan, then try walking around obstacles (a unit caught in a building: BR_fnc_aiCheckTrapped).
BR_fnc_aiUnstick = {
    params ["_unit", "_destination", "_tries"];

    private _orderTo = _destination;

    switch (_tries) do {
        case 1: {
            doStop _unit;
        };
        case 2: {
            _orderTo = _unit getPos [BR_var_aiDetourDistance, (_unit getDir _destination) + selectRandom [-70, 70]];
        };
        default {
            private _freePos = (getPosATL _unit) findEmptyPosition [2, BR_var_aiUnstickRadius, typeOf _unit];

            if (_freePos isNotEqualTo [] && {!surfaceIsWater _freePos}) then {
                _orderTo = _freePos;
            };
            // the loot target it cannot get to is given up as a whole: the engine found no way to a building's holders
            // (army tents behind the razor wire of a DayZ compound, a squad in the spruce thicket beside it - PC test
            // pd25: 3 AI tried holder after holder of the same tents for 8 minutes)
            if (!isNull (_unit getVariable ["BR_var_aiLootBuilding", objNull])) then {[_unit] call BR_fnc_aiEndLootRun};
            private _loose = _unit getVariable ["BR_var_aiLooseLoot", objNull];
            if (!isNull _loose) then {
                _loose setVariable ["BR_var_aiRetryAfter", time + BR_var_aiWeaponSeekRetry];
                _unit setVariable ["BR_var_aiLooseLoot", objNull];
            };
            _unit setVariable ["BR_var_aiStuckTries", 0];
        };
    };

    // the real destination counts as ordered: BR_fnc_aiMoveTo leaves a detour alone for BR_var_aiOrderRepeatTime
    _orderTo = [_unit, _orderTo, BR_var_aiLegLength] call BR_fnc_aiLegTarget;
    _unit doMove _orderTo;
    _unit setVariable ["BR_var_aiLeg", _orderTo];
    _unit setVariable ["BR_var_aiDestination", _destination];
    _unit setVariable ["BR_var_aiOrderTime", time];
};
