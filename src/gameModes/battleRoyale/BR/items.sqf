// Battle Royale healing items (server and client), as in PUBG: bandages heal 10 HP each up to 75 % health, first aid
// kits heal up to 75 % at once, medikits to full health, energy drinks give a boost that heals slowly. All of them are
// used by a left double-click in the inventory (no scroll menu actions), take a few seconds (moving, firing or a
// hit cancels the use; no progress bar) and are used up only when the use completes. The AI uses the
// same timed use. Arma has no bandages or drinks and a mission cannot add classes: existing magazines with fitting
// pictures carry them (Old Man's bandage and antibiotics, CfgMagazines).
// First aid kits and medikits are the vanilla items on the ground and on the AI, but a player carries them as magazines
// as well: the engine offers "Treat yourself" to anyone injured who carries a FirstAidKit item and
// has no way to hide that action, a magazine it does not know as a healing item. The inventory shows the carried
// magazine with the kit's name and picture (BR_fnc_relabelInventory).

BR_var_bandageClass = "Bandage";
BR_var_drinkClass = "Antibiotic"; // carrier of the energy drink
BR_var_fakClass = "FirstAidKit";
BR_var_medikitClass = "Medikit";
BR_var_bandageHeal = 0.1; // 10 HP
BR_var_bandageMaxHealth = 0.75; // bandages heal up to this health ...
BR_var_fakMaxHealth = 0.75; // ... first aid kits as well, at once; a medikit heals to full health
BR_var_bandageTime = 3; // s of a use; moving or firing cancels it
BR_var_drinkTime = 2.5;
BR_var_fakTime = 6;
BR_var_medikitTime = 8;
BR_var_drinkClasses = ["Antibiotic", "EnergyDrink"] select {isClass (configFile >> "CfgMagazines" >> _x)};

// kit -> the magazine a player carries it as (base game, Old Man; mass 1 and 100 against 8 and 80 of the kits)
BR_var_kitCarriers = [["FirstAidKit", "Antimalaricum"], ["Medikit", "AntimalaricumVaccine"]] select {
    isClass (configFile >> "CfgMagazines" >> (_x select 1))
};
BR_var_kitConvertInterval = 1; // s: kits a player got without a Take event (script, uniform swap) are converted this often

BR_var_bandageMoveLimit = 1;
BR_var_bandageAnimation = "AinvPknlMstpSlayWrflDnon_medic";
BR_var_boostDuration = 70; // s of the energy drink's boost ...
BR_var_boostHeal = 0.01; // ... healing this much (1 HP) ...
BR_var_boostInterval = 2; // ... this often, up to full health, ...
BR_var_boostStamina = 1; // ... and gives this many seconds of stamina back (recovers about 50 % faster)
BR_var_aiBandageDamage = 0.3; // the AI bandages itself out of a fight above this damage ...
BR_var_aiDrinkDamage = 0.15; // ... and drinks above this one (when no boost runs)

BR_var_limitMessage = "%1 heal only up to %2"; // a use refused above the item's health limit says why ...
BR_var_healthyMessage = "You are not injured"; // ... a medikit at full health as well
BR_var_selfTreatMessage = "Use first aid kits and medikits by double-click in the inventory";
BR_var_itemMessageTime = 3; // s a message stays in the inventory before it fades
BR_var_blockedHealActions = ["HealSoldierSelf"]; // engine actions of the player blocked (BR_fnc_onUiAction)
BR_var_vehicleGearWait = 1; // s: the inventory a vehicle's "Gear" action opens has this long to open

if (isNil "BR_var_inventoryDisplay") then {BR_var_inventoryDisplay = 602}; // normally set by BR\uniforms.sqf
BR_var_inventoryOwnLists = [633, 638, 619]; // uniform, vest and backpack container lists of the inventory
BR_var_inventoryRelabelLists = [632, 640, 633, 638, 619]; // the own ones and ground / other container

