gStats = {
	"LastHitCount" : 0, 
    "LastHitTotal": 0,
    "DenyCount": 0,
    "DenyTotal": 0,
    "CumLasthitTime": 0,
    "MeleeCreepsKilled": 0,
    "MeleeCreepsDenied": 0,
    "MeleeCreepsBadguysMissed":0,
    "MeleeCreepsLost":0,
    "FlagCreepsKilled": 0,
    "FlagCreepsDenied": 0,
    "FlagCreepsBadguysMissed":0,
    "FlagCreepsLost":0,
    "RangedCreepsKilled": 0,
    "RangedCreepsDenied": 0,
    "RangedCreepsBadguysMissed":0,
    "RangedCreepsLost":0,
    "SiegeCreepsKilled" : 0,
    "SiegeCreepsDenied" : 0,
    "SiegeCreepsBadguysMissed": 0,
    "SiegeCreepsLost": 0
};

exp_to_level = [0,240,640,1160,1760,2440,3200,4000,4900,5900,7000,8200,9500,10900,12400,14000,15700,17500,19400,21400,23600,26000,28600,31400,34400,38400,43400,49400,56400,63900]

var lasthit_delay = [];

// var test_delay = [-0.3,0,-0.4,-0.3,0,-0.4,0.3,0,0.4,0.3,0,0.4,-0.7, 1];
// OpenInfoScreen();
// var sine_values = [];
// for (var i = 0; i <= 100; i++)
// {
// 	sine_values.push(Math.sin(Math.PI * 2 * i/20));
// }

function OpenInfoScreen()
{
    var killedPercentage = 0;
    if (gStats["LastHitTotal"]+gStats["DenyTotal"] == 0)
        lasthit_delay = [];
    else
        killedPercentage = Math.round(100*(gStats["LastHitCount"]+gStats["DenyCount"])/(gStats["LastHitTotal"]+gStats["DenyTotal"]));
    // TODO: This ignores xp and gold upgrade interval
    var total_exp_hero = (gStats["MeleeCreepsBadguysMissed"]*57 + gStats["RangedCreepsBadguysMissed"]*69 + gStats["SiegeCreepsBadguysMissed"]*88) + (gStats["MeleeCreepsKilled"]*57 + gStats["RangedCreepsKilled"]*69 + gStats["SiegeCreepsKilled"]*88);
    var gold_missed = (gStats["MeleeCreepsBadguysMissed"]*37 + gStats["FlagCreepsBadguysMissed"]*37 + gStats["RangedCreepsBadguysMissed"]*48 + gStats["SiegeCreepsBadguysMissed"]*66);
    var exp_lost = (gStats["MeleeCreepsLost"]*57 + gStats["RangedCreepsLost"]*69 + gStats["SiegeCreepsLost"]*88)/2;

    var deniedExp = (gStats["MeleeCreepsDenied"]*57 + gStats["RangedCreepsDenied"]*69 + gStats["SiegeCreepsDenied"]*88)/2;
    var deniedGold = gStats["MeleeCreepsDenied"]*37 + gStats["FlagCreepsDenied"]*37 + gStats["RangedCreepsDenied"]*48 + gStats["SiegeCreepsDenied"]*66;
    var gainedExp = total_exp_hero-exp_lost;
    // var enemyExp = total_exp_hero-deniedExp;
    var gainedGold = gStats["MeleeCreepsKilled"]*37 + gStats["FlagCreepsKilled"]*37 + gStats["RangedCreepsKilled"]*48 + gStats["SiegeCreepsKilled"]*66;
    var expLoss =  exp_lost;
    var goldLoss = gold_missed;

    // var hero_lvl = 0;
    // var enemy_lvl = 0;
    // for(var i=0; i < 30; i++)
    // {
    //     if(gainedExp >= exp_to_level[i])
    //         hero_lvl = i+1;
    //     if(enemyExp >= exp_to_level[i])
    //         enemy_lvl = i+1;
    //     if(gainedExp < exp_to_level[i] && enemyExp < exp_to_level[i])
    //         break;
    // }

    $("#InfoScreen").ToggleClass("Invisible");
    SetText("#KilledPercentage", killedPercentage + "%");
    SetText("#DeniedExp", deniedExp);// + "(enemy level: "+ enemy_lvl + ")");
    SetText("#DeniedGold", deniedGold);
    SetText("#GainedExp", gainedExp)// + "(your level: " + hero_lvl + ")");
    SetText("#GainedGold", gainedGold);
    SetText("#ExpLoss", expLoss);
    SetText("#GoldLoss", goldLoss);
    DrawGraph($("#TestGraph"), lasthit_delay, 150,570,0);
}

function CloseInfoScreen()
{
    $("#InfoScreen").ToggleClass("Invisible");
}

