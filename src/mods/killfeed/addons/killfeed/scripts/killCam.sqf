// Killfeed kill cam (client): after the own death by another unit (with a revive system: already when going down,
// KF_fnc_killCamDowned) the view flies from where it is to the killer (his vehicle, the UAV) and orbits him for a few
// seconds, his name and rank above him; Space skips it. The respawn timer keeps running meanwhile; game modes start
// their death screens after it (KF_fnc_waitUntilKillCamDone, the scripted event "KF_killCamDone").
// Included by fnc_client.sqf.

// ---- settings ----
// Defaults; the module and the game modes set them on the server before KF_fnc_startKillfeed, which publishes them.

if (isNil "KF_var_killCamEnabled") then {KF_var_killCamEnabled = true;};
if (isNil "KF_var_killCamMinDistance") then {KF_var_killCamMinDistance = 0;};        // m: the killer's distance at the death,
if (isNil "KF_var_killCamMaxDistance") then {KF_var_killCamMaxDistance = 300;};      // outside of it no kill cam
if (isNil "KF_var_killCamFlightDuration") then {KF_var_killCamFlightDuration = [1, 2.5];};   // s: shortest, longest flight
if (isNil "KF_var_killCamHoldDuration") then {KF_var_killCamHoldDuration = 5;};      // s on the killer
if (isNil "KF_var_killCamRequireLineOfSight") then {KF_var_killCamRequireLineOfSight = false;};   // victim could see him
if (isNil "KF_var_killCamTeamKills") then {KF_var_killCamTeamKills = true;};
if (isNil "KF_var_killCamAirMaxHeight") then {KF_var_killCamAirMaxHeight = 300;};    // m: none for an aircraft higher up
if (isNil "KF_var_killCamIndirectKills") then {KF_var_killCamIndirectKills = false;};   // mortars, artillery, explosives
if (isNil "KF_var_killCamOnRoundEnd") then {KF_var_killCamOnRoundEnd = false;};      // also once the round is over
if (isNil "KF_var_killCamSkipKey") then {KF_var_killCamSkipKey = 57;};               // DIK code (Space)
// the end of the kill cam after a death, always through black (never a cut to the own body): "black" stays black for
// the death transition (KF_var_deathTransition) of the game mode; "body" fades in at the own body, after
// KF_var_killCamBodyTime to black again and in with the respawn menu (SC)
if (isNil "KF_var_killCamOutro") then {KF_var_killCamOutro = "black";};

// hooks of the game modes (code run on the client)
if (isNil "KF_fnc_killCamCanShow") then {KF_fnc_killCamCanShow = {true};};     // [victim, killer, target]: false blocks it
if (isNil "KF_fnc_killCamRoundOver") then {KF_fnc_killCamRoundOver = {false};}; // true while the round is over
if (isNil "KF_fnc_killCamRank") then {KF_fnc_killCamRank = {""};};             // [unit]: rank before the name, "" for none

// ---- tuning ----

KF_var_killCamStartDelay = [1, 3];            // s after the death: earliest and latest start
KF_var_killCamSettleSpeed = 0.15;             // m/s: the view counts as settled (body at rest) below this movement,
KF_var_killCamSettleTurnRate = 4;             // deg/s: this turn rate
KF_var_killCamSettleFrames = 3;               // and for this many frames in a row
KF_var_killCamFlightSpeed = 50;               // m/s: flight duration = path length / this, within the flight duration
KF_var_killCamTurnShare = 0.5;                // share of the flight in which the camera turns towards the killer
KF_var_killCamMinFov = 0.6;                   // the flight zooms out to at least this field of view (killed while aiming)
KF_var_killCamPathRadius = 0.4;               // m: safety radius of the flight path (four parallel rays)
KF_var_killCamPathTaper = 1.5;                // m from the start over which that radius grows (the view starts at the ground)
KF_var_killCamPathSamples = 16;               // segments of a curved flight path checked for collisions
KF_var_killCamClimbHeights = [3, 6, 10, 16, 25, 40];   // m above the higher end of the flight: over an obstacle
KF_var_killCamFadeDuration = 0.3;             // s: fade through black when no flight path is free
KF_var_killCamUnitDistances = [7, 5.5, 4, 2.5];        // m: camera positions around a killer on foot
KF_var_killCamVehicleDistances = [8, 6, 4.5];          // m: around a vehicle, plus its radius times the next factor
KF_var_killCamVehicleDistanceFactor = 0.8;
KF_var_killCamAngles = [180, 150, 210, 120, 240, 90, 270, 60, 300, 30, 330, 0];   // deg relative to his direction
KF_var_killCamUnitHeight = 0.5;               // m above the chest of a unit (head height)
KF_var_killCamVehicleHeight = 1;              // m above the top of a vehicle
KF_var_killCamExtraHeight = 2.5;              // m higher positions when the level ones are blocked
KF_var_killCamClearance = 0.6;                // m free around a camera position
KF_var_killCamClearanceDirs = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1]];
KF_var_killCamViewMargin = 0.5;               // m behind a camera position that must see the killer as well
KF_var_killCamMinHeight = 1;                  // m above the terrain or the sea
KF_var_killCamOrbitSpeed = 10;                // deg/s around the killer
KF_var_killCamOrbitSmoothing = 2;             // 1/s: how fast the orbit speed follows a start or a change of direction
KF_var_killCamRadiusSmoothing = 6;            // 1/s: how fast the orbit radius follows a change
KF_var_killCamOrbitRadii = [1, 0.75, 0.5];    // shares of the orbit radius tried when the orbit ahead is blocked
KF_var_killCamMinOrbitRadius = 2;             // m
KF_var_killCamOrbitCheckInterval = 0.2;       // s between two collision checks of the orbit
KF_var_killCamOrbitLookAhead = 1;             // s of orbit checked ahead
KF_var_killCamRelocateInterval = 1;           // s: at most one jump to a new spot per this time
KF_var_killCamRespawnReserve = 1;             // s: the respawn timer is held at least this high while the kill cam runs
KF_var_killCamMenuTimeout = 5;                // s to wait for the vanilla respawn menu after the kill cam
KF_var_killCamKeyReleaseTimeout = 3;          // s to wait for the release of the skip key
KF_var_killCamIconHeight = 0.5;               // m: the name above the head or the vehicle
KF_var_killCamTextSizeCells = 1;              // size of the name in GUI grid cells