/*
    Armor level of vests and headgear in the inventory: CUP's descriptions ("Armor Level III", "No
    armor") do not match its configs - 377 CUP vests share one protection, 73 of them say "No armor". The level comes
    from the config: sum of armor * (1 - passThrough) of the item's HitpointsProtectionInfo (as BR_fnc_aiClothingProfile)
    against these thresholds; level = number of thresholds reached. Vests (vanilla + CUP): 0 none (belts,
    bandoliers), 12-28.8 light (tactical vest, PASGT, JPC light), 33.6-44.8 Carrier Lite and most CUP rigs, 48-56 Carrier
    Rig, 6B45, IOTV, 72.8-92.8 Carrier Special / GL Rig. Headgear: 0 caps, 0.8-2 light helmets, 3-4 combat helmets,
    5 enhanced helmets, 6-10 face shields and Viper.
*/
BR_var_armorLevelThresholds = createHashMapFromArray [[701, [5, 30, 45, 65]], [605, [0.5, 2.5, 4.5, 5.5]]]; // ItemInfo type
// Uniforms, vests and backpacks show their space as well: maximumLoad of the container (CfgVehicles;
// uniforms and vests: their ItemInfo >> containerClass). One suffix per item: " [Armor 2 | Space 80]".
BR_var_armorLabel = "Armor %1";
BR_var_spaceLabel = "Space %1";
BR_var_itemInfoFormat = " [%1]";
BR_var_itemInfoSeparator = " | ";
// ItemInfo type of wearables by their base class, for items whose ItemInfo has no type (an addon's own base class)
BR_var_wearableBases = [["HelmetBase", 605], ["Vest_Camo_Base", 701], ["Vest_NoCamo_Base", 701], ["Uniform_Base", 801]];
// slot pictures of RscDisplayInventory whose tooltip shows the suffix: headgear, uniform, vest, backpack
BR_var_gearSlots = [[6240, {headgear player}], [6331, {uniform player}], [6381, {vest player}], [6191, {backpack player}]];
BR_var_itemSuffixes = createHashMap; // class (lower case) -> suffix, "" for other items
BR_var_rowDataClasses = createHashMap; // lbData (lower case) -> its class, "" if it is none (backpack rows)
BR_var_rowTextClasses = createHashMap; // row text (lower case) -> class, for rows without a class in lbData
BR_var_rowTextLogged = []; // row texts (lower case) without a class already in the RPT
BR_var_rowNameClasses = []; // [name (lower case), class] of the wearables around, rebuilt at most this often:
BR_var_rowNameInterval = 0.5; // s
BR_var_rowNameTime = -1;
BR_var_rowNameRadius = 6; // m: containers around the player the ground / other list can show

// ---- items, classes and health ----

// the item of a usable class or carrier: the class as configured (case-sensitive checks like "in magazines" hold)
BR_var_itemUseClasses = createHashMap;
{BR_var_itemUseClasses set [toLowerANSI _x, _x]} forEach ([BR_var_bandageClass, BR_var_fakClass, BR_var_medikitClass] + BR_var_drinkClasses);
{BR_var_itemUseClasses set [toLowerANSI (_x select 1), _x select 0]} forEach BR_var_kitCarriers;

// carrier (lower case) -> [kit name, kit picture] for the inventory rows
BR_var_carrierLabels = createHashMapFromArray (BR_var_kitCarriers apply {
    private _kit = configFile >> "CfgWeapons" >> (_x select 0);

    [toLowerANSI (_x select 1), [getText (_kit >> "displayName"), getText (_kit >> "picture")]]
});

// [carrier name (lower case), label] for rows without lbData
BR_var_carrierNames = BR_var_kitCarriers apply {
    [toLowerANSI getText (configFile >> "CfgMagazines" >> (_x select 1) >> "displayName"), BR_var_carrierLabels get toLowerANSI (_x select 1)]
};

BR_fnc_carrierOf = {
    params ["_kit"];

    ((BR_var_kitCarriers select {(_x select 0) == _kit}) param [0, ["", ""]]) select 1
};

// a kit is carried as the item (AI, ground) or as its carrier magazine (players)
BR_fnc_hasItem = {
    params ["_unit", "_class"];

    if (_class in [BR_var_fakClass, BR_var_medikitClass]) exitWith {
        _class in items _unit || {([_class] call BR_fnc_carrierOf) in magazines _unit}
    };

    _class in magazines _unit
};

// the carrier first: a vanilla kit a player still has is converted anyway
BR_fnc_removeItemUsed = {
    params ["_unit", "_class"];

    if (_class in [BR_var_fakClass, BR_var_medikitClass]) exitWith {
        private _carrier = [_class] call BR_fnc_carrierOf;

        if (_carrier != "" && {_carrier in magazines _unit}) then {_unit removeMagazine _carrier} else {_unit removeItem _class};
    };

    _unit removeMagazine _class;
};

// the largest damage of a unit, overall or of a hit point (hit legs alone count too)
BR_fnc_injury = {
    params ["_unit"];

    selectMax (((getAllHitPointsDamage _unit) param [2, []]) + [damage _unit])
};

// Overall damage and every hit point to at most _target, none raised: setDamage alone would set every hit point to
// the overall value, also slightly hit ones up. Where the unit is local.
BR_fnc_healTo = {
    params ["_unit", "_target"];

    private _hits = (getAllHitPointsDamage _unit) param [2, []];

    _unit setDamage ((damage _unit) min _target);
    {_unit setHitIndex [_forEachIndex, _x min _target, false]} forEach _hits;
};

// ---- use (players and AI) ----

// a use is possible: alive, not downed, no other use running, the item carried and the health below its limit
BR_fnc_canUseItem = {
    params ["_unit", "_class"];

    alive _unit && {!(_unit getVariable ["ais_unconscious", false])} && {!(_unit getVariable ["BR_var_bandaging", false])} &&
        {[_unit, _class] call BR_fnc_hasItem} && {([_unit, _class] call BR_fnc_itemLimitMessage) == ""}
};

