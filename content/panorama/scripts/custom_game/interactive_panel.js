gStats = {
	"LastHitCount" : 0, 
	"LastHitTotal": 0,
	"DenyCount": 0,
	"DenyTotal": 0,
    "AverageLasthitTime": 0,
    "MeleeCreepsKilled": 0,
	"MeleeCreepsDenied": 0,
	"RangedCreepsKilled": 0,
	"RangedCreepsDenied": 0,
	"GoldSecured": 0
};
var nemesisAttackSpeed = 0
var attackSpeedTimer = null
var attackSpeedDelta = 0
var expChange = 0

// Put this into a function
var graph = $("#Graph1");
graph.RemoveAndDeleteChildren();

var values = [10, 20, 30, 40, 50];
var max = Math.max(...values);

for (var i = 0; i < values.length; i++) {
    var bar = $.CreatePanel("Panel", graph, "");
    bar.style.width = "6px";
    bar.style.height = (values[i] / max * 100) + "px";
    bar.style.backgroundColor = "#17eb17ff";
    bar.style.marginRight = "4px";
	bar.style.verticalAlign = "bottom"
}

var graph2 = $("#Graph2");
graph2.RemoveAndDeleteChildren();

var values = [0, 10, 20, 30, 40, 50];
var max = Math.max(...values);

var graphWidth = 50;
var graphHeight = 50;
var stepX = graphWidth / (values.length - 1);

for (var i = 0; i < values.length; i++) {
    var dot = $.CreatePanel("Panel", graph2, "");
    dot.AddClass("GraphDot");
	let value = values[i];
	dot.hittest = true;

    var x = i * stepX;
    var y = graphHeight - (values[i] / max * graphHeight);

    dot.style.x = (x - 4) + "px";
    dot.style.y = (y - 4) + "px";


	dot.SetPanelEvent("onmouseover", function () {
		$.DispatchEvent("DOTAShowTextTooltip", dot, "Value: " + value);
	});

	dot.SetPanelEvent("onmouseout", function () {
		$.DispatchEvent("DOTAHideTextTooltip");
	});

	dot.SetPanelEvent("onmouseover", function () {
		$.Msg("Hovered dot:", value);
	});
}
////////////

SetText("#AttackSpeedTextBox", nemesisAttackSpeed)

// Unused, maybe I will add splash screen back for info (in which case go to Valve's source code)
function HideSplashScreen()
{
	$( "#splash_screen_container" ).SetHasClass( "VisibilityCollapsed", true );
}

function PlayAgainButtonPressed()
{
	$( "#ControlPanel" ).ToggleClass( "Minimized" );
	$.DispatchEvent('FireCustomGameEvent_Str', 'RoundRestartButtonPressed', '' );
}

function RoundEndNewHeroButtonPressed()
{
	$( "#ControlPanel" ).ToggleClass( "Minimized" );
	ToggleHeroPicker();
}

function OnRoundEnded( roundEndData )
{
	//$.Msg( "OnRoundEnded" )

	$( "#RoundEndPanel" ).SetHasClass( "Visible", true );
	//Game.EmitSound( "RoundStart" );
	//$.Schedule( 5.0, HideModeStart );
	//$.DispatchEvent( "DOTAHUDHideScoreboard" )

	return true;
}

function ToggleHeroPicker()
{
	$('#ControlPanel').ToggleClass('HeroPickerVisible');
}

function SwitchToNewHero( nHeroID )
{
	$('#ControlPanel').RemoveClass('HeroPickerVisible');
	$.DispatchEvent('FireCustomGameEvent_Str', 'SwitchToNewHero', String(nHeroID));
}

function Start_AttackSpeedChange(delta)
{
	if(attackSpeedTimer != null)
		return;
	if($("#NemesisSettingButtons").BHasClass("Faded"))
		return;
	attackSpeedDelta = delta;
	AttackSpeedChange();
}

function AttackSpeedChange()
{
	if(attackSpeedDelta < 0 && nemesisAttackSpeed > -700)
	{
		nemesisAttackSpeed-=10;
		SetText("#AttackSpeedTextBox",nemesisAttackSpeed);
		$.DispatchEvent('FireCustomGameEvent_Str', "NemesisAttackSpeedChange", String(nemesisAttackSpeed));
	}
	else if(attackSpeedDelta > 0 && nemesisAttackSpeed < 700)
	{
		nemesisAttackSpeed+=10;
		SetText("#AttackSpeedTextBox",nemesisAttackSpeed);
		$.DispatchEvent('FireCustomGameEvent_Str', "NemesisAttackSpeedChange", String(nemesisAttackSpeed));
	}
	expChange++;
	var delay = 0.15 - 0.1*(1/(Math.exp(1/(expChange*0.1))));
	attackSpeedTimer = $.Schedule(delay, AttackSpeedChange);
}

function Stop_AttackSpeedChange()
{
	attackSpeedDelta = 0;
	if(attackSpeedTimer != null)
	{
		$.CancelScheduled(attackSpeedTimer);
	}
	attackSpeedTimer = null;
	expChange = 0;
}

function UpdateNemesisAttackSpeed(data)
{
	nemesisAttackSpeed = data.attack_speed
	SetText("#AttackSpeedTextBox",nemesisAttackSpeed);
}

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
	SetText('#MeleeCreepsKilled', gStats["MeleeCreepsKilled"]);
	SetText('#MeleeCreepsDenied', gStats["MeleeCreepsDenied"]);
	SetText('#RangedCreepsKilled', gStats["RangedCreepsKilled"]);
	SetText('#RangedCreepsDenied', gStats["RangedCreepsDenied"]);
	// SetText('#GoldFromMeleeCreeps', gStats["GoldFromMeleeCreeps"]);
	// SetText('#GoldFromRangedCreeps', gStats["GoldFromRangedCreeps"]);

}

function OnLastHitTrainerStatsUpdated( tableName, key, data )
{
	//$.Msg("STATS DATA RECEIVED")
	gStats = data;

	UpdateScores();
}

function SlideThumbActivate()
{
	$( "#ControlPanel" ).ToggleClass( "Minimized" );
	$('#ControlPanel').RemoveClass('HeroPickerVisible');
}

function NemesisModeActivate()
{
	$("#NemesisSettingButtons").ToggleClass("Faded")
	$.DispatchEvent('FireCustomGameEvent_Str', 'EnableUnfairButtonPressed', '' );
}

(function()
{
	//$.Msg("INITIALIZED PANORAMA JS: round end panel");

	$( "#ControlPanel" ).ToggleClass( "Minimized" );

	GameEvents.Subscribe( "round_ended", OnRoundEnded );
	GameEvents.Subscribe("update_nemesis_attack_speed", UpdateNemesisAttackSpeed)

	// CustomNetTables.SubscribeNetTableListener("last_hit_trainer_stats", OnLastHitTrainerStatsUpdated);

	$.RegisterEventHandler('DOTAUIHeroPickerHeroSelected', $('#ControlPanel'), SwitchToNewHero );
})();