// the fixed side palette of the 3D icons (tdicons)
KF_var_killCamSideColors = createHashMapFromArray [
    [west, [0, 0.5, 1, 1]],
    [east, [1, 0, 0, 1]],
    [independent, [0, 0.8, 0.27, 1]]
];
KF_var_killCamOtherSideColor = [0.75, 0.75, 0.75, 1];

KF_var_killCamActive = false;     // from the own death until the kill cam is over (game modes wait for it)
KF_var_killCam = createHashMap;   // the state of the current kill cam

// ---- game mode interface ----

// scheduled: returns once no kill cam is pending or running (at once if there is none)
KF_fnc_waitUntilKillCamDone = {
    waitUntil {!KF_var_killCamActive};
};

// server -> victim: whether the kill was made with placed explosives or artillery (the server knows the killer's hits)
KF_fnc_setKillCamIndirect = {
    params ["_isIndirect"];

    if (KF_var_killCamActive && {!(KF_var_killCam get "shown")}) then {
        KF_var_killCam set ["indirect", _isIndirect];
    };
};

// ---- the kill ----

// [camera target, killer] of a kill, [] for none (suicide, environment, fall, zone, explosives without an owner):
// a UAV kill shows the UAV with its operator's name, a killer in a vehicle the vehicle
KF_fnc_killCamTarget = {
    params ["_victim", "_killer", "_instigator"];

    private _killerVehicle = vehicle _killer;

    if (unitIsUAV _killerVehicle) exitWith {
        private _operator = _instigator;

        if (isNull _operator || {(vehicle _operator) isEqualTo _killerVehicle}) then {
            _operator = [_killerVehicle, gunner _killerVehicle] call KF_fnc_getUavOperator;
        };

        if (_operator isEqualTo _victim) exitWith {[]};

        [_killerVehicle, _operator]
    };

    private _person = _instigator;

    // road kills come without instigator
    if (isNull _person) then {
        _person = if (_killer isKindOf "CAManBase") then {
            _killer
        } else {
            [driver _killer, effectiveCommander _killer] select (isNull driver _killer)
        };
    };

    if (isNull _person || {_person isEqualTo _victim} || {(vehicle _person) isEqualTo (vehicle _victim)}) exitWith {[]};

    [vehicle _person, _person]
};

// friendly fire: same side, unless the victim was a renegade (as the killfeed counts it)
KF_fnc_killCamIsTeamKill = {
    params ["_killer", "_victim"];

    ((side group _killer) == (side group _victim)) && {(rating _victim) >= -2000}
};

// the options and the game mode's hooks at the moment of the death
KF_fnc_killCamAllowed = {
    params ["_victim", "_target", "_person"];

    private _distance = _victim distance _target;

    (_distance >= KF_var_killCamMinDistance) &&
    {_distance <= KF_var_killCamMaxDistance} &&
    {KF_var_killCamTeamKills || {!([_person, _victim] call KF_fnc_killCamIsTeamKill)}} &&
    {!(_target isKindOf "Air") || {((getPos _target) select 2) <= KF_var_killCamAirMaxHeight}} &&
    {KF_var_killCamIndirectKills || {(getNumber (configOf _target >> "artilleryScanner")) != 1}} &&
    {!KF_var_killCamRequireLineOfSight || {([vehicle _victim, "VIEW", _target] checkVisibility [eyePos _victim, aimPos _target]) > 0}} &&
    {KF_var_killCamOnRoundEnd || {!(call KF_fnc_killCamRoundOver)}} &&
    {[_victim, _person, _target] call KF_fnc_killCamCanShow}
};

// "[rank] name" of the killer
KF_fnc_killCamLabel = {
    params ["_person"];

    private _name = _person getVariable ["KF_var_name", name _person];
    private _rank = [_person] call KF_fnc_killCamRank;

    if (_rank isEqualTo "") exitWith {_name};

    format ["[%1] %2", _rank, _name]
};

// down (unconscious) in a revive system: AIS or the vanilla revive
KF_fnc_killCamIsDown = {
    params ["_unit"];

    (_unit getVariable ["AIS_unconscious", false]) || {(lifeState _unit) == "INCAPACITATED"}
};

// "EntityKilled": a kill cam for the own death, decided at once (the vanilla respawn menu opens in this frame). The
// death of a player who is down gets none when his going down had one (KF_fnc_killCamDowned); one of those still
// running (he was finished off meanwhile) goes on and now holds the respawn menu.
KF_fnc_killCamEntityKilled = {
    params ["_unit", "_killer", "_instigator"];

    if (_unit isNotEqualTo player) exitWith {};

    if ([_unit] call KF_fnc_killCamIsDown && {_unit getVariable ["KF_var_killCamDowned", false]}) exitWith {
        if (KF_var_killCamActive && {(KF_var_killCam get "victim") isEqualTo _unit} && {!(KF_var_killCam getOrDefault ["finishing", false])}) then {
            call KF_fnc_killCamHoldRespawnMenu;
        };
    };

    [_unit, _killer, _instigator] call KF_fnc_killCamTrigger;
};

// Called by the game mode's revive system on the player's machine when the player goes down (AIS: SC): the kill cam
// shows who downed him, as at a death; the revive system starts its own unconscious view and HUD after it.
KF_fnc_killCamDowned = {
    params ["_unit", "_killer", "_instigator"];

    if (_unit isNotEqualTo player) exitWith {};

    _unit setVariable ["KF_var_killCamDowned", [_unit, _killer, _instigator] call KF_fnc_killCamTrigger];
};