// why a carried item cannot be used at this health ("": it can)
BR_fnc_itemLimitMessage = {
    params ["_unit", "_class"];

    switch (true) do {
        case (_class == BR_var_bandageClass): {
            ["", format [BR_var_limitMessage, "Bandages", str round (BR_var_bandageMaxHealth * 100) + " %"]] select
                (damage _unit <= 1 - BR_var_bandageMaxHealth)
        };
        case (_class == BR_var_fakClass): {
            ["", format [BR_var_limitMessage, "First aid kits", str round (BR_var_fakMaxHealth * 100) + " %"]] select
                (([_unit] call BR_fnc_injury) <= 1 - BR_var_fakMaxHealth)
        };
        case (_class == BR_var_medikitClass): {
            ["", BR_var_healthyMessage] select (([_unit] call BR_fnc_injury) < 0.001)
        };
        default {""};
    }
};

BR_fnc_canUseBandage = {
    params ["_unit"];

    [_unit, BR_var_bandageClass] call BR_fnc_canUseItem
};

BR_fnc_canDrink = {
    params ["_unit", ["_class", ""]];

    if (_class == "") then {_class = (BR_var_drinkClasses select {_x in magazines _unit}) param [0, ""]};
    _class in BR_var_drinkClasses && {[_unit, _class] call BR_fnc_canUseItem}
};

BR_fnc_itemUseTime = {
    params ["_class"];

    switch (true) do {
        case (_class == BR_var_bandageClass): {BR_var_bandageTime};
        case (_class == BR_var_fakClass): {BR_var_fakTime};
        case (_class == BR_var_medikitClass): {BR_var_medikitTime};
        default {BR_var_drinkTime};
    }
};

// Same duration and cancellation rules for players and AI. Healing is committed only after uninterrupted use.
BR_fnc_bandage = {
    params ["_unit"];

    [_unit, BR_var_bandageClass] call BR_fnc_startItemUse
};

BR_fnc_drink = {
    params ["_unit", ["_class", ""]];

    if (_class == "") then {_class = (BR_var_drinkClasses select {_x in magazines _unit}) param [0, ""]};
    [_unit, _class] call BR_fnc_startItemUse
};

// Reserve immediately, before scheduling: repeated inventory clicks cannot start concurrent uses.
BR_fnc_startItemUse = {
    params ["_unit", "_class"];

    if !([_unit, _class] call BR_fnc_canUseItem) exitWith {false};
    _unit setVariable ["BR_var_bandaging", true];
    _unit setVariable ["BR_var_bandageInterrupted", false];
    [_unit, _class, [_class] call BR_fnc_itemUseTime] spawn BR_fnc_runItemUse;
    true
};

BR_fnc_runItemUse = {
    params ["_unit", "_class", "_duration"];

    private _startPos = getPosATL _unit;
    private _startDamage = damage _unit;
    private _parent = objectParent _unit;
    private _log = hasInterface && {_unit isEqualTo player};

    private _firedEh = _unit addEventHandler ["FiredMan", {
        (_this select 0) setVariable ["BR_var_bandageInterrupted", "fired"];
    }];

    private _hitEh = _unit addEventHandler ["Hit", {
        (_this select 0) setVariable ["BR_var_bandageInterrupted", "hit"];
    }];

    // in a vehicle the unit keeps its seat and its pose: no kneeling, no stop order (an AI driver would brake)
    private _onFoot = isNull _parent;
    if (_onFoot && {!isPlayer _unit}) then {doStop _unit};
    private _stance = stance _unit;
    if (_onFoot) then {_unit playMoveNow BR_var_bandageAnimation};

    if (_log) then {
        diag_log format ["BR items: use %1 started (%2 s, damage %3, %4)", _class, _duration, damage _unit, ["in vehicle", "on foot"] select _onFoot];
    };

    private _end = time + _duration;
    private _reason = "";

    // the reason a use stops early ("" while it goes on); the AI tick sets the interruption to true (fight, zone)
    waitUntil {
        sleep 0.1;
        private _interrupted = _unit getVariable ["BR_var_bandageInterrupted", false];

        _reason = switch (true) do {
            case (!alive _unit): {"dead"};
            case (_unit getVariable ["ais_unconscious", false]): {"unconscious"};
            case (_interrupted isEqualType ""): {_interrupted};
            case (_interrupted isEqualTo true): {"interrupted"};
            case (_onFoot && {_unit distance _startPos > BR_var_bandageMoveLimit}): {"moved"};
            case (objectParent _unit isNotEqualTo _parent): {"vehicle change"};
            case (damage _unit > _startDamage + 0.001): {"damage rose"};
            default {""};
        };

        _reason != "" || {time >= _end}
    };

    _unit removeEventHandler ["FiredMan", _firedEh];
    _unit removeEventHandler ["Hit", _hitEh];

    if (_reason == "" && {!([_unit, _class] call BR_fnc_hasItem)}) then {_reason = "item gone"};

    if (_reason == "") then {
        private _before = damage _unit;

        [_unit, _class] call BR_fnc_applyItem;
        if (_log) then {diag_log format ["BR items: use %1 completed, damage %2 -> %3", _class, _before, damage _unit]};
    } else {
        if (_log) then {diag_log format ["BR items: use %1 cancelled: %2", _class, _reason]};
    };

    if (_onFoot && {alive _unit} && {isNull objectParent _unit} && {!(_unit getVariable ["ais_unconscious", false])}) then {
        _unit playMoveNow (switch _stance do {
            case "STAND": {"AmovPercMstpSrasWrflDnon"};
            case "PRONE": {"AmovPpneMstpSrasWrflDnon"};
            default {"AmovPknlMstpSrasWrflDnon"};
        });
    };

    _unit setVariable ["BR_var_aiDestination", []];
    _unit setVariable ["BR_var_bandaging", false];
};

