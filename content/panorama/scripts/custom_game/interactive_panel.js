var nemesisAttackSpeed = 0;
var nemesisAttackSpeedToSend = 0;
var sendingAttackSpeed = false;
var attackSpeedTimer = null;
var attackSpeedDelta = 0;
var expChange = 0;
var choosing_enemy = false;
var maxHeroDmg = 40;
var avgHeroDmg = 40;
var minHeroDmg = 40;
var bonusHeroDmg = 0;
var timedPracticeSeconds = 30;
var gameSpeed = 1;

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
	$("#InfoScreen").AddClass("Invisible");
	$('#AdvancedScreen').AddClass('Invisible')
	$('#ControlPanel').ToggleClass('HeroPickerVisible');
}
function ToggleEnemyHeroPicker()
{
	choosing_enemy = true;
	$('#ControlPanel').ToggleClass('HeroPickerVisible');
	$('#AdvancedScreen').AddClass('Invisible')
	$("#InfoScreen").AddClass("Invisible");
}

function ToggleAdvancedSettings()
{
	$('#AdvancedScreen').ToggleClass('Invisible')
	$('#ControlPanel').RemoveClass('HeroPickerVisible');
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

function TimedPracticeChange(delta)
{
	if (delta < 0)
	{
		if(timedPracticeSeconds > 30)
			timedPracticeSeconds -= 30;
	}
	else
	{
		timedPracticeSeconds += 30;
	}
	var minutes = Math.floor(timedPracticeSeconds/60);
	var seconds = timedPracticeSeconds%60;
	if(seconds == 0)
		SetText("#TimedPracticeTextBox", minutes+":"+seconds+"0")
	else
		SetText("#TimedPracticeTextBox", minutes+":"+seconds)
	$.DispatchEvent('FireCustomGameEvent_Str', 'TimedPracticeChanged', String(timedPracticeSeconds) );
}

function GameSpeedChange(delta)
{
	var text = "dec";
	if(delta < 0)
	{
		if(gameSpeed <= 0.1)
			return;
		if(gameSpeed == 1)
			gameSpeed = 0.8;
		else if(gameSpeed < 1 && gameSpeed > 0.1)
			gameSpeed = gameSpeed/2;
		else
			gameSpeed -= 1;
		text = "dec";
	}
	else
	{
		if(gameSpeed >= 10)
			return;
		if(gameSpeed == 0.8)
			gameSpeed = 1;
		else if(gameSpeed < 0.8)
			gameSpeed = gameSpeed*2;
		else if(gameSpeed < 10)
			gameSpeed += 1;
		text = "inc";
	}

	SetText("#GameSpeedTextBox", gameSpeed)
	$.DispatchEvent('FireCustomGameEvent_Str', 'GameSpeedChanged', String(gameSpeed) );
}

function UpdateNemesisAttackSpeed(data)
{
	nemesisAttackSpeed = data.attack_speed;
	if(nemesisAttackSpeed < -700)
		nemesisAttackSpeed = -700;
	else if(nemesisAttackSpeed > 700)
		nemesisAttackSpeed = 700;
	var text = "Bot attack speed " + Math.round(nemesisAttackSpeed);
	var slider = $("#AttackSpeedSlider");
	nemesisAttackSpeed = (nemesisAttackSpeed + 700)/1400;
	slider.value = nemesisAttackSpeed;
	SetText("#AttackSpeedNum", text);
}

function UpdateHeroDamage(data)
{
	maxHeroDmg = data.max;
	avgHeroDmg = data.avg;
	minHeroDmg = data.min;
	bonusHeroDmg = data.avg - Math.floor((data.min+data.max)/2);
	UpdateUIHeroDamage();
}

function UpdateUIHeroDamage()
{
	var slider = $("#DamageSlider");
	var value = slider.value;
	var diff = maxHeroDmg - minHeroDmg;

	var text = "Damage threshold: " + Math.round(minHeroDmg + diff*value + bonusHeroDmg);
	SetText("#DamageThresholdNum",text);
}

function TimedPracticeStart()
{
	SlideThumbActivate();
}

function TimedPracticeEnd()
{
	$( "#ControlPanel" ).RemoveClass( "Minimized" );
	$('#AdvancedScreen').RemoveClass('Invisible')
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
	//$("#NemesisSettingButtons").ToggleClass("Faded")
	$.DispatchEvent('FireCustomGameEvent_Str', 'EnableUnfairButtonPressed', '' );
}
function DamageThresholdValueChanged()
{
	var slider = $("#DamageSlider");
	var value = slider.value;
	var diff = maxHeroDmg - minHeroDmg;

	var text = "Damage threshold: " + Math.round(minHeroDmg + Math.round(diff*value) + bonusHeroDmg);
	SetText("#DamageThresholdNum",text);
	$.DispatchEvent('FireCustomGameEvent_Str', "HeroDamageChange", String(Math.round(value*100)))
}
function AttackSpeedValueChanged()
{
	var slider = $("#AttackSpeedSlider");
	var value = slider.value;

	value = ((value * 2)-1)*700;
	nemesisAttackSpeedToSend = value;
	if(sendingAttackSpeed == false)
	{
		$.Schedule(0.1, SendAttackSpeedChange)
	}

	var text = "Bot attack speed " + Math.round(value);
	SetText("#AttackSpeedNum",text);

	
}

function TowerDamageValueChanged()
{
	var slider = $("#TowerDamageSlider");
	var value = slider.value;
	var value = Math.round((value*2)+1);

	var tier = "T1";
	if (value == 1)
		tier = "T1";
	else if(value == 2)
		tier = "T2";
	else if(value == 3)
		tier = "T3";
	else
		tier = "Undefined";

	$.Msg("Tier = "+value);

	var text = "Tower tier: " + tier;
	SetText("#TowerDamageText",text);
	$.DispatchEvent('FireCustomGameEvent_Str', "TowerDamageChange", value)
}

function CreepMeetingPointChanged()
{
	var slider = $("#MeetingPointSlider");
	var value = slider.value;
	value = ((value * 2)-1);

	var text = "Creep meeting point: " + Math.round(value*100)/100;
	SetText("#CreepMeetingText",text);
	$.DispatchEvent('FireCustomGameEvent_Str', "CreepMeetingPointChange", value*0.8)
}

function SendAttackSpeedChange()
{
	var value = nemesisAttackSpeedToSend;
	$.DispatchEvent('FireCustomGameEvent_Str', "NemesisAttackSpeedChange", String(Math.round(value)));
	sendingAttackSpeed = false;
}

function initSliders()
{
	var slider_thrs = $("#DamageSlider");
	var slider_atck = $("#AttackSpeedSlider");
	var slider_meet = $("#MeetingPointSlider");
	slider_thrs.value = 0.5;
	slider_atck.value = 0.5;
	slider_meet.value = 0.5;
}

function PauseButtonPressed()
{
  $.DispatchEvent('FireCustomGameEvent_Str', "LasthitTrainerPause", '');
}


(function()
{
	$("#AutoWaveButton").SetSelected(true);
	$("#DireSiegeButton").SetSelected(true);
	$("#RadiantSiegeButton").SetSelected(true);
	$("#DireRangedButton").SetSelected(true);
	$("#RadiantRangedButton").SetSelected(true);
	$("#DireMeleeButton").SetSelected(true);
	$("#RadiantMeleeButton").SetSelected(true);
	$( "#ControlPanel" ).ToggleClass( "Minimized" );
	initSliders()
	GameEvents.Subscribe( "round_ended", OnRoundEnded );
	GameEvents.Subscribe("update_nemesis_attack_speed", UpdateNemesisAttackSpeed)
	GameEvents.Subscribe("update_hero_damage", UpdateHeroDamage)
	GameEvents.Subscribe("timed_practice_start", TimedPracticeStart)
	GameEvents.Subscribe("timed_practice_end", TimedPracticeEnd)
	// The following five lines are all needed to enable unlimited pausing on the server
	var date = new Date();
	var unique_string = "+lasthit_trainer_pause"+date.getDay()+date.getMonth()+date.getYear()+date.getHours()+date.getMinutes()+date.getSeconds();
	$.Msg(unique_string)
	Game.AddCommand( unique_string, PauseButtonPressed, "", 0 );
	Game.CreateCustomKeyBind('F9', unique_string);

	$.RegisterEventHandler('DOTAUIHeroPickerHeroSelected', $('#ControlPanel'), SwitchToNewHero );
})();