// decides and starts a kill cam for the player's death or going down; returns true if one starts
KF_fnc_killCamTrigger = {
    params ["_unit", "_killer", "_instigator"];

    if (KF_var_killCamActive || {!KF_var_killCamEnabled}) exitWith {false};

    ([_unit, _killer, _instigator] call KF_fnc_killCamTarget) params [["_target", objNull], ["_person", objNull]];

    if (isNull _target || {!([_unit, _target, _person] call KF_fnc_killCamAllowed)}) exitWith {false};

    (boundingBoxReal _target) params ["_boxMin", "_boxMax"];

    private _center = (_boxMin vectorAdd _boxMax) vectorMultiply 0.5;

    KF_var_killCamActive = true;
    KF_var_killCam = createHashMapFromArray [
        ["victim", _unit],
        ["killer", _killer],
        ["target", _target],
        ["person", _person],
        ["isUnit", _target isKindOf "CAManBase"],
        ["targetCenter", _center],
        ["iconOffset", [_center select 0, _center select 1, (_boxMax select 2) + KF_var_killCamIconHeight]],
        ["deathTime", time],
        ["label", [_person] call KF_fnc_killCamLabel],
        ["color", KF_var_killCamSideColors getOrDefault [side group _person, KF_var_killCamOtherSideColor]],
        ["phase", ""],
        ["shown", false],
        ["skip", false],
        ["keyHeld", false],
        ["indirect", false],
        ["menuTemplates", []]
    ];

    if (!alive _unit) then {
        call KF_fnc_killCamHoldRespawnMenu;
    };

    call KF_fnc_killCamAddKeyHandlers;
    [] spawn KF_fnc_runKillCam;
    true
};

// the kill cam has to stop: skipped, respawned (another player unit), revived, the killer is gone, an indirect kill,
// the round is over, mission end
KF_fnc_killCamShouldStop = {
    private _victim = KF_var_killCam get "victim";

    (KF_var_killCam get "skip") ||
    {player isNotEqualTo _victim} ||
    {alive _victim && {!([_victim] call KF_fnc_killCamIsDown)}} ||
    {isNull (KF_var_killCam get "target")} ||
    {isNull findDisplay 46} ||
    {!KF_var_killCamIndirectKills && {KF_var_killCam get "indirect"}} ||
    {!KF_var_killCamOnRoundEnd && {call KF_fnc_killCamRoundOver}}
};

// ---- respawn: timer and vanilla respawn menu ----
// The engine respawns a dead player when the respawn timer runs out, so it is held at KF_var_killCamRespawnReserve
// while the kill cam runs. The vanilla respawn menu (templates MenuPosition / MenuInventory) opens at the death unless
// the dead unit has BIS_fnc_showRespawnMenu_disable (a3\functions_f\Respawn\fn_respawnMenuPosition.sqf); it is held
// that way and opened after the kill cam with the templates' own functions. Variables of a unit are copied to its
// respawned unit, so the variable is always removed before the respawn.

KF_fnc_killCamHoldRespawnTimer = {
    if (!alive player && {playerRespawnTime < KF_var_killCamRespawnReserve}) then {
        setPlayerRespawnTime KF_var_killCamRespawnReserve;
    };
};

// the templates of the vanilla respawn menu the mission uses (as BIS_fnc_selectRespawnTemplate reads them)
KF_fnc_killCamMenuTemplates = {
    if !((0 call BIS_fnc_missionRespawnType) in [2, 3]) exitWith {[]};

    private _templates = getMissionConfigValue ["respawnTemplates" + str (side group player), getMissionConfigValue ["respawnTemplates", []]];

    if !(_templates isEqualType []) then {
        _templates = [_templates];
    };

    _templates select {_x in ["MenuPosition", "MenuInventory"]}
};

KF_fnc_killCamHoldRespawnMenu = {
    private _templates = call KF_fnc_killCamMenuTemplates;

    if (_templates isEqualTo []) exitWith {};

    (KF_var_killCam get "victim") setVariable ["BIS_fnc_showRespawnMenu_disable", true];
    KF_var_killCam set ["menuTemplates", _templates];
};

// Scheduled: opens the held menu as the templates do at the death, while the player is still dead. After a shown kill
// cam without the vanilla pause and black screen before the map (the kill cam took that time). Returns once the map
// is open.
KF_fnc_killCamOpenRespawnMenu = {
    private _templates = KF_var_killCam get "menuTemplates";

    if (_templates isEqualTo []) exitWith {};

    private _victim = KF_var_killCam get "victim";

    _victim setVariable ["BIS_fnc_showRespawnMenu_disable", nil];
    KF_var_killCam set ["menuTemplates", []];

    if (alive player) exitWith {};

    private _skipPause = KF_var_killCam get "shown";
    private _args = [_victim, KF_var_killCam get "killer", 0 call BIS_fnc_missionRespawnType, getMissionConfigValue ["respawnDelay", 0]];

    if (_skipPause) then {
        uiNamespace setVariable ["BIS_RscRespawnControls_skipBlackOut", true];
    };

    {
        _args spawn (missionNamespace getVariable ["BIS_fnc_respawn" + _x, {}]);
    } forEach _templates;

    private _timeout = time + KF_var_killCamMenuTimeout;

    waitUntil {
        call KF_fnc_killCamHoldRespawnTimer;
        (alive player) || {missionNamespace getVariable ["BIS_RscRespawnControlsMap_shown", false]} || {time > _timeout}
    };

    if (_skipPause) then {
        uiNamespace setVariable ["BIS_RscRespawnControls_skipBlackOut", nil];
    };
};

// "EntityRespawned": a respawn forced while the menu is held - the new unit got the variable of the old one
KF_fnc_killCamEntityRespawned = {
    params ["_newEntity", "_oldEntity"];

    if (!KF_var_killCamActive || {_newEntity isNotEqualTo player} || {(KF_var_killCam get "menuTemplates") isEqualTo []}) exitWith {};

    {
        _x setVariable ["BIS_fnc_showRespawnMenu_disable", nil];
    } forEach [_newEntity, _oldEntity];

    KF_var_killCam set ["menuTemplates", []];
};

// ---- skip key ----
// Consumed while the kill cam runs; the end waits for its release, so it can't reach a "press space" of the game mode.

KF_fnc_killCamAddKeyHandlers = {
    private _display = findDisplay 46;

    KF_var_killCam set ["keyHandlers", [
        _display displayAddEventHandler ["KeyDown", {_this call KF_fnc_killCamKeyDown}],
        _display displayAddEventHandler ["KeyUp", {_this call KF_fnc_killCamKeyUp}]
    ]];
};

KF_fnc_killCamKeyDown = {
    params ["", "_key"];

    if (_key != KF_var_killCamSkipKey) exitWith {false};

    KF_var_killCam set ["skip", true];
    KF_var_killCam set ["keyHeld", true];
    true
};

KF_fnc_killCamKeyUp = {
    params ["", "_key"];

    if (_key == KF_var_killCamSkipKey) then {
        KF_var_killCam set ["keyHeld", false];
    };

    false
};