// the completed use: the item used up and its effect, where the unit is local
BR_fnc_applyItem = {
    params ["_unit", "_class"];

    switch (true) do {
        // one bandage: BR_var_bandageHeal less damage, not below 1 - BR_var_bandageMaxHealth
        case (_class == BR_var_bandageClass): {
            _unit removeMagazine _class;
            [_unit, (damage _unit - BR_var_bandageHeal) max ((1 - BR_var_bandageMaxHealth) min damage _unit)] call BR_fnc_healTo;
        };
        case (_class == BR_var_fakClass): {
            [_unit, _class] call BR_fnc_removeItemUsed;
            [_unit, 1 - BR_var_fakMaxHealth] call BR_fnc_healTo;
        };
        case (_class == BR_var_medikitClass): {
            [_unit, _class] call BR_fnc_removeItemUsed;
            _unit setDamage 0;
        };
        default {[_unit, _class] call BR_fnc_applyDrink};
    };
};

/*
    Energy drink (where the unit is local): BR_var_boostHeal every BR_var_boostInterval for BR_var_boostDuration, a new
    drink starts the boost anew. HUD interface: player variables BR_var_boostEnd (serverTime), BR_var_boostDuration
    (seconds) and BR_var_boost (0..1, the bar fill). Faster stamina recovery: see BR_var_boostStamina.
*/
BR_fnc_applyDrink = {
    params ["_unit", ["_class", BR_var_drinkClass]];

    if (!alive _unit || {!(_class in magazines _unit)}) exitWith {};

    _unit removeMagazine _class;

    private _alreadyRunning = (_unit getVariable ["BR_var_boostEnd", 0]) > serverTime;

    _unit setVariable ["BR_var_boostEnd", serverTime + BR_var_boostDuration];
    _unit setVariable ["BR_var_boostDuration", BR_var_boostDuration];

    if (hasInterface && {_unit isEqualTo player}) then {
        diag_log format ["BR items: boost %1, ends in %2 s", ["started", "extended"] select _alreadyRunning, BR_var_boostDuration];
    };

    if (_alreadyRunning) exitWith {};

    [_unit] spawn {
        params ["_unit"];

        waitUntil {
            private _left = (_unit getVariable ["BR_var_boostEnd", 0]) - serverTime;

            _unit setVariable ["BR_var_boost", 0 max (_left / BR_var_boostDuration)];

            if (alive _unit && {_left > 0}) then {
                if (damage _unit > 0) then {
                    _unit setDamage (0 max (damage _unit - BR_var_boostHeal));
                };

                if (isStaminaEnabled _unit) then {
                    _unit setStamina (getStamina _unit + BR_var_boostStamina);
                };
            };

            sleep BR_var_boostInterval;
            !alive _unit || {_left <= 0}
        };

        _unit setVariable ["BR_var_boost", 0];
    };
};

// ---- player (client) ----

// Once per player unit (the respawn hook in BR\uniforms.sqf resets the flag on a new unit): inventory double-click,
// kit carriers; once per client: the blocked self-treatment and the inventory key in vehicles.
BR_fnc_initItems = {
    call BR_fnc_initUiAction;
    call BR_fnc_initVehicleGear;

    if (player getVariable ["BR_var_itemHooksInstalled", false]) exitWith {};

    player setVariable ["BR_var_itemHooksInstalled", true];

    player addEventHandler ["InventoryOpened", {
        [] spawn BR_fnc_hookInventoryItems;
        false

    }];

    // a picked up kit becomes its carrier at once (next frame: not inside the engine's own transfer)
    player addEventHandler ["Take", {
        params ["_unit", "", "_item"];

        if (_item in [BR_var_fakClass, BR_var_medikitClass]) then {
            [_unit] spawn {[_this select 0] call BR_fnc_convertKits};
        };

    }];

    player addEventHandler ["InventoryClosed", {
        [_this select 0] spawn {[_this select 0] call BR_fnc_convertKits};
    }];

    [player] call BR_fnc_convertKits;

    if (isNil "BR_var_kitConvertLoop") then {
        BR_var_kitConvertLoop = [] spawn {
            while {true} do {
                sleep BR_var_kitConvertInterval;
                if (alive player) then {[player] call BR_fnc_convertKits};
            };
        };
    };
};

