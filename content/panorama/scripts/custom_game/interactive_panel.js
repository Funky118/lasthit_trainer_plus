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
}

(function()
{
	//$.Msg("INITIALIZED PANORAMA JS: round end panel");

	$( "#ControlPanel" ).ToggleClass( "Minimized" );

	GameEvents.Subscribe( "round_ended", OnRoundEnded );

	// CustomNetTables.SubscribeNetTableListener("last_hit_trainer_stats", OnLastHitTrainerStatsUpdated);

	$.RegisterEventHandler('DOTAUIHeroPickerHeroSelected', $('#ControlPanel'), SwitchToNewHero );
})();
