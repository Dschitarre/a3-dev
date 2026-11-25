// Battle Royale on Altis. Variant config: the build replaces BR\maps\mapData.hpp by this file (cfg\variantConfigs.txt).
// Positions are 2D [x, y]; radii and heights in metres. The play area is always all land of the map and the combatants
// on Auto follow its land area (BR\maps\maps.sqf).
// Another map needs its own mapData<map>.hpp and missionFiles\mission<map>.sqm (plus a cfg\maps.txt line).
class BR_mapData {
    startAreaCenter[] = {11461, 11662};     // AAC Airfield, warmup
    startAreaRadius = 120;
    flightHeight = 450;                     // height of the transport flight above the terrain
};