// every FirstAidKit / Medikit item of the local unit becomes its carrier magazine, in the same container
BR_fnc_convertKits = {
    params ["_unit"];

    if (!local _unit || {!alive _unit} || {((items _unit) findIf {_x in [BR_var_fakClass, BR_var_medikitClass]}) < 0}) exitWith {};

    {
        _x params ["_kit", "_carrier"];

        {
            _x params ["_container", "_remove"];

            if (!isNull _container) then {
                private _count = {_x == _kit} count itemCargo _container;

                if (_count > 0) then {
                    for "_i" from 1 to _count do {call _remove};
                    _container addMagazineCargoGlobal [_carrier, _count];
                };
            };
        } forEach [
            [uniformContainer _unit, {_unit removeItemFromUniform _kit}],
            [vestContainer _unit, {_unit removeItemFromVest _kit}],
            [backpackContainer _unit, {_unit removeItemFromBackpack _kit}]
        ];
    } forEach BR_var_kitCarriers;
};

/*
    "Treat yourself" (HealSoldierSelf) is blocked: kits are used by double-click. A player carries
    them as magazines (BR_fnc_convertKits), so the engine normally does not even offer the action; this catches the
    moment before a conversion. inGameUISetEventHandler is one handler per client: AIS (BR\downed.sqf, team modes)
    sets its own when its init has run, so ours is set again after that and calls the AIS handler itself.
*/
BR_fnc_initUiAction = {
    if (!isNil "BR_var_uiActionSet") exitWith {};

    BR_var_uiActionSet = true;
    inGameUISetEventHandler ["Action", "_this call BR_fnc_onUiAction"];

    if (call BR_fnc_downedEnabled) then {
        [] spawn {
            private _until = time + 120;

            // AIS_Core_realSide is set right after the AIS player init, which sets its own handler
            waitUntil {sleep 0.5; !isNil "AIS_Core_realSide" || {time > _until}};
            inGameUISetEventHandler ["Action", "_this call BR_fnc_onUiAction"];
        };
    };
};

// the UI "Action" handler: true blocks the engine action
BR_fnc_onUiAction = {
    params ["", "_caller", "", "_action"];

    if (_action in BR_var_blockedHealActions && {_caller isEqualTo player}) exitWith {
        [BR_var_selfTreatMessage] call BR_fnc_itemMessage;
        true
    };

    if (isNil "AIS_System_fnc_overrideHealAction") exitWith {false};

    _this call AIS_System_fnc_overrideHealAction
};

/*
    A short message the player sees for sure: in the inventory (the double-click happens there; a hint goes unnoticed)
    a text at the top of it, else a notification.
*/
BR_fnc_itemMessage = {
    params ["_text"];

    if (!hasInterface) exitWith {};

    disableSerialization;
    private _display = findDisplay BR_var_inventoryDisplay;

    if (isNull _display) exitWith {["brInfo", [_text]] call BIS_fnc_showNotification};

    private _ctrl = _display getVariable ["BR_var_itemMessageCtrl", controlNull];

    if (isNull _ctrl) then {
        _ctrl = _display ctrlCreate ["RscStructuredText", -1];
        _ctrl ctrlSetPosition [safeZoneX + safeZoneW * 0.3, safeZoneY + safeZoneH * 0.04, safeZoneW * 0.4, safeZoneH * 0.05];
        _ctrl ctrlSetBackgroundColor [0, 0, 0, 0.75];
        _display setVariable ["BR_var_itemMessageCtrl", _ctrl];
    };

    _ctrl ctrlSetStructuredText parseText format ["<t align='center' size='1.25'>%1</t>", _text];
    _ctrl ctrlSetFade 0;
    _ctrl ctrlCommit 0;

    private _token = (_display getVariable ["BR_var_itemMessageToken", 0]) + 1;
    _display setVariable ["BR_var_itemMessageToken", _token];

    [_display, _ctrl, _token] spawn {
        params ["_display", "_ctrl", "_token"];

        uiSleep BR_var_itemMessageTime;

        // a newer message keeps the text up
        if (!isNull _ctrl && {(_display getVariable ["BR_var_itemMessageToken", 0]) == _token}) then {
            _ctrl ctrlSetFade 1;
            _ctrl ctrlCommit 0.5;
        };
    };
};

// One route for the inventory double-click: shared duration/cancellation rules apply to players and AI alike. _class
// is a usable class as configured (BR_fnc_inventoryItemClass); a use refused at high health says why.
BR_fnc_inventoryUseItem = {
    params ["_unit", "_class"];

    private _used = [_unit, _class] call BR_fnc_startItemUse;

    if (!_used && {[_unit, _class] call BR_fnc_hasItem}) then {
        private _message = [_unit, _class] call BR_fnc_itemLimitMessage;

        if (_message != "") then {[_message] call BR_fnc_itemMessage};
    };

    _used
};