// ---- camera math ----

// smootherstep: eased progress 0..1 without a jerk at either end
KF_fnc_killCamEase = {
    params ["_t"];

    _t = (_t max 0) min 1;
    _t * _t * _t * (_t * (6 * _t - 15) + 10)
};

// cubic Bezier curve through the control points [p0, p1, p2, p3] (ASL) at _t
KF_fnc_killCamBezier = {
    params ["_points", "_t"];
    _points params ["_p0", "_p1", "_p2", "_p3"];

    private _u = 1 - _t;

    ((_p0 vectorMultiply (_u * _u * _u)) vectorAdd (_p1 vectorMultiply (3 * _u * _u * _t))) vectorAdd
        ((_p2 vectorMultiply (3 * _u * _t * _t)) vectorAdd (_p3 vectorMultiply (_t * _t * _t)))
};

// [yaw, pitch] in degrees of a direction (pitch within +-89, where the yaw stays defined)
KF_fnc_killCamYawPitch = {
    params ["_dir"];

    _dir = vectorNormalized _dir;

    [(_dir select 0) atan2 (_dir select 1), ((asin (((_dir select 2) max -1) min 1)) max -89) min 89]
};

// [direction, up] of a camera with yaw, pitch and roll in degrees
KF_fnc_killCamOrientation = {
    params ["_yaw", "_pitch", ["_roll", 0]];

    private _dir = [(sin _yaw) * (cos _pitch), (cos _yaw) * (cos _pitch), sin _pitch];
    private _up = [-(sin _yaw) * (sin _pitch), -(cos _yaw) * (sin _pitch), cos _pitch];

    if (_roll != 0) then {
        _up = (_up vectorMultiply (cos _roll)) vectorAdd ((_dir vectorCrossProduct _up) vectorMultiply (sin _roll));
    };

    [_dir, _up]
};

// [yaw, pitch, roll] of a camera direction and up vector
KF_fnc_killCamAngles = {
    params ["_dir", "_up"];

    ([_dir] call KF_fnc_killCamYawPitch) params ["_yaw", "_pitch"];
    ([_yaw, _pitch] call KF_fnc_killCamOrientation) params ["_levelDir", "_levelUp"];

    private _right = _levelDir vectorCrossProduct _levelUp;

    [_yaw, _pitch, (_up vectorDotProduct _right) atan2 (_up vectorDotProduct _levelUp)]
};

// the shortest turn from one yaw to another, -180..180
KF_fnc_killCamAngleDiff = {
    params ["_from", "_to"];

    ((_to - _from + 540) mod 360) - 180
};

// the point the camera looks at (ASL, render time): between head and pelvis of a unit, the middle of a vehicle
KF_fnc_killCamLookPoint = {
    params ["_target"];

    if (KF_var_killCam get "isUnit") exitWith {
        _target modelToWorldVisualWorld (((_target selectionPosition "head") vectorAdd (_target selectionPosition "pelvis")) vectorMultiply 0.5)
    };

    _target modelToWorldVisualWorld (KF_var_killCam get "targetCenter")
};

// where the name is drawn (ASL, render time)
KF_fnc_killCamIconPoint = {
    params ["_target"];

    if (KF_var_killCam get "isUnit") exitWith {
        _target modelToWorldVisualWorld ((_target selectionPosition "head") vectorAdd [0, 0, KF_var_killCamIconHeight])
    };

    _target modelToWorldVisualWorld (KF_var_killCam get "iconOffset")
};

// at least KF_var_killCamMinHeight above the terrain and the sea
KF_fnc_killCamLiftPos = {
    params ["_pos"];

    private _floor = ((getTerrainHeightASL _pos) max 0) + KF_var_killCamMinHeight;

    [_pos select 0, _pos select 1, (_pos select 2) max _floor]
};

KF_fnc_killCamOrbitPos = {
    params ["_look", "_angle", "_radius", "_height"];

    [_look vectorAdd [(sin _angle) * _radius, (cos _angle) * _radius, _height]] call KF_fnc_killCamLiftPos
};

// ---- collision checks (at the start and a few times per second, never per frame) ----

KF_fnc_killCamIsLineFree = {
    params ["_from", "_to", ["_ignore1", objNull], ["_ignore2", objNull]];

    !(terrainIntersectASL [_from, _to]) &&
    {(lineIntersectsSurfaces [_from, _to, _ignore1, _ignore2, true, 1, "VIEW", "GEOM"]) isEqualTo []}
};

// _from (ASL) sees the target at _look: the first surface on the way belongs to the target (a vehicle: also its crew)
KF_fnc_killCamSeesTarget = {
    params ["_from", "_look"];

    if (terrainIntersectASL [_from, _look]) exitWith {false};

    private _hits = lineIntersectsSurfaces [_from, _look, objNull, objNull, true, 1, "VIEW", "GEOM"];

    if (_hits isEqualTo []) exitWith {true};

    (_hits select 0) params ["", "", "_object", "_parent"];

    (KF_var_killCam get "target") in [_object, _parent, objectParent _object]
};

// a camera position (ASL) that sees the target also from KF_var_killCamViewMargin further out and has room around it
// (as VA_fnc_isCameraViewFree of the arsenal camera)
KF_fnc_killCamIsCameraPosFree = {
    params ["_pos", "_look"];

    private _outer = _pos vectorAdd ((vectorNormalized (_pos vectorDiff _look)) vectorMultiply KF_var_killCamViewMargin);

    ([_outer, _look] call KF_fnc_killCamSeesTarget) &&
    {(KF_var_killCamClearanceDirs findIf {
        !([_pos, _pos vectorAdd (_x vectorMultiply KF_var_killCamClearance)] call KF_fnc_killCamIsLineFree)
    }) == -1}
};

