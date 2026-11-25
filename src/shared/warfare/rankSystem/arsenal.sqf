// Arsenal (client): opening the arsenal with the unlocked items, thermal view inside the arsenal and the rank
// decorations of its item lists (vaOverride hooks): perk groups with header rows, unlock rank per row, rank order,
// locked items with the reason (rank / perk icon), equipped and NEW markers, next unlock above the lists.
#include "\a3\ui_f\hpp\defineResincl.inc"
#include "\a3\ui_f\hpp\defineResinclDesign.inc"

// ---- arsenal ----

SC_fnc_setArsenalVisionMode = {
    missionNamespace setVariable ["BIS_fnc_arsenal_visionMode", ([0, 1] select SC_var_nvGogglesEnabled)];
    false setCamUseTI 0;
    camUseNVG SC_var_nvGogglesEnabled;
};

SC_fnc_arsenalThermalLoop = {
    waitUntil {
        private _mode = missionNamespace getVariable ["BIS_fnc_arsenal_visionMode", -1];

        if (_mode == 2) then {
            _mode = 0;
            false setCamUseTI 0;
            camUseNVG false;
            missionNamespace setVariable ["BIS_fnc_arsenal_visionMode", 0];
        };

        if (SC_var_nvGogglesEnabled != (_mode == 1)) then {
            SC_var_nvGogglesEnabled = !SC_var_nvGogglesEnabled;
        };

        false
    };
};

// unscheduled like VA_fnc_onArsenalOpened (at the first opening the arsenal's event comes from a scheduled script)
SC_fnc_arsenalOpened = {
    params ["_display"];

    isNil {
        call SC_fnc_setArsenalVisionMode;

        [_display, [_display] call SC_fnc_getArsenalSession] spawn {
            params ["_display", "_session"];

            private _nightVisionScript = [] spawn SC_fnc_arsenalThermalLoop;
            private _items = items player;
            private _oldWepItems = call SC_fnc_getPlayersWeaponsItems;
            private _lockedMags = [side (group player), SC_var_perks, (player getVariable "SC_var_rank"), false] call SC_fnc_getLockedMags;

            waitUntil {
                {
                    player removeMagazines _x;
                } forEach ((magazines player) arrayIntersect _lockedMags);

                {
                    if (_x in _lockedMags) then {player removePrimaryWeaponItem _x};
                } forEach (primaryWeaponMagazine player);

                {
                    if (_x in _lockedMags) then {player removeSecondaryWeaponItem _x};
                } forEach (secondaryWeaponMagazine player);

                {
                    if (_x in _lockedMags) then {player removeHandgunItem _x};
                } forEach (handgunMagazine player);

                (isNull _display)
            };

            [_session] call SC_fnc_saveArsenalSeenItems;

            if SC_var_nvGogglesEnabled then {
                player action ["nvGoggles", player];
            };

            terminate _nightVisionScript;
            // weapon items newly attached from the inventory: the arsenal attaches a copy, the inventory one is removed
            private _newWepItems = call SC_fnc_getPlayersWeaponsItems;
            {player removeItems _x;} forEach ((_items arrayIntersect _newWepItems) select {!(_x in _oldWepItems)});

            private _sideIndex = SC_var_sides find (side (group player));
            player linkItem (SC_var_wgUavTerminals select _sideIndex);

            if (!DW_var_skipNight && {(hmd player) == ""} && {!("H_PilotHelmetFighter_" in (headgear player))} && {!(("Viper") in (headgear player))}) then {
                private _defaultNvg = SC_var_wgDefaultNvgs select _sideIndex;

                if (_defaultNvg != "") then {
                    player linkItem _defaultNvg;
                };
            };

            if (call SC_fnc_isLoadoutValid) then {
                private _mags = magazines player;

                {
                    private _weapon = _x;
                    {
                        private _muzzle = _x;
                        {
                            private _mag = _x;
                            if (_mag in _mags) then {
                                player addWeaponItem [_weapon, _mag, true];
                            };
                        } forEach (if (_muzzle == "this") then {
                            getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines")
                        } else {
                            getArray (configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "magazines")
                        });
                    } forEach (getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles"));
                } forEach (weapons player);

                SC_var_lastLoadout = getUnitLoadout player;
                SC_var_lastLoadoutInfo = call SC_fnc_getLoadoutInfo;
                call SC_fnc_saveLoadoutToProfile;

                if SC_var_hudEnabled then {
                    ["loadoutSaved"] call BIS_fnc_showNotification;
                };
            } else {
                ["loadoutNotSaved"] call BIS_fnc_showNotification;
            };
        };
    };
};

// ---- unlock requirements ----

// arsenal tabs whose items come from the arsenal's own item lists (the attachment and weapon magazine lists depend on
// the equipped weapons)
SC_var_arsenalStaticTabs = (VA_var_leftTabs - VA_var_identityTabs) + [
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOTHROW,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOPUT,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMISC
];

SC_var_arsenalMagazineTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOTHROW,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOPUT
];