/*
    The usable class (as configured) of an inventory row, "" for others; a carrier row gives its kit. The engine's
    container lists (RscListBox in RscDisplayInventory) carry the class in lbData; should a row have none, its text is
    matched against the names of the usable classes the player carries (a relabelled carrier shows the kit's name).
*/
BR_fnc_inventoryItemClass = {
    params ["_list", "_index"];

    if (_index < 0) exitWith {""};

    private _class = BR_var_itemUseClasses getOrDefault [toLowerANSI (_list lbData _index), ""];

    if (_class == "" && {(_list lbData _index) == ""}) then {
        private _text = toLowerANSI (_list lbText _index);
        private _usable = [BR_var_bandageClass, BR_var_fakClass, BR_var_medikitClass] + BR_var_drinkClasses;
        private _found = _usable findIf {
            private _root = ["CfgMagazines", "CfgWeapons"] select (_x in [BR_var_fakClass, BR_var_medikitClass]);
            private _name = toLowerANSI getText (configFile >> _root >> _x >> "displayName");

            [player, _x] call BR_fnc_hasItem && {_name != ""} && {(_text find _name) >= 0}
        };

        _class = _usable param [_found, ""];
    };

    _class
};

BR_fnc_hookInventoryItems = {
    disableSerialization;
    private _until = diag_tickTime + 2;

    waitUntil {
        uiSleep 0.01;
        !isNull (findDisplay BR_var_inventoryDisplay) || {diag_tickTime > _until}
    };

    private _display = findDisplay BR_var_inventoryDisplay;
    if (isNull _display || {_display getVariable ["BR_var_itemHooked", false]}) exitWith {};

    _display setVariable ["BR_var_itemHooked", true];
    BR_var_rowTextClasses = createHashMap;
    BR_var_rowNameTime = -1;

    // carrier rows show the kit, wearables their armor and space; every frame, as the engine rebuilds its lists on
    // every change - in Draw3D, after the engine's update of the display: it refreshes the player's own container
    // lists and the slot tooltips every frame after EachFrame
    addMissionEventHandler ["Draw3D", {call BR_fnc_relabelInventory}];

    {
        private _list = _display displayCtrl _x;

        if (!isNull _list) then {
            _list ctrlAddEventHandler ["LBDblClick", {
                params ["_list", "_index"];

                if (_index < 0) then {_index = lbCurSel _list};
                private _class = [_list, _index] call BR_fnc_inventoryItemClass;
                private _used = _class != "" && {[player, _class] call BR_fnc_inventoryUseItem};

                // one line per double-click on a usable item: shows in the client RPT what the row held and why
                if (_class != "" || {_index >= 0 && {(_list lbData _index) == ""}}) then {
                    diag_log format [
                        "BR items: double-click list %1 row %2 data '%3' text '%4' -> class '%5', used %6, damage %7",
                        ctrlIDC _list, _index, _list lbData _index, _list lbText _index, _class, _used, damage player
                    ];
                };

                // closed in the next frame: closing the display inside its own control handler is avoided
                if (_used) then {
                    [] spawn {(findDisplay BR_var_inventoryDisplay) closeDisplay 2};
                };

                _used

            }];
        };
    } forEach BR_var_inventoryOwnLists;
};

// The display name of an item class (CfgWeapons, a backpack in CfgVehicles, CfgMagazines, CfgGlasses).
BR_fnc_itemName = {
    params ["_class"];

    private _root = ["CfgWeapons", "CfgVehicles", "CfgMagazines", "CfgGlasses"] select {isClass (configFile >> _x >> _class)};

    if (_root isEqualTo []) exitWith {""};
    getText (configFile >> (_root select 0) >> _class >> "displayName")
};

/*
    The suffix of an item class, cached per class: armor level of vests and headgear, space of uniforms, vests and
    backpacks (" [Armor 2 | Space 80]", " [Space 40]", " [Armor 3]"), "" for other items. A wearable whose ItemInfo has
    no type is recognized by its base class (BR_var_wearableBases).
*/
BR_fnc_itemSuffix = {
    params ["_class"];

    private _key = toLowerANSI _class;
    private _suffix = BR_var_itemSuffixes get _key;

    if (isNil "_suffix") then {
        private _parts = [];
        private _cfg = configFile >> "CfgWeapons" >> _class;

        if (isClass _cfg) then {
            private _info = _cfg >> "ItemInfo";
            private _type = getNumber (_info >> "type");

            if (_type == 0) then {
                private _base = BR_var_wearableBases findIf {_class isKindOf [_x select 0, configFile >> "CfgWeapons"]};
                if (_base >= 0) then {_type = (BR_var_wearableBases select _base) select 1};
            };

            private _thresholds = BR_var_armorLevelThresholds getOrDefault [_type, []];

            if (_thresholds isNotEqualTo []) then {
                private _protection = 0;

                {
                    _protection = _protection + getNumber (_x >> "armor") * (1 - getNumber (_x >> "passThrough"));
                } forEach ("true" configClasses (_info >> "HitpointsProtectionInfo"));

                _parts pushBack format [BR_var_armorLabel, {_protection >= _x} count _thresholds];
            };

            if (_type in [701, 801]) then {
                private _container = configFile >> "CfgVehicles" >> getText (_info >> "containerClass");
                if (isClass _container) then {_parts pushBack format [BR_var_spaceLabel, getNumber (_container >> "maximumLoad")]};
            };
        } else {
            private _bag = configFile >> "CfgVehicles" >> _class;
            if (getNumber (_bag >> "isBackpack") == 1) then {_parts pushBack format [BR_var_spaceLabel, getNumber (_bag >> "maximumLoad")]};
        };

        _suffix = "";
        if (_parts isNotEqualTo []) then {_suffix = format [BR_var_itemInfoFormat, _parts joinString BR_var_itemInfoSeparator]};
        BR_var_itemSuffixes set [_key, _suffix];
    };

    _suffix
};