// Scheduled: a camera position around the killer with a free view of him (ASL): behind him first, far before near,
// level before higher; [] if none is free
KF_fnc_killCamFindEndPos = {
    params ["_target", "_look"];

    private _isUnit = KF_var_killCam get "isUnit";
    private _distances = KF_var_killCamUnitDistances;
    private _height = KF_var_killCamUnitHeight;

    if (!_isUnit) then {
        private _radius = (boundingBoxReal _target) select 2;

        _distances = KF_var_killCamVehicleDistances apply {_x + KF_var_killCamVehicleDistanceFactor * _radius};
        _height = (((boundingBoxReal _target) select 1) select 2) - ((KF_var_killCam get "targetCenter") select 2) + KF_var_killCamVehicleHeight;
    };

    private _targetDir = getDirVisual _target;
    private _result = [];

    {
        private _distance = _x;

        {
            private _offsetZ = _x;

            {
                private _angle = _targetDir + _x;
                private _pos = [_look vectorAdd [(sin _angle) * _distance, (cos _angle) * _distance, _offsetZ]] call KF_fnc_killCamLiftPos;

                if ([_pos, _look] call KF_fnc_killCamIsCameraPosFree) exitWith {
                    _result = _pos;
                };
            } forEach KF_var_killCamAngles;

            if (_result isNotEqualTo []) exitWith {};
        } forEach [_height, _height + KF_var_killCamExtraHeight];

        if (_result isNotEqualTo []) exitWith {};
    } forEach _distances;

    _result
};

// The flight path between the curve points at the parameters _ts free: per segment a centre ray and four rays at
// KF_var_killCamPathRadius around it (growing over the first KF_var_killCamPathTaper m, the view starts at the
// ground). The victim's body is ignored.
KF_fnc_killCamIsPathFree = {
    params ["_controlPoints", "_ts"];

    private _victim = KF_var_killCam get "victim";
    private _start = _controlPoints select 0;
    private _points = _ts apply {[_controlPoints, _x] call KF_fnc_killCamBezier};
    private _floor = (getTerrainHeightASL _start) + 0.05;
    private _free = true;

    // the head of a body at rest is often a bit inside the ground: the check starts just above it
    if ((_start select 2) < _floor) then {
        _points set [0, [_start select 0, _start select 1, _floor]];
    };

    for "_i" from 0 to (count _points - 2) do {
        private _from = _points select _i;
        private _to = _points select (_i + 1);
        private _forward = vectorNormalized (_to vectorDiff _from);
        private _side = _forward vectorCrossProduct [0, 0, 1];

        // a vertical segment
        if ((vectorMagnitude _side) < 0.01) then {
            _side = [1, 0, 0];
        };

        _side = vectorNormalized _side;

        private _up = _side vectorCrossProduct _forward;
        private _fromRadius = KF_var_killCamPathRadius * (((_from distance _start) / KF_var_killCamPathTaper) min 1);
        private _toRadius = KF_var_killCamPathRadius * (((_to distance _start) / KF_var_killCamPathTaper) min 1);

        _free = ([[0, 0, 0], _side, _side vectorMultiply -1, _up, _up vectorMultiply -1] findIf {
            !([_from vectorAdd (_x vectorMultiply _fromRadius), _to vectorAdd (_x vectorMultiply _toRadius),
                _victim] call KF_fnc_killCamIsLineFree)
        }) == -1;

        if (!_free) exitWith {};
    };

    _free
};

// Scheduled. The flight path as Bezier control points (ASL): straight if free, else over the obstacle (up to a free
// height, then down); [] when neither is free (the camera fades through black)
KF_fnc_killCamFindPath = {
    params ["_start", "_end"];

    private _delta = _end vectorDiff _start;
    private _straight = [_start, _start vectorAdd (_delta vectorMultiply (1 / 3)), _start vectorAdd (_delta vectorMultiply (2 / 3)), _end];

    if([_straight,
        [0,(KF_var_killCamPathTaper /((vectorMagnitude _delta) max 0.01)) min 0.5,
        1]] call KF_fnc_killCamIsPathFree) exitWith {
        _straight
    };

    private _ts = [];

    for "_i" from 0 to KF_var_killCamPathSamples do {
        _ts pushBack (_i / KF_var_killCamPathSamples);
    };

    private _top = (_start select 2) max (_end select 2);
    private _index = KF_var_killCamClimbHeights findIf {
        [[_start,[_start select 0, _start select 1, _top + _x],[_end select 0, _end select 1, _top + _x],
            _end], _ts] call KF_fnc_killCamIsPathFree
    };

    if (_index == -1) exitWith {[]};

    private _height = _top + (KF_var_killCamClimbHeights select _index);

    [_start, [_start select 0, _start select 1, _height], [_end select 0, _end select 1, _height], _end]
};

KF_fnc_killCamPathLength = {
    params ["_controlPoints"];

    private _length = 0;
    private _last = _controlPoints select 0;

    for "_i" from 1 to KF_var_killCamPathSamples do {
        private _point = [_controlPoints, _i / KF_var_killCamPathSamples] call KF_fnc_killCamBezier;

        _length = _length + (_point distance _last);
        _last = _point;
    };

    _length
};

// ---- run ----

// scheduled: waiting for the start, flight and hold, then the end
KF_fnc_runKillCam = {
    if (call KF_fnc_killCamWaitForStart) then {
        private _plan = call KF_fnc_killCamPlan;

        if (_plan isNotEqualTo [] && {!(call KF_fnc_killCamShouldStop)}) then {
            isNil {_plan call KF_fnc_killCamBegin};

            if ((_plan select 2) isEqualTo []) then {
                call KF_fnc_killCamFadeToHold;
            };

            call KF_fnc_killCamWatch;
        };
    };

    call KF_fnc_killCamFinish;
};

// Scheduled, one check per frame: the start KF_var_killCamStartDelay after the death, as soon as the view hardly moves
// any more (the body has settled). Returns false when the kill cam has to stop instead.
KF_fnc_killCamWaitForStart = {
    KF_var_killCamStartDelay params ["_earliest", "_latest"];

    private _deathTime = KF_var_killCam get "deathTime";
    private _lastPos = positionCameraToWorld [0, 0, 0];
    private _lastDir = (positionCameraToWorld [0, 0, 1]) vectorDiff _lastPos;
    private _lastTime = time;
    private _settledFrames = 0;

    waitUntil {
        call KF_fnc_killCamHoldRespawnTimer;

        private _elapsed = time - _lastTime;

        if (_elapsed > 0) then {
            private _pos = positionCameraToWorld [0, 0, 0];
            private _dir = (positionCameraToWorld [0, 0, 1]) vectorDiff _pos;
            private _turn = acos ((_dir vectorCos _lastDir) min 1);
            private _settled =((_pos distance _lastPos) < KF_var_killCamSettleSpeed * _elapsed) &&
                {_turn < KF_var_killCamSettleTurnRate * _elapsed};

            _settledFrames = [0, _settledFrames + 1] select _settled;
            _lastPos = _pos;
            _lastDir = _dir;
            _lastTime = time;
        };

        (call KF_fnc_killCamShouldStop) ||
        {time >= _deathTime + _latest} ||
        {time >= _deathTime + _earliest && {_settledFrames >= KF_var_killCamSettleFrames}}
    };

    !(call KF_fnc_killCamShouldStop)
};

