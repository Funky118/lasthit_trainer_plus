gStats = {
	"LastHitCount" : 0, 
	"LastHitTotal": 0,
	"DenyCount": 0,
	"DenyTotal": 0,
    "CumLasthitTime": 0
};

$.RegisterForUnhandledEvent("DOTAHUDShopOpened", () => {$.Msg("Shop opened!")});
$.RegisterForUnhandledEvent("DOTAHUDShopOpened", () => {$.Msg("Shop closed!")});

function SetText(name, value)
{
	var element = $(name);

	if(element == null)
		return;

	element.text = value;
}

function UpdateScores()
{
	SetText('#CreepsLastHit', gStats["LastHitCount"] + "/" + gStats["LastHitTotal"]);
	SetText('#CreepsDenied', gStats["DenyCount"] + "/" + gStats["DenyTotal"]);
	var avg_cs_time = gStats["CumLasthitTime"]/(gStats["LastHitCount"]+gStats["DenyCount"])
    SetText('#AverageLasthitTime', avg_cs_time.toFixed(3));
}

function OnLastHitTrainerStatsUpdated( tableName, key, data )
{
	//$.Msg("STATS DATA RECEIVED")
	$.Msg(data)
	gStats = data;

	// var grid_basics_tab = $("#GridMainShop");
	// $.Msg(grid_basics_tab)
	
	UpdateScores();
}

(function()
{
	//$.Msg("INITIALIZED PANORAMA JS: score panel");
	CustomNetTables.SubscribeNetTableListener("last_hit_trainer_stats", OnLastHitTrainerStatsUpdated);

	UpdateScores();
})();