// [name (lower case), class] of the items with a suffix in the player's containers and the containers around him
// (ground holders, boxes, vehicles, bodies), longest name first: rows without a class in lbData are matched by them
BR_fnc_rowNameClasses = {
    BR_var_rowNameTime = diag_tickTime;
    private _containers = [uniformContainer player, vestContainer player, backpackContainer player, objectParent player, cursorObject];
    private _classes = [];

    {
        if (_x isKindOf "CAManBase") then {
            _containers append [uniformContainer _x, vestContainer _x, backpackContainer _x];
        } else {
            _containers pushBack _x;
        };
    } forEach nearestObjects [player, ["WeaponHolder", "WeaponHolderSimulated", "ReammoBox_F", "AllVehicles"], BR_var_rowNameRadius];

    {
        if (!isNull _x && {!(_x isKindOf "CAManBase")}) then {
            _classes append itemCargo _x;
            _classes append backpackCargo _x;

            {
                _classes append itemCargo (_x select 1);
                _classes append backpackCargo (_x select 1);
            } forEach everyContainer _x;
        };
    } forEach _containers;

    private _names = [];

    {
        if (([_x] call BR_fnc_itemSuffix) != "") then {
            private _name = toLowerANSI ([_x] call BR_fnc_itemName);
            if (_name != "") then {_names pushBack [-(count _name), _name, _x]};
        };
    } forEach (_classes arrayIntersect _classes);

    _names sort true;
    BR_var_rowNameClasses = _names apply {[_x select 1, _x select 2]};
};

/*
    The class of an inventory row, "" if unknown. The engine's lists carry it in lbData for every item type except
    backpacks (CBA, cba_ui_fnc_getInventoryItemData: feedback.bistudio.com/T183096); such a row is matched by its text
    (the name, perhaps with the suffix already appended) against the items around (BR_fnc_rowNameClasses).
*/
BR_fnc_inventoryRowClass = {
    params ["_data", "_text"];

    private _key = toLowerANSI _data;
    private _class = BR_var_rowDataClasses get _key;

    if (isNil "_class") then {
        _class = "";

        if (_data != "" && {(["CfgWeapons", "CfgMagazines", "CfgVehicles", "CfgGlasses"] findIf {isClass (configFile >> _x >> _data)}) >= 0}) then {
            _class = _data;
        };

        BR_var_rowDataClasses set [_key, _class];
    };

    if (_class == "") then {
        private _textKey = toLowerANSI _text;
        _class = BR_var_rowTextClasses get _textKey;

        if (isNil "_class") then {
            private _fnc_match = {
                private _found = BR_var_rowNameClasses findIf {(_textKey find (_x select 0)) == 0};
                (BR_var_rowNameClasses param [_found, ["", ""]]) select 1
            };

            _class = call _fnc_match;

            if (_class == "" && {diag_tickTime >= BR_var_rowNameTime + BR_var_rowNameInterval}) then {
                call BR_fnc_rowNameClasses;
                _class = call _fnc_match;

                if (_class == "" && {!(_textKey in BR_var_rowTextLogged)}) then {
                    BR_var_rowTextLogged pushBack _textKey;
                    diag_log format ["BR items: inventory row without a class: data '%1' text '%2'", _data, _text];
                };
            };

            // a miss is not cached: the next rebuild of the names may find the row
            if (_class != "") then {BR_var_rowTextClasses set [_textKey, _class]};
        };
    };

    _class
};