// scheduled: [look point at planning, end position, flight path] from the current view, [] without a free end position
KF_fnc_killCamPlan = {
    private _target = KF_var_killCam get "target";
    private _look = [_target] call KF_fnc_killCamLookPoint;
    private _end = [_target, _look] call KF_fnc_killCamFindEndPos;

    if (_end isEqualTo []) exitWith {[]};

    [_look, _end, [AGLToASL positionCameraToWorld [0, 0, 0], _end] call KF_fnc_killCamFindPath]
};

// Unscheduled: the camera takes over exactly the view of this frame (position, direction, roll, field of view). The
// positions of positionCameraToWorld are AGL, each converted on its own.
KF_fnc_killCamBegin = {
    params ["_planLook", "_end", "_path"];

    private _pos = AGLToASL positionCameraToWorld [0, 0, 0];
    private _dir = (AGLToASL positionCameraToWorld [0, 0, 1]) vectorDiff _pos;
    private _up = (AGLToASL positionCameraToWorld [0, 1, 0]) vectorDiff _pos;
    private _fov = ((getObjectFOV player) max 0.01) min 2;
    private _camera = "camera" camCreate (ASLToAGL _pos);

    _camera cameraEffect ["internal", "back"];
    _camera setPosASL _pos;
    _camera setVectorDirAndUp [_dir, _up];
    _camera camPrepareFov _fov;
    _camera camCommitPrepared 0;
    showCinemaBorder false;
    camUseNVG ((currentVisionMode player) == 1);
    call KF_fnc_killCamClearFeedback;

    KF_var_killCam merge [createHashMapFromArray [
        ["camera", _camera],
        ["shown", true],
        ["startAngles", [_dir, _up] call KF_fnc_killCamAngles],
        ["startFov", _fov],
        ["endFov", _fov max KF_var_killCamMinFov],
        ["planLook", _planLook],
        ["endOffset", _end vectorDiff _planLook],
        ["phase", "still"],
        ["phaseStart", time],
        ["lastFrame", time],
        ["textSize", ((call KF_fnc_gridCell) select 1) * KF_var_killCamTextSizeCells]
    ], true];

    // the path starts at the view of this frame, not of the planning a few frames ago
    if (_path isNotEqualTo []) then {
        _path set [0, _pos];

        KF_var_killCam set ["path", _path];
        KF_var_killCam set ["duration",
            ((([_path] call KF_fnc_killCamPathLength) / KF_var_killCamFlightSpeed) max (
            KF_var_killCamFlightDuration select 0)) min (KF_var_killCamFlightDuration select 1)];
        KF_var_killCam set ["phase", "flight"];
    };

    KF_var_killCam set ["drawHandler", addMissionEventHandler ["Draw3D", {call KF_fnc_killCamFrame}]];
};

// scheduled: through black to the hold position (no free flight path, or the killer went out of view)
KF_fnc_killCamFadeToHold = {
    private _layer = "KF_killCamFade" call BIS_fnc_rscLayer;

    _layer cutText ["", "BLACK OUT", KF_var_killCamFadeDuration, true];
    sleep KF_var_killCamFadeDuration;
    isNil {call KF_fnc_killCamStartHold};
    _layer cutText ["", "BLACK IN", KF_var_killCamFadeDuration, true];
};

// the orbit from the end position (endOffset from the look point); the hold time starts with the first hold
KF_fnc_killCamStartHold = {
    (KF_var_killCam get "endOffset") params ["_offsetX", "_offsetY", "_offsetZ"];

    private _radius = (vectorMagnitude [_offsetX, _offsetY, 0]) max KF_var_killCamMinOrbitRadius;

    KF_var_killCam merge [createHashMapFromArray [
        ["orbitAngle", _offsetX atan2 _offsetY],
        ["orbitRadius", _radius],
        ["orbitRadiusGoal", _radius],
        ["orbitBaseRadius", _radius],
        ["orbitHeight", _offsetZ],
        ["orbitDir", 1],
        ["orbitVelocity", 0]
    ], true];

    if ((KF_var_killCam get "phase") != "hold") then {
        KF_var_killCam set ["holdStart", time];
        KF_var_killCam set ["phase", "hold"];
    };
};

// The vanilla damage feedback (a3\functions_f\Feedback\fn_feedbackMain.fsm) blurs and greys the screen when the player
// dies or goes unconscious (BIS_DeathBlur, BIS_UncBlur, ... - the death blur stays until the respawn): the kill cam
// shows the killer clearly. Only effects that are on are switched off (the handle of a destroyed effect can belong to
// a newer effect by now); the feedback switches its unconscious effects on again by itself after the kill cam.
KF_var_killCamFeedbackEffects = [
    "BIS_DeathBlur", "BIS_DeathRadialBlur", "BIS_DeathCC", "BIS_UncBlur", "BIS_UncRadialBlur", "BIS_UncCC",
    "BIS_TotDesatCC", "BIS_fnc_feedback_damageBlur", "BIS_fnc_feedback_damageCC", "BIS_SuffBlur", "BIS_SuffCC",
    "BIS_BleedCC", "BIS_HitCC", "BIS_BurnCC", "BIS_fnc_feedback_fatigueBlur", "BIS_fnc_feedback_fatigueCC"
];

KF_fnc_killCamClearFeedback = {
    {
        private _handle = missionNamespace getVariable [_x, -1];

        if ((_handle isEqualType 0) && {_handle >= 0} && {ppEffectEnabled _handle}) then {
            _handle ppEffectEnable false;
        };
    } forEach KF_var_killCamFeedbackEffects;
};