// item type (BIS_fnc_itemType select 1) of the attachment tabs
SC_var_arsenalAttachmentTypes = createHashMapFromArray [
    [IDC_RSCDISPLAYARSENAL_TAB_ITEMOPTIC, "AccessorySights"],
    [IDC_RSCDISPLAYARSENAL_TAB_ITEMACC, "AccessoryPointer"],
    [IDC_RSCDISPLAYARSENAL_TAB_ITEMMUZZLE, "AccessoryMuzzle"],
    [IDC_RSCDISPLAYARSENAL_TAB_ITEMBIPOD, "AccessoryBipod"]
];

// side -> [requirements, class names, tab classes, option texts] (SC_fnc_buildArsenalUnlockData)
SC_var_arsenalUnlockData = createHashMap;

// "Rank 20" / "Rank 20 · Grenadier perk"
SC_fnc_formatRequirement = {
    params ["_rank", "_perk"];

    if (_perk == "") then {
        format ["Rank %1", _rank]
    } else {
        format ["Rank %1 · %2 perk", _rank, [_perk] call SC_fnc_getPerkFromPerkAbbrev]
    }
};

// adds an unlock option [rank, perk] of a class (key: lower case class; the class name is kept for new arsenal rows)
SC_fnc_addUnlockRequirement = {
    params ["_requirements", "_classNames", "_class", "_requirement"];

    private _key = toLowerANSI _class;
    private _options = _requirements get _key;

    if (isNil "_options") then {
        _options = [];
        _requirements set [_key, _options];
        _classNames set [_key, _class];
    };

    _options pushBackUnique _requirement;
};

// the unlock options of all items of the item config for one side (the arsenal's item lists must exist, i.e. the
// arsenal is open):
// - requirements: lower case class -> [[rank, perk], ...] ascending, the rank includes the perk's own rank; weapons as
//   their base weapon like in the arsenal, magazines without a rank of their own come with the weapons that use them
// - class names: lower case class -> class name
// - tab classes: arsenal tab -> lower case classes of SC_var_arsenalStaticTabs that belong in its list
// - option texts: lower case class -> SC_fnc_formatRequirement of each option
SC_fnc_buildArsenalUnlockData = {
    params ["_side"];

    private _requirements = createHashMap;
    private _weaponMagazines = createHashMap;
    private _classNames = createHashMap;
    private _perkRanks = createHashMapFromArray (SC_var_perkConfig apply {[_x select 1, _x select 2]});
    private _sideStr = str _side;

    {
        _x params ["_perk", "_configNames"];

        private _perkRank = _perkRanks getOrDefault [_perk, 1];

        {
            {
                _x params ["_configClass", "_rank"];

                private _requirement = [_rank max _perkRank, _perk];
                private _class = _configClass;

                if ((([_configClass] call SC_fnc_getItemType) select 0) == "Weapon") then {
                    _class = _configClass call BIS_fnc_baseWeapon;
                };

                [_requirements, _classNames, _class, _requirement] call SC_fnc_addUnlockRequirement;

                if (([_configClass] call SC_fnc_getItemCategories) select 0) then {
                    {
                        [_weaponMagazines, _classNames, _x, _requirement] call SC_fnc_addUnlockRequirement;
                    } forEach ([_configClass] call SC_fnc_getWeaponMagazines);
                };
            } forEach ((getArray (missionConfigFile >> (format [_x, _sideStr]))) call SC_fnc_filterConfigArr);
        } forEach _configNames;
    } forEach ([["", ["general", "%1General"]]] + SC_var_perkItemConfigs);

    _requirements merge [_weaponMagazines, false];

    // the Medic perk replaces the first aid kits by a medikit
    [_requirements, _classNames, "Medikit", [_perkRanks getOrDefault ["MEDC", 1], "MEDC"]] call SC_fnc_addUnlockRequirement;

    private _arsenalData = missionNamespace getVariable ["bis_fnc_arsenal_data", []];
    private _classTabs = createHashMap;

    {
        private _tab = _x;

        {
            _classTabs set [toLowerANSI _x, _tab];
        } forEach (_arsenalData param [_tab, []]);
    } forEach SC_var_arsenalStaticTabs;

    private _tabClasses = createHashMap;
    private _optionTexts = createHashMap;

    {
        private _options = _requirements get _x;
        _options sort true;
        _optionTexts set [_x, _options apply {_x call SC_fnc_formatRequirement}];

        private _tab = _classTabs get _x;

        if !(isNil "_tab") then {
            private _classes = _tabClasses get _tab;

            if (isNil "_classes") then {
                _classes = [];
                _tabClasses set [_tab, _classes];
            };

            _classes pushBack _x;
        };
    } forEach (keys _requirements);

    [_requirements, _classNames, _tabClasses, _optionTexts]
};

