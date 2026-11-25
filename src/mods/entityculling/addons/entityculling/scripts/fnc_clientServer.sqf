// Entity culling (server and clients): the settings. Missions may set them before the mod loads; the module sets
// them on the server and publishes them. EC_var_enabled may change at any time, also on a single client: false
// reveals everything there and pauses the culling.

if (isNil "EC_var_enabled") then {EC_var_enabled = true;};
if (isNil "EC_var_frameBudget") then {EC_var_frameBudget = 0.001;};     // seconds of visibility tests per frame
if (isNil "EC_var_minDistance") then {EC_var_minDistance = 10;};        // metres: nearer entities are never hidden
if (isNil "EC_var_checkInterval") then {EC_var_checkInterval = 0.2;};   // seconds between two checks of a visible entity
if (isNil "EC_var_hideAfterChecks") then {EC_var_hideAfterChecks = 3;}; // invisible checks in a row before hiding
if (isNil "EC_var_lookahead") then {EC_var_lookahead = 0.5;};           // seconds of movement a check covers
if (isNil "EC_var_debug") then {EC_var_debug = false;};                 // overlay: hidden entities, worker time, fps

EC_var_clientServerInitDone = true;