// scheduled, every frame: until the hold time is over or the kill cam has to stop; checks the orbit a few times a second
KF_fnc_killCamWatch = {
    private _nextCheck = 0;

    waitUntil {
        private _holding = (KF_var_killCam get "phase") == "hold";

        call KF_fnc_killCamClearFeedback;

        if (_holding && {time >= _nextCheck}) then {
            _nextCheck = time + KF_var_killCamOrbitCheckInterval;
            call KF_fnc_killCamCheckOrbit;
        };

        (call KF_fnc_killCamShouldStop) || {_holding && {time >= (KF_var_killCam get "holdStart") + KF_var_killCamHoldDuration}}
    };
};

KF_var_killCamOutroFade = 1;      // s per fade at the end of the kill cam
KF_var_killCamBodyTime = 2;       // s at the own body between the fades ("body" outro)
KF_var_killCamBlack = false;      // the kill cam ended in black on the death transition's layer (KF_fnc_runDeathFeed)

// scheduled: waits _duration seconds and holds the respawn timer meanwhile, like the running kill cam
KF_fnc_killCamWait = {
    params ["_duration"];

    private _end = time + _duration;

    waitUntil {
        call KF_fnc_killCamHoldRespawnTimer;
        time >= _end
    };
};

// Scheduled: out of the kill cam through black (user: never a cut to the own body), the camera off in the black, then
// KF_var_killCamOutro: "black" hands the black to the death transition of the game mode, "body" fades in at the own body
// and through black again to the respawn menu; going unconscious (AIS) fades in to the unconscious view. Then the held
// respawn menu opens and the game mode goes on.
KF_fnc_killCamFinish = {
    // from here on a death no longer holds the respawn menu (KF_fnc_killCamEntityKilled)
    KF_var_killCam set ["finishing", true];

    private _camera = KF_var_killCam getOrDefault ["camera", objNull];
    private _dead = !(alive player);
    private _handOver = _dead && {KF_var_killCamOutro == "black"} && {KF_var_deathTransition} && {KF_var_deathFeedParts isNotEqualTo []};
    private _layer = (["KF_killCamOutro", "KF_deathTransition"] select _handOver) call BIS_fnc_rscLayer;

    if (!isNull _camera) then {
        _layer cutText ["", "BLACK OUT", KF_var_killCamOutroFade, true];
        [KF_var_killCamOutroFade] call KF_fnc_killCamWait;
    };

    isNil {
        if (!isNull _camera) then {
            removeMissionEventHandler ["Draw3D", KF_var_killCam get "drawHandler"];
            _camera cameraEffect ["terminate", "back"];
            camDestroy _camera;
            camUseNVG false;
        };
    };

    if (!isNull _camera && {_dead} && {KF_var_killCamOutro == "body"}) then {
        _layer cutText ["", "BLACK IN", KF_var_killCamOutroFade, true];
        [KF_var_killCamOutroFade + KF_var_killCamBodyTime] call KF_fnc_killCamWait;
        _layer cutText ["", "BLACK OUT", KF_var_killCamOutroFade, true];
        [KF_var_killCamOutroFade] call KF_fnc_killCamWait;
    };

    KF_var_killCamBlack = _handOver && {!isNull _camera};

    call KF_fnc_killCamOpenRespawnMenu;

    private _timeout = time + KF_var_killCamKeyReleaseTimeout;

    waitUntil {
        call KF_fnc_killCamHoldRespawnTimer;
        !(KF_var_killCam get "keyHeld") || {time > _timeout}
    };

    private _display = findDisplay 46;

    (KF_var_killCam get "keyHandlers") params ["_keyDownHandler", "_keyUpHandler"];
    _display displayRemoveEventHandler ["KeyDown", _keyDownHandler];
    _display displayRemoveEventHandler ["KeyUp", _keyUpHandler];

    KF_var_killCamActive = false;
    [missionNamespace, "KF_killCamDone", [KF_var_killCam get "shown"]] call BIS_fnc_callScriptedEventHandler;

    // back in with what follows (respawn menu, unconscious view), after a moment for it to appear
    if (!isNull _camera && {!_handOver}) then {
        sleep 0.2;
        _layer cutText ["", "BLACK IN", KF_var_killCamOutroFade, true];
    };
};

// ---- per frame (Draw3D): only cheap math ----

KF_fnc_killCamFrame = {
    call KF_fnc_killCamHoldRespawnTimer;

    private _target = KF_var_killCam get "target";

    if (isNull _target) exitWith {};

    private _camera = KF_var_killCam get "camera";
    private _look = [_target] call KF_fnc_killCamLookPoint;
    private _now = time;

    switch (KF_var_killCam get "phase") do {
        case "flight": {
            [_camera, _look, _now] call KF_fnc_killCamFlightFrame;
        };
        case "hold": {
            [_camera, _look, _now] call KF_fnc_killCamHoldFrame;
        };
    };

    KF_var_killCam set ["lastFrame", _now];

    drawIcon3D [
        "",
        KF_var_killCam get "color",
        ASLToAGL ([_target] call KF_fnc_killCamIconPoint),
        0,
        0,
        0,
        KF_var_killCam get "label",
        2,
        KF_var_killCam get "textSize",
        "RobotoCondensed",
        "center"
    ];
};

// eased along the path, plus the killer's movement since the planning; turns towards him in the first part of the
// flight while the roll of the dead view straightens and the zoom opens
KF_fnc_killCamFlightFrame = {
    params ["_camera", "_look", "_now"];

    private _progress = ((_now - (KF_var_killCam get "phaseStart")) / (KF_var_killCam get "duration")) min 1;
    private _eased = [_progress] call KF_fnc_killCamEase;
    private _turn = [_progress / KF_var_killCamTurnShare] call KF_fnc_killCamEase;
    private _pos =([KF_var_killCam get "path",
        _eased] call KF_fnc_killCamBezier) vectorAdd ((_look vectorDiff (KF_var_killCam get "planLook"))
        vectorMultiply _eased);

    (KF_var_killCam get "startAngles") params ["_startYaw", "_startPitch", "_startRoll"];
    ([_look vectorDiff _pos] call KF_fnc_killCamYawPitch) params ["_yaw", "_pitch"];

    private _orientation = [
        _startYaw + _turn * ([_startYaw, _yaw] call KF_fnc_killCamAngleDiff),
        _startPitch + _turn * (_pitch - _startPitch),
        _startRoll * (1 - _turn)
    ] call KF_fnc_killCamOrientation;

    _camera setPosASL _pos;
    _camera setVectorDirAndUp _orientation;

    private _startFov = KF_var_killCam get "startFov";
    private _endFov = KF_var_killCam get "endFov";

    if (_startFov != _endFov) then {
        _camera camPrepareFov (_startFov + _turn * (_endFov - _startFov));
        _camera camCommitPrepared 0;
    };

    if (_progress >= 1) then {
        call KF_fnc_killCamStartHold;
    };
};