// SC_fnc_buildArsenalUnlockData, built once per side
SC_fnc_getArsenalUnlockData = {
    params ["_side"];

    private _data = SC_var_arsenalUnlockData get _side;

    if (isNil "_data") then {
        _data = [_side] call SC_fnc_buildArsenalUnlockData;
        SC_var_arsenalUnlockData set [_side, _data];
    };

    _data
};

// the unlock option of an item ([[rank, perk], ...] ascending) its row shows: the first one the player has, else the
// lowest rank without a missing perk, else the lowest rank
SC_fnc_getArsenalOptionIndex = {
    params ["_options", "_playerRank", "_perks"];

    private _index = _options findIf {((_x select 0) <= _playerRank) && {((_x select 1) == "") || {(_x select 1) in _perks}}};

    if (_index == -1) then {
        _index = _options findIf {((_x select 1) == "") || {(_x select 1) in _perks}};
    };

    0 max _index
};

// what the player lacks for an unlock option: "Rank 20 not reached · Grenadier perk not selected" ("" if nothing)
SC_fnc_formatMissingRequirement = {
    params ["_rank", "_perk", "_playerRank", "_perks"];

    private _missing = [];

    if (_rank > _playerRank) then {
        _missing pushBack format ["Rank %1 not reached", _rank];
    };

    if ((_perk != "") && {!(_perk in _perks)}) then {
        _missing pushBack format ["%1 perk not selected", [_perk] call SC_fnc_getPerkFromPerkAbbrev];
    };

    _missing joinString " · "
};

// VA_var_lockReason: what is missing for the item's option (SC_fnc_getArsenalOptionIndex) and its other options ("" if
// it has none)
SC_fnc_getArsenalLockReason = {
    params ["_class"];

    ([side (group player)] call SC_fnc_getArsenalUnlockData) params ["_requirements", "", "", "_optionTexts"];

    private _key = toLowerANSI _class;

    if !(_key in _requirements) then {
        _key = toLowerANSI (_class call BIS_fnc_baseWeapon);
    };

    private _options = _requirements getOrDefault [_key, []];

    if (_options isEqualTo []) exitWith {""};

    private _playerRank = player getVariable ["SC_var_rank", 1];
    private _optionIndex = [_options, _playerRank, SC_var_perks] call SC_fnc_getArsenalOptionIndex;
    (_options select _optionIndex) params ["_rank", "_perk"];

    private _missing = [_rank, _perk, _playerRank, SC_var_perks] call SC_fnc_formatMissingRequirement;
    private _others = +(_optionTexts get _key);

    if (_missing == "") exitWith {_others joinString " or "};

    _others deleteAt _optionIndex;
    _missing + (["", "; also unlocked by " + (_others joinString " or ")] select (_others isNotEqualTo []))
};

// ---- list decorations ----

// white vanilla icons, tinted per row
SC_var_arsenalEquippedIcon = "\a3\ui_f\data\map\diary\icons\tasksucceeded_ca.paa";
SC_var_arsenalLockedIcon = "\a3\ui_f\data\gui\rsc\rscdisplaydynamicgroups\lock.paa";     // locked for another reason
SC_var_arsenalRankIcon = "\a3\ui_f\data\gui\cfg\ranks\sergeant_gs.paa";                 // rank not reached, general items
SC_var_arsenalPerkIcon = "\a3\ui_f\data\igui\cfg\actions\reammo_ca.paa";                // a perk without an icon below

