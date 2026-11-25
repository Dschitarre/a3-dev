// Battle Royale on Stratis. Variant config: the build replaces BR\maps\mapData.hpp by this file (cfg\variantConfigs.txt).
// Positions are 2D [x, y]; radii and heights in metres. The start area is the world's airfield (BR_fnc_defaultStartArea),
// the play area is always all land of the map and the combatants on Auto follow its land area (BR\maps\maps.sqf).
class BR_mapData {
    startAreaRadius = 120;
    flightHeight = 450;                     // height of the transport flight above the terrain
};