// around the killer at the orbit radius and height, following him; speed and radius change smoothly
KF_fnc_killCamHoldFrame = {
    params ["_camera", "_look", "_now"];

    private _elapsed = _now - (KF_var_killCam get "lastFrame");
    private _velocity = KF_var_killCam get "orbitVelocity";
    private _radius = KF_var_killCam get "orbitRadius";

    _velocity = _velocity +((KF_var_killCam get "orbitDir") * KF_var_killCamOrbitSpeed - _velocity) *(1 - exp (-
        KF_var_killCamOrbitSmoothing * _elapsed));
    _radius = _radius + ((KF_var_killCam get "orbitRadiusGoal") - _radius) * (1 - exp (-KF_var_killCamRadiusSmoothing * _elapsed));

    private _angle = (KF_var_killCam get "orbitAngle") + _velocity * _elapsed;

    KF_var_killCam set ["orbitVelocity", _velocity];
    KF_var_killCam set ["orbitRadius", _radius];
    KF_var_killCam set ["orbitAngle", _angle];

    private _pos = [_look, _angle, _radius, KF_var_killCam get "orbitHeight"] call KF_fnc_killCamOrbitPos;
    private _orientation = ([_look vectorDiff _pos] call KF_fnc_killCamYawPitch) call KF_fnc_killCamOrientation;

    _camera setPosASL _pos;
    _camera setVectorDirAndUp _orientation;
};

// ---- orbit checks (scheduled, a few times per second) ----

// the longest orbit radius (share of the base radius) at which the camera KF_var_killCamOrbitLookAhead seconds ahead in
// direction _dir is free and reachable from _current; -1 if none
KF_fnc_killCamFreeOrbitRadius = {
    params ["_look", "_dir", "_current"];

    private _angle = (KF_var_killCam get "orbitAngle") + _dir * KF_var_killCamOrbitSpeed * KF_var_killCamOrbitLookAhead;
    private _baseRadius = KF_var_killCam get "orbitBaseRadius";
    private _height = KF_var_killCam get "orbitHeight";
    private _radii = KF_var_killCamOrbitRadii apply {(_baseRadius * _x) max KF_var_killCamMinOrbitRadius};
    private _index = _radii findIf {
        private _pos = [_look, _angle, _x, _height] call KF_fnc_killCamOrbitPos;

        ([_pos, _look] call KF_fnc_killCamIsCameraPosFree) && {[_current, _pos] call KF_fnc_killCamIsLineFree}
    };

    if (_index == -1) exitWith {-1};

    _radii select _index
};

// The orbit ahead must stay free: blocked at every radius, it turns round; blocked both ways, it stands still. A
// camera that lost the view of the killer (he moved behind something) jumps through black to a free spot.
KF_fnc_killCamCheckOrbit = {
    private _target = KF_var_killCam get "target";

    if (isNull _target) exitWith {};

    private _look = [_target] call KF_fnc_killCamLookPoint;
    private _current = getPosASLVisual (KF_var_killCam get "camera");

    if !([_current, _look] call KF_fnc_killCamSeesTarget) exitWith {
        [_target, _look] call KF_fnc_killCamRelocate;
    };

    private _orbitDir = KF_var_killCam get "orbitDir";
    private _directions = if (_orbitDir == 0) then {[1, -1]} else {[_orbitDir, -_orbitDir]};
    private _radius = -1;
    private _index = _directions findIf {
        _radius = [_look, _x, _current] call KF_fnc_killCamFreeOrbitRadius;
        _radius > 0
    };

    if (_index == -1) exitWith {
        KF_var_killCam set ["orbitDir", 0];
    };

    KF_var_killCam set ["orbitDir", _directions select _index];
    KF_var_killCam set ["orbitRadiusGoal", _radius];
};

// at most once per KF_var_killCamRelocateInterval
KF_fnc_killCamRelocate = {
    params ["_target", "_look"];

    if (time < (KF_var_killCam getOrDefault ["nextRelocate", 0])) exitWith {};

    KF_var_killCam set ["nextRelocate", time + KF_var_killCamRelocateInterval];

    private _pos = [_target, _look] call KF_fnc_killCamFindEndPos;

    if (_pos isEqualTo []) exitWith {};

    KF_var_killCam set ["endOffset", _pos vectorDiff _look];
    call KF_fnc_killCamFadeToHold;
};

// ---- recovery (alt-tab robustness) ----
// The kill cam and the death transition black the screen out on the killfeed's layers in a chain of fades and waits; a
// step missed while the game window had no focus (alt-tab) could leave the screen black after the respawn (user). Once
// the player has been back in his own view for KF_var_recoveryDelay seconds without a kill cam, these layers are
// cleared once.
KF_var_recoveryDelay = 3;

KF_fnc_recoveryLoop = {
    private _since = -1;      // since when the player is back in his own view, -1: he isn't
    private _done = false;    // the layers are cleared already in this life

    waitUntil {
        if ((call KF_fnc_playerHasRespawned) && {!KF_var_killCamActive}) then {
            if (_since < 0) then {
                _since = time;
            };

            if (!_done && {(time - _since) >= KF_var_recoveryDelay}) then {
                _done = true;

                {
                    (_x call BIS_fnc_rscLayer) cutText ["", "PLAIN", 0, true];
                } forEach ["KF_killCamOutro", "KF_deathTransition", "KF_killCamFade"];
            };
        } else {
            _since = -1;
            _done = false;
        };

        sleep 0.5;
        false
    };
};

// ---- start: once the server started the killfeed ----

[] spawn {
    waitUntil {!isNil "KF_var_running" && {KF_var_running}};

    addMissionEventHandler ["EntityKilled", {_this call KF_fnc_killCamEntityKilled}];
    addMissionEventHandler ["EntityRespawned", {_this call KF_fnc_killCamEntityRespawned}];

    if (hasInterface) then {
        KF_var_recoveryScript = [] spawn KF_fnc_recoveryLoop;
    };
};