// perk -> icon of its items: reason of their locked rows and icon of their group header (SC perks have no icons)
SC_var_arsenalPerkIcons = createHashMapFromArray [
    ["MEDC", "\a3\ui_f\data\igui\cfg\actions\heal_ca.paa"],
    ["MRKS", "\a3\ui_f\data\gui\cfg\respawnroles\recon_ca.paa"],
    ["MGNR", "\a3\ui_f\data\gui\cfg\respawnroles\assault_ca.paa"],
    ["LNCR", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\secondaryweapon_ca.paa"],
    ["ARMR", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\vest_ca.paa"],
    ["GRND", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\cargothrow_ca.paa"],
    ["DEMO", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\cargoput_ca.paa"],
    ["SUPR", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\itemmuzzle_ca.paa"]
];

// alpha of the white rank texts and of locked rows
SC_var_arsenalDimAlpha = 0.5;
SC_var_arsenalLockedAlpha = 0.35;

// lower case class -> the mod icon the arsenal shows on the right of its row (replaced by the decoration icons)
SC_var_arsenalModIcons = createHashMap;

// texture path in lower case without the leading backslash (the engine may return a texture name normalized)
SC_fnc_normalizeArsenalPath = {
    params ["_path"];

    _path = toLowerANSI _path;

    if ((_path select [0, 1]) == "\") then {_path select [1]} else {_path}
};

// the right pictures of the decorations (any other right picture of a row is the arsenal's mod icon)
SC_var_arsenalOwnIcons = (
    [SC_var_arsenalEquippedIcon, SC_var_arsenalLockedIcon, SC_var_arsenalRankIcon, SC_var_arsenalPerkIcon] +
    (values SC_var_arsenalPerkIcons)
) apply {[_x] call SC_fnc_normalizeArsenalPath};

// per open arsenal (stored on the display): unlock data, unlocked classes (cache of VA_fnc_isUnlocked), the NEW items
// shown, locked items of the static tabs, next unlock per tab, rank and perks at the opening, the setting, the colors
// (text, dim, locked, accent, warning)
SC_fnc_getArsenalSession = {
    params ["_display"];

    private _session = _display getVariable "SC_var_arsenalSession";

    if (isNil "_session") then {
        private _accent = +(["accent"] call UI_fnc_color);
        _accent set [3, 1];

        private _warning = +(["warning"] call UI_fnc_color);
        _warning set [3, 1];

        _session = createHashMapFromArray [
            ["unlockData", [side (group player)] call SC_fnc_getArsenalUnlockData],
            ["unlocked", createHashMap],
            ["pendingSeen", createHashMap],
            ["lockedByTab", createHashMap],
            ["nextUnlocks", createHashMap],
            ["rank", player getVariable ["SC_var_rank", 1]],
            ["perks", +SC_var_perks],
            ["showLocked", SC_var_showLockedArsenalItems],
            ["colors", [[1, 1, 1, 1], [1, 1, 1, SC_var_arsenalDimAlpha], [1, 1, 1, SC_var_arsenalLockedAlpha], _accent, _warning]]
        ];

        _display setVariable ["SC_var_arsenalSession", _session];

        // the item lists are grouped by perk and sorted by rank (SC_fnc_decorateArsenalList); the cargo lists have no
        // sort menu
        {
            private _ctrlSort = _display displayCtrl (IDC_RSCDISPLAYARSENAL_SORT + _x);

            if !(isNull _ctrlSort) then {
                _ctrlSort lbSetText [0, "Sort by perk and rank"];
                _ctrlSort lbSetText [1, "Sort by perk, mod and rank"];
            };
        } forEach (VA_var_leftTabs + VA_var_attachmentTabs);
    };

    _session
};

SC_fnc_isArsenalItemUnlocked = {
    params ["_session", "_key"];

    private _cache = _session get "unlocked";
    private _unlocked = _cache get _key;

    if (isNil "_unlocked") then {
        _unlocked = [_key, uiNamespace getVariable ["VA_var_unlockedCargo", []]] call VA_fnc_isUnlocked;
        _cache set [_key, _unlocked];
    };

    _unlocked
};

SC_fnc_isArsenalScope = {
    params ["_config"];

    ((getNumber (_config >> "scope")) == 2) || {(getNumber (_config >> "scopeArsenal")) == 2}
};

// config of an item of an arsenal tab
SC_fnc_getArsenalItemConfig = {
    params ["_class", "_tab"];

    private _root = switch true do {
        case (_tab == IDC_RSCDISPLAYARSENAL_TAB_BACKPACK): {"CfgVehicles"};
        case (_tab == IDC_RSCDISPLAYARSENAL_TAB_GOGGLES): {"CfgGlasses"};
        case (_tab in SC_var_arsenalMagazineTabs): {"CfgMagazines"};
        default {"CfgWeapons"};
    };

    configFile >> _root >> _class
};

// magazines (lower case) of the unit's weapons, like the arsenal's weapon magazine list (magazine wells included)
SC_fnc_getCompatibleMagazines = {
    params ["_unit"];

    private _magazines = [];

    {
        private _cfgWeapon = configFile >> "CfgWeapons" >> _x;

        {
            private _cfgMuzzle = if (_x == "this") then {_cfgWeapon} else {_cfgWeapon >> _x};
            _magazines append (getArray (_cfgMuzzle >> "magazines"));

            {
                {
                    _magazines append (getArray _x);
                } forEach (configProperties [configFile >> "CfgMagazineWells" >> _x, "isArray _x"]);
            } forEach (getArray (_cfgMuzzle >> "magazineWell"));
        } forEach (getArray (_cfgWeapon >> "muzzles"));
    } forEach ((weapons _unit) - ["Throw", "Put"]);

    _magazines = _magazines apply {toLowerANSI _x};
    _magazines arrayIntersect _magazines
};

// the lower case classes with unlock requirements that belong in the list of a tab: attachments compatible with the
// weapon of the open tab, magazines of the equipped weapons while a container tab is open (the arsenal fills both lists
// only then), else the tab's items
SC_fnc_getArsenalCandidates = {
    params ["_display", "_tab", "_session"];

    (_session get "unlockData") params ["_requirements", "", "_tabClasses"];

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];

    if (_tab in VA_var_attachmentTabs) exitWith {
        private _weapon = [_display, _center] call VA_fnc_getActiveWeapon;
        private _type = SC_var_arsenalAttachmentTypes get _tab;
        private _compatible = if (_weapon == "") then {[]} else {(_weapon call BIS_fnc_compatibleItems) apply {toLowerANSI _x}};

        (_compatible arrayIntersect _compatible) select {
            (_x in _requirements) &&
            {(([_x] call SC_fnc_getItemType) select 1) == _type} &&
            {[configFile >> "CfgWeapons" >> _x] call SC_fnc_isArsenalScope}
        }
    };

    if (_tab == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG) exitWith {
        private _containerOpen = (VA_var_containerTabs findIf {ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x))}) != -1;
        private _magazines = if _containerOpen then {[_center] call SC_fnc_getCompatibleMagazines} else {[]};

        _magazines select {
            (_x in _requirements) && {[configFile >> "CfgMagazines" >> _x] call SC_fnc_isArsenalScope}
        }
    };

    _tabClasses getOrDefault [_tab, []]
};

// "next: <item> (<requirement>)" for the locked class of _classes the player gets next (options without a missing perk
// first, then the lowest rank), "" if there is none
SC_fnc_formatNextUnlock = {
    params ["_session", "_classes"];

    (_session get "unlockData") params ["_requirements", "_classNames"];

    private _perks = _session get "perks";
    private _candidates = [];

    {
        private _key = _x;

        {
            _x params ["_rank", "_perk"];
            _candidates pushBack [[1, 0] select ((_perk == "") || {_perk in _perks}), _rank, _key, _perk];
        } forEach (_requirements getOrDefault [_key, []]);
    } forEach _classes;

    if (_candidates isEqualTo []) exitWith {""};

    _candidates sort true;
    (_candidates select 0) params ["", "_rank", "_key", "_perk"];

    format ["next: %1 (%2)", [_classNames get _key] call VA_fnc_getDisplayName, [_rank, _perk] call SC_fnc_formatRequirement]
};

// ---- list decorations: perk groups ----

// position of a perk's group ("" = general items) in the lists: the general items, then the groups of the player's
// perks, then the others, each in the order of SC_var_perkConfig
SC_fnc_getArsenalGroupOrder = {
    params ["_perk", "_perks"];

    if (_perk == "") exitWith {0};

    ([200, 100] select (_perk in _perks)) + (SC_var_perkConfig findIf {(_x select 1) == _perk})
};

// [text, icon, right text, tooltip] of the header row of a perk's group ("" = general items); the right text says why
// the player can't use the group's items yet
SC_fnc_getArsenalGroupHeader = {
    params ["_perk", "_playerRank", "_perks"];

    if (_perk == "") exitWith {
        ["GENERAL", SC_var_arsenalRankIcon, "", "General items: unlocked by rank alone"]
    };

    private _perkIndex = SC_var_perkConfig findIf {(_x select 1) == _perk};
    (if (_perkIndex == -1) then {[_perk, _perk, 1]} else {SC_var_perkConfig select _perkIndex}) params ["_name", "", "_perkRank"];

    private _text = toUpperANSI (format ["%1 perk", _name]);
    private _icon = SC_var_arsenalPerkIcons getOrDefault [_perk, SC_var_arsenalPerkIcon];

    switch true do {
        case (_perk in _perks): {
            [_text, _icon, "", format ["Items of the %1 perk (selected)", _name]]
        };
        case (_perkRank <= _playerRank): {
            [_text, _icon, "not selected", format ["Items of the %1 perk: choose the perk at the Perks object in your base", _name]]
        };
        default {
            [_text, _icon, format ["perk at R%1", _perkRank], format ["Items of the %1 perk: the perk can be chosen from rank %2", _name, _perkRank]]
        };
    }
};

// ---- list decorations: rows ----

// VA_var_listDecorator, left lists and right lists (attachments, cargo):
// - rows grouped by the perk of their unlock option, each group under a header row (perk icon and name, why its items
//   are not usable yet) with an empty row above; not for lists of general items only
// - unlock rank on every row ("R12"), in a group the rows in rank order with the locked items at the end (setting)
// - locked items greyed, on the right the reason: the perk's icon (perk missing) or the rank icon (rank not reached),
//   the rank text in the warning color while the rank is not reached; the tooltip lists what is missing
// - the equipped item with a check in the accent color, NEW for unlocked items not seen yet; cargo lists keep the
//   arsenal's colors (items that don't fit are dimmed) and their counts
SC_fnc_decorateArsenalList = {
    params ["_display", "_ctrlList", "_tab"];

    if (_tab in VA_var_identityTabs) exitWith {};

    private _session = [_display] call SC_fnc_getArsenalSession;
    (_session get "unlockData") params ["_requirements", "_classNames", "", "_optionTexts"];
    (_session get "colors") params ["_colorText", "_colorDim", "_colorLocked", "_colorAccent", "_colorWarning"];

    private _unlockedCache = _session get "unlocked";
    private _isListN = (ctrlType _ctrlList) == CT_LISTNBOX;
    private _rows = [_ctrlList] call VA_fnc_listRows;

    // the locked items of a static tab don't change while the arsenal is open
    private _lockedByTab = _session get "lockedByTab";
    private _locked = _lockedByTab get _tab;

    if (isNil "_locked") then {
        _locked =([_display, _tab,
            _session] call SC_fnc_getArsenalCandidates) select {!([_session,
            _x] call SC_fnc_isArsenalItemUnlocked)};
        (_session get "nextUnlocks") set [_tab, [_session, _locked] call SC_fnc_formatNextUnlock];

        if (_tab in SC_var_arsenalStaticTabs) then {
            _lockedByTab set [_tab, _locked];
        };
    };

    if (_session get "showLocked") then {
        private _present = createHashMapFromArray (_rows apply {[toLowerANSI (_x select 0), true]});

        {
            if !(_x in _present) then {
                private _class = _classNames get _x;
                private _config = [_class, _tab] call SC_fnc_getArsenalItemConfig;
                private _text = getText (_config >> "displayName");

                [_ctrlList, _class, _text, getText (_config >> "picture")] call VA_fnc_listAddRow;
                _rows pushBack [_class, _text, ""];
                _present set [_x, true];
            };
        } forEach _locked;
    };

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
    private _equipped = ([_display, _center, _tab] call VA_fnc_getEquippedItems) apply {toLowerANSI _x};
    private _seen = missionNamespace getVariable ["SC_var_arsenalSeenItems", createHashMap];
    private _pendingSeen = _session get "pendingSeen";
    private _isShown = ctrlEnabled _ctrlList;
    private _playerRank = _session get "rank";
    private _perks = _session get "perks";
    private _sortByMod = !_isListN && {((uiNamespace getVariable ["bis_fnc_arsenal_sort", []]) param [_tab, 0]) > 0};
    private _styles = [];
    private _groups = [];

    // per row [group order, row kind (0 separator, 1 header, 2 item), locked, mod, rank, name, row index]
    private _sortKeys = [];

    {
        _x params ["_class", "_text", "_pictureRight"];

        private _key = toLowerANSI _class;

        if (_key == "") then {
            // the arsenal's own first row (<Empty>) stays first and unchanged
            _styles pushBack [];
            _sortKeys pushBack [-1, 0, 0, "", 0, "", _forEachIndex];
        } else {
            private _unlocked = _unlockedCache get _key;

            if (isNil "_unlocked") then {
                _unlocked = [_session, _key] call SC_fnc_isArsenalItemUnlocked;
            };

            private _options = _requirements getOrDefault [_key, []];
            private _texts = _optionTexts getOrDefault [_key, []];
            private _optionIndex = [_options, _playerRank, _perks] call SC_fnc_getArsenalOptionIndex;
            (_options param [_optionIndex, [0, ""]]) params ["_rank", "_perk"];

            private _rankText = if (_options isEqualTo []) then {""} else {format ["R%1", _rank]};
            private _isEquipped = _key in _equipped;
            private _tooltip = format ["%1\n%2", _text, _class];
            private _modIcon = "";

            if !_isListN then {
                if !(([_pictureRight] call SC_fnc_normalizeArsenalPath) in SC_var_arsenalOwnIcons) then {
                    SC_var_arsenalModIcons set [_key, _pictureRight];
                };

                _modIcon = SC_var_arsenalModIcons getOrDefault [_key, ""];
            };

            if _unlocked then {
                private _isNew = (_options isNotEqualTo []) && {!(_key in _seen)};

                if (_isNew && _isShown) then {
                    _pendingSeen set [_key, true];
                };

                if (_texts isNotEqualTo []) then {
                    _tooltip = _tooltip + "\nUnlocked at " + (_texts select _optionIndex);
                };

                // list-n-boxes (cargo) keep the arsenal's colors, which dim items that don't fit
                private _color = [_colorText, []] select _isListN;
                private _icon = _modIcon;
                private _iconColor = _colorText;

                if _isEquipped then {
                    _color = _colorAccent;
                    _icon = SC_var_arsenalEquippedIcon;
                    _iconColor = _colorAccent;
                };

                _styles pushBack [
                    (["", "NEW · "] select _isNew) + _rankText,
                    [_colorDim, _colorAccent] select _isNew,
                    _color,
                    [_colorText, []] select _isListN,
                    _icon,
                    _iconColor,
                    _tooltip
                ];
            } else {
                private _rankMissing = (_options isNotEqualTo []) && {_rank > _playerRank};
                private _perkMissing = (_perk != "") && {!(_perk in _perks)};
                private _missing = [_rank, _perk, _playerRank, _perks] call SC_fnc_formatMissingRequirement;

                // the reason icon: a missing perk first (its rank shows in the warning colored rank text)
                private _icon = SC_var_arsenalLockedIcon;
                private _iconColor = _colorDim;

                if (_perkMissing || _rankMissing) then {
                    _icon = if _perkMissing then {SC_var_arsenalPerkIcons getOrDefault [_perk,
                        SC_var_arsenalPerkIcon]} else {SC_var_arsenalRankIcon};
                    _iconColor = _colorWarning;
                };

                _tooltip = _tooltip + (switch true do {
                    case (_options isEqualTo []): {"\nNot available"};
                    case (_missing == ""): {"\nLocked: requires " + (_texts joinString " or ")};
                    default {
                        private _others = +_texts;
                        _others deleteAt _optionIndex;

                        "\nLocked: " + _missing + (["", "\nAlso unlocked by " + (_others joinString " or ")] select (_others isNotEqualTo []))
                    };
                });

                // an equipped locked item can be kept: its name in the accent color
                _styles pushBack [
                    _rankText,
                    [_colorLocked, _colorWarning] select _rankMissing,
                    [_colorLocked, _colorAccent] select _isEquipped,
                    _colorLocked,
                    _icon,
                    _iconColor,
                    _tooltip
                ];
            };

            _groups pushBackUnique _perk;
            _sortKeys pushBack [[_perk, _perks] call SC_fnc_getArsenalGroupOrder, 2,[1, 0] select _unlocked,
                ["", _modIcon] select _sortByMod, _rank, toLowerANSI _text, _forEachIndex];
        };
    } forEach _rows;

    [_ctrlList, _styles] call VA_fnc_listStyleRows;

    // the header rows are added after the item rows, in the order of _sortKeys
    if (((count _groups) > 1) || {(_groups param [0, ""]) != ""}) then {
        private _groupOrders = _groups apply {[[_x, _perks] call SC_fnc_getArsenalGroupOrder, _x]};
        _groupOrders sort true;

        {
            _x params ["_groupOrder", "_perk"];

            if (_forEachIndex > 0) then {
                _sortKeys pushBack [_groupOrder, 0, 0, "", 0, "", [_ctrlList] call VA_fnc_listAddHeader];
            };

            ([_perk, _playerRank, _perks] call SC_fnc_getArsenalGroupHeader) params ["_text", "_icon", "_textRight", "_tooltip"];
            _sortKeys pushBack [_groupOrder, 1, 0, "", 0, "",
                [_ctrlList, _text, _icon, _colorAccent, _textRight, _colorWarning,
                _tooltip] call VA_fnc_listAddHeader];
        } forEach _groupOrders;
    };

    // the position of each row in the order of _sortKeys
    private _order = +_sortKeys;
    _order sort true;

    private _sortValues = [];
    _sortValues resize (count _sortKeys);

    {
        _sortValues set [_x select 6, _forEachIndex];
    } forEach _order;

    [_ctrlList, _sortValues] call VA_fnc_listSort;
};

// ---- header ----

// VA_var_tabDecorator: "Rank 23 · next: <item> (Rank 24)" above the arsenal for the open tab (all tabs if none),
// hidden with the arsenal's interface
SC_fnc_decorateArsenalTab = {
    params ["_display", "_tab"];

    private _session = [_display] call SC_fnc_getArsenalSession;
    private _ctrlHeader = _display getVariable ["SC_var_arsenalHeader", controlNull];

    if (isNull _ctrlHeader) then {
        _ctrlHeader = _display ctrlCreate ["SC_ArsenalHeader", -1];
        _display setVariable ["SC_var_arsenalHeader", _ctrlHeader];
    };

    private _nextUnlocks = _session get "nextUnlocks";
    private _next = _nextUnlocks get _tab;

    if (isNil "_next") then {
        _next = _nextUnlocks get -1;

        if (isNil "_next") then {
            private _locked = (keys ((_session get "unlockData") select 0)) select {!([_session, _x] call SC_fnc_isArsenalItemUnlocked)};
            _next = [_session, _locked] call SC_fnc_formatNextUnlock;
            _nextUnlocks set [-1, _next];
        };
    };

    _ctrlHeader ctrlSetText format ["Rank %1 · %2", _session get "rank", ["all items unlocked", _next] select (_next != "")];
    _ctrlHeader ctrlShow (ctrlShown (_display displayCtrl IDC_RSCDISPLAYARSENAL_CONTROLSBAR_CONTROLBAR));
};

// ---- NEW markers ----

// classes (lower case) the player has seen unlocked in the arsenal, per world group in the profile; without stored data
// everything unlocked so far counts as seen, so only later unlocks (rank up, perk change) are marked NEW
SC_fnc_loadArsenalSeenItems = {
    private _list = ["SC_var_arsenalSeenItems"] call SC_fnc_getProgressList;

    if(!(_list isEqualType []) ||
        {(_list findIf {!(_x isEqualType []) || {(count _x) != 2} ||
        {!((_x select 0) isEqualType "")}}) != -1}) then {
        ["SC_var_arsenalSeenItems", []] call SC_fnc_setProgressList;
    };

    private _stored = ["SC_var_arsenalSeenItems", -1] call SC_fnc_getWorldGroupProfileEntry;

    if ((_stored isEqualType []) && {(_stored findIf {!(_x isEqualType "")}) == -1}) exitWith {
        SC_var_arsenalSeenItems = createHashMapFromArray (_stored apply {[_x, true]});
    };

    SC_var_arsenalSeenItems = createHashMap;

    // [weapons, backpacks, items, magazines]; the arsenal lists weapons as their base weapon
    private _unlockedItems = [side (group player), SC_var_perks, player getVariable ["SC_var_rank", 1]] call SC_fnc_getItems;

    {
        {
            SC_var_arsenalSeenItems set [toLowerANSI _x, true];
        } forEach _x;
    } forEach _unlockedItems;

    {
        SC_var_arsenalSeenItems set [toLowerANSI (_x call BIS_fnc_baseWeapon), true];
    } forEach (_unlockedItems select 0);

    ["SC_var_arsenalSeenItems", keys SC_var_arsenalSeenItems] call SC_fnc_setWorldGroupProfileEntry;
};

// after the arsenal closed: the NEW items shown in it count as seen
SC_fnc_saveArsenalSeenItems = {
    params ["_session"];

    private _pendingSeen = _session get "pendingSeen";

    if ((count _pendingSeen) == 0) exitWith {};

    SC_var_arsenalSeenItems merge _pendingSeen;
    ["SC_var_arsenalSeenItems", keys SC_var_arsenalSeenItems] call SC_fnc_setWorldGroupProfileEntry;
    saveProfileNamespace;
};
