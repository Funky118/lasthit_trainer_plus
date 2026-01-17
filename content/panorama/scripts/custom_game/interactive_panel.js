var nemesisAttackSpeed = 0;
var attackSpeedTimer = null;
var attackSpeedDelta = 0;
var expChange = 0;
var choosing_enemy = false;

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
	choosing_enemy = false;
	$('#ControlPanel').ToggleClass('HeroPickerVisible');
}
function ToggleEnemyHeroPicker()
{
	choosing_enemy = true;
	$('#ControlPanel').ToggleClass('HeroPickerVisible');
}

function ToggleAdvancedSettings()
{
	$('#AdvancedScreen').ToggleClass('Invisible')
}

function SwitchToNewHero( nHeroID )
{
	$('#ControlPanel').RemoveClass('HeroPickerVisible');
	if (choosing_enemy)
		$.DispatchEvent('FireCustomGameEvent_Str', 'SwitchToNewEnemyHero', String(nHeroID));
	else
		$.DispatchEvent('FireCustomGameEvent_Str', 'SwitchToNewHero', String(nHeroID));
}

function SwitchToNewEnemyHero( nHeroID )
{
	$.Msg("Switching to new enemy")
	$('#ControlPanel').RemoveClass('HeroPickerVisible');
	$.DispatchEvent('FireCustomGameEvent_Str', 'SwitchToNewEnemyHero', String(nHeroID));
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
		nemesisAttackSpeed-=5;
		SetText("#AttackSpeedTextBox",nemesisAttackSpeed);
		$.DispatchEvent('FireCustomGameEvent_Str', "NemesisAttackSpeedChange", String(nemesisAttackSpeed));
	}
	else if(attackSpeedDelta > 0 && nemesisAttackSpeed < 700)
	{
		nemesisAttackSpeed+=5;
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

function SlideThumbActivate()
{
	$( "#ControlPanel" ).ToggleClass( "Minimized" );
	$('#ControlPanel').RemoveClass('HeroPickerVisible');
	$('#AdvancedScreen').AddClass('Invisible')
}

function NemesisModeActivate()
{
	$("#NemesisSettingButtons").ToggleClass("Faded")
	$.DispatchEvent('FireCustomGameEvent_Str', 'EnableUnfairButtonPressed', '' );
}
function DamageThresholdValueChanged()
{
	var slider = $("#MySlider");
	var value = slider.value;
	
	$.Msg("Slider value: ", value);
	var text = "Damage threshold: " + Math.round(value*10);
	SetText("#DamageThresholdNum",text);
}
function AttackSpeedValueChanged()
{
	var slider = $("#AttackSpeedSlider");
	var value = slider.value;

	value = ((value * 2)-1)*700;

	var text = "Bot attack speed " + Math.round(value);
	SetText("#AttackSpeedNum",text);

	$.DispatchEvent('FireCustomGameEvent_Str', "NemesisAttackSpeedChange", String(Math.round(value)));
}

function initSliders()
{
	var slider_thrs = $("#MySlider");
	var slider_atck = $("#AttackSpeedSlider");
	slider_thrs.value = 0.5;
	slider_atck.value = 0.5;

}

(function()
{
	//$.Msg("INITIALIZED PANORAMA JS: round end panel");
	// var slider = $("#MySlider");
	// slider.SetPanelEvent("onvaluechanged", function(){
	// 	var value = slider.value;
	// 	$.Msg("Slider value: ", value);
	// });

	$( "#ControlPanel" ).ToggleClass( "Minimized" );
	initSliders()
	GameEvents.Subscribe( "round_ended", OnRoundEnded );
	GameEvents.Subscribe("update_nemesis_attack_speed", UpdateNemesisAttackSpeed)

	$.RegisterEventHandler('DOTAUIHeroPickerHeroSelected', $('#ControlPanel'), SwitchToNewHero );
})();