function DrawGraph(graphPanel, values, graphHeight, graphWidth)
{
    // --- Setup ---
    graphPanel.RemoveAndDeleteChildren();

    var tooltip = $("#GraphTooltip");
    var tooltipLabel = $("#GraphTooltipLabel");

    var maxValue = Math.max(...values);
    var minValue = Math.min(...values);
    var stepX = 0;
    if((values.length - 1) == 0)
        stepX = 0;
    else
        stepX = graphWidth / (values.length - 1);

    var points = [];

    // --- Draw data points ---
    for (var i = 0; i < values.length; i++) {
        let value = Number(values[i]);

        var x = i * stepX;
        var y = 0;
        var scale = 1;
        if (Math.abs(minValue) >= maxValue)
            scale = Math.abs(minValue)*2;
        else
            scale = maxValue*2;
        
        if (scale == 0)
            y = 0;
        else
        {
            y = graphHeight*2 - ((value + scale/2)/(scale) * graphHeight*2);
        }
        
        var dot = $.CreatePanel("Panel", graphPanel, "");
        dot.AddClass("GraphDot");
        dot.hittest = true;

        dot.style.x = (x - 4) + "px";
        dot.style.y = (y - 4) + "px";

        points.push({ x: x, y: y, value: value });

        // --- Tooltip handling ---
        dot.SetPanelEvent("onmouseover", function () {
            tooltipLabel.text = value.toString();
            tooltip.visible = true;

            UpdateTooltipPosition(tooltip);
        });

        dot.SetPanelEvent("onmousemove", function () {
            UpdateTooltipPosition(tooltip);
        });

        dot.SetPanelEvent("onmouseout", function () {
            tooltip.visible = false;
        });
    }

    // --- Draw connecting lines ---
    for (var i = 0; i < points.length - 1; i++) {
        DrawLineSegment(graphPanel, points[i], points[i + 1]);
    }

    // --- Draw Y-axis grid and labels ---
    DrawYGrid(graphPanel, graphHeight, graphWidth, maxValue, minValue);
}

function UpdateTooltipPosition(tooltip)
{
    var cursor = GameUI.GetCursorPosition();
    tooltip.style.x = (cursor[0] + 12) + "px";
    tooltip.style.y = (cursor[1] + 12) + "px";
}

function DrawLineSegment(parent, p1, p2)
{
    var dx = p2.x - p1.x;
    var dy = p2.y - p1.y;

    var length = Math.sqrt(dx * dx + dy * dy);
    var angle = Math.round(Math.atan2(dy, dx) * 180 / Math.PI);

    var line = $.CreatePanel("Panel", parent, "");
    line.AddClass("GraphLine");
    line.hittest = false;

    line.style.x = p1.x + "px";
    line.style.y = p1.y + "px";
    line.style.width = length + "px";
    line.style.transform = "rotateZ(" + angle + "deg)";
}

function DrawYGrid(parent, height, width, maxValue, minValue)
{
    var GRID_STEPS = 4;

    for (var i = 0; i <= GRID_STEPS; i++) {
        var t = i / GRID_STEPS;
        var y = 2*height * t;

        // Grid line
        var line = $.CreatePanel("Panel", parent, "");
        line.AddClass("GraphGridLine");
        line.hittest = false;
        line.style.y = y + "px";

        // Label
        var label = $.CreatePanel("Label", parent, "");
        label.AddClass("GraphGridLabel");
        label.hittest = false;
        var scale = 0;
        if (Math.abs(minValue) >= maxValue)
            scale = Math.abs(minValue)*2
        else
            scale = maxValue*2

        var value = (-scale/2 + ((1 - t)/1)*(scale)).toFixed(2);
        label.text = value.toString();

        label.style.y = (y - height-4) + "px";
        label.style.x = (width+20) + "px";

        if (i === GRID_STEPS / 2) {
            line.AddClass("Middle");
            label.AddClass("Middle");
        }
    }
}

function saveLasthitDelay(data)
{
    if (data.killer == "hero")
    {
        $.Msg("Got lasthit");
        lasthit_delay.push(parseFloat(data.time).toFixed(3));
    }
    else if(data.text == "Too early ")
    {
        $.Msg("Got missed lasthit");
        lasthit_delay.push(parseFloat(-data.time).toFixed(3));
    }

}

function OnLastHitTrainerStatsUpdated( tableName, key, data )
{
	//$.Msg("STATS DATA RECEIVED")
	$.Msg(data)
	gStats = data;

	// var grid_basics_tab = $("#GridMainShop");
	// $.Msg(grid_basics_tab)
}

(function()
{
	//$.Msg("INITIALIZED PANORAMA JS: score panel");
	//CustomNetTables.SubscribeNetTableListener("last_hit_trainer_stats", OnLastHitTrainerStatsUpdated);
    GameEvents.Subscribe("show_notification", saveLasthitDelay);
    CustomNetTables.SubscribeNetTableListener("last_hit_trainer_stats", OnLastHitTrainerStatsUpdated);
})();