// Every frame (Draw3D) while the inventory is open: carrier rows get the kit's name, picture and tooltip; wearable rows and slots
// their armor and space. A row is touched only while its text lacks the suffix (the engine rebuilt it).
BR_fnc_relabelInventory = {
    disableSerialization;
    private _display = findDisplay BR_var_inventoryDisplay;

    if (isNull _display) exitWith {removeMissionEventHandler ["Draw3D", _thisEventHandler]};

    {
        private _list = _display displayCtrl _x;

        if (!isNull _list) then {
            for "_i" from 0 to (lbSize _list - 1) do {
                private _data = _list lbData _i;
                private _key = toLowerANSI _data;
                private _label = BR_var_carrierLabels getOrDefault [_key, []];

                // a row without data: by the carrier's own name
                if (_label isEqualTo [] && {_data == ""}) then {
                    private _text = toLowerANSI (_list lbText _i);
                    private _found = BR_var_carrierNames findIf {(_text find (_x select 0)) >= 0};

                    if (_found >= 0) then {_label = (BR_var_carrierNames select _found) select 1};
                };

                if (_label isNotEqualTo []) then {
                    if ((_list lbText _i) != (_label select 0)) then {
                        _list lbSetText [_i, _label select 0];
                        _list lbSetPicture [_i, _label select 1];
                        _list lbSetTooltip [_i, _label select 0];
                    };
                } else {
                    private _text = _list lbText _i;
                    private _class = BR_var_rowDataClasses get _key;
                    if (isNil "_class" || {_class == ""}) then {_class = [_data, _text] call BR_fnc_inventoryRowClass};

                    if (_class != "") then {
                        private _suffix = BR_var_itemSuffixes get toLowerANSI _class;
                        if (isNil "_suffix") then {_suffix = [_class] call BR_fnc_itemSuffix};

                        // the tooltip too: CUP's own description ("No armor") would contradict the level
                        if (_suffix != "" && {(_text find _suffix) < 0}) then {
                            _list lbSetText [_i, _text + _suffix];
                            _list lbSetTooltip [_i, _text + _suffix];
                        };
                    };
                };
            };
        };
    } forEach BR_var_inventoryRelabelLists;

    // the slot pictures: no tooltip getter, so set every frame (four controls)
    {
        _x params ["_idc", "_worn"];
        private _ctrl = _display displayCtrl _idc;
        private _class = call _worn;

        if (!isNull _ctrl && {_class != ""}) then {
            _ctrl ctrlSetTooltip (([_class] call BR_fnc_itemName) + ([_class] call BR_fnc_itemSuffix));
        };
    } forEach BR_var_gearSlots;
};

/*
    The inventory key in a vehicle. Every BR player is a renegade (BR_fnc_makeRenegade: free for all), and the engine
    opens no vehicle inventory for a renegade ("Action::Process - No target [action: Gear]"). So the key lifts the rating to 0, opens the
    inventory by "Gear" on the vehicle and makes the player a renegade again once it is open. The key itself is
    consumed: else the engine keeps its own failed Gear action pending and opens the inventory once more when the
    player gets out.
*/
BR_fnc_initVehicleGear = {
    if (!isNil "BR_var_vehicleGearKey") exitWith {};

    BR_var_vehicleGearKey = true;
    BR_var_vehicleGearPending = false;

    [] spawn {
        waitUntil {uiSleep 0.1; !isNull findDisplay 46};

        (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];

            if (
                _key in actionKeys "Gear" && {alive player} && {!isNull objectParent player} && {!BR_var_vehicleGearPending} &&
                {isNull findDisplay BR_var_inventoryDisplay} && {rating player < 0}
            ) then {
                BR_var_vehicleGearPending = true;
                player addRating (0 - rating player);
                [objectParent player] spawn BR_fnc_vehicleGearOpen;
                true
            } else {
                false
            }
        }];
    };
};

BR_fnc_vehicleGearOpen = {
    params ["_vehicle"];

    private _opened = {!isNull findDisplay BR_var_inventoryDisplay};
    private _how = "failed";

    if (alive player && {objectParent player isEqualTo _vehicle}) then {
        player action ["Gear", _vehicle];
        private _until = diag_tickTime + BR_var_vehicleGearWait;
        waitUntil {call _opened || {diag_tickTime > _until}};
        if (call _opened) then {_how = "action"};
    };

    [player] call BR_fnc_makeRenegade;
    uiSleep 0.2;
    diag_log format ["BR items: vehicle inventory in %1 by %2, still open as a renegade again: %3", typeOf _vehicle, _how, call _opened];
    BR_var_vehicleGearPending = false;
};

// ---- AI (server) ----

/*
    Out of a fight: a drink above BR_var_aiDrinkDamage (also on the move), a bandage above BR_var_aiBandageDamage - not
    in a _hurry (zone), it kneels for BR_var_bandageTime. True while bandaging: the AI tick stops there.
*/
BR_fnc_aiUseItems = {
    params ["_unit", ["_hurry", false]];

    if (
    damage _unit > BR_var_aiDrinkDamage && {(_unit getVariable ["BR_var_boostEnd", 0]) <= serverTime} && {[_unit] call BR_fnc_canDrink}

    ) then {
        [_unit] call BR_fnc_drink;
    };

    if (_unit getVariable ["BR_var_bandaging", false] || {!scriptDone (_unit getVariable ["BR_var_aiBandageScript", scriptNull])}) exitWith {true};

    if (_hurry || {damage _unit <= BR_var_aiBandageDamage} || {!([_unit] call BR_fnc_canUseBandage)}) exitWith {false};

    _unit setVariable ["BR_var_aiBandageScript", [_unit] spawn BR_fnc_bandage];
    true
};
