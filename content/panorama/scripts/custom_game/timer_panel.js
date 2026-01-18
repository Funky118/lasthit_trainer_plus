var cancelPractice = true;
var overTime = false;

function SetText(name, value)
{
	var element = $(name);

	if(element == null)
		return;

	element.text = value;
}

function Zeropad(number)
{
	if(number < 10)
		return "0" + number;

	return "" + number;
}

function TimedPractice()
{
    if(cancelPractice)
        return;

	var maxSeconds = gGameInfo.TimedPracticeDuration;
	var timeRemaining = maxSeconds - ( Game.GetGameTime() - gGameInfo.TimedPracticeStartTime );

	if (overTime)
	{
		$( "#TimerRemaining" ).SetHasClass( "overtime", true );
	}
	else
	{
		$( "#TimerRemaining" ).SetHasClass( "overtime", false );
	}

	if ( timeRemaining >= 0 )
	{
		var minutes = Zeropad( Math.floor( timeRemaining / 60 ) );
		var seconds = Zeropad( Math.floor( timeRemaining - minutes * 60 ) );

		SetText( '#TimerRemaining', "" + minutes + ":" + seconds );
	}

	$.Schedule( 1, TimedPractice );
}

function TimedPracticeStart(data)
{
	gGameInfo = data;
    cancelPractice = false;
    overTime = false;
    $("#TimedTrainingPanel").RemoveClass("Invisible")
	TimedPractice();
}

function TimedPracticeEnd()
{
    cancelPractice = true;
	$("#TimedTrainingPanel").AddClass("Invisible")
}

function TimedPracticeOvertime()
{
    overTime = true;
}

(function()
{
	$("#TimedTrainingPanel").AddClass("Invisible")
    GameEvents.Subscribe("timed_practice_start", TimedPracticeStart)
    GameEvents.Subscribe("timed_practice_end", TimedPracticeEnd)
    GameEvents.Subscribe("timed_practice_overtime", TimedPracticeOvertime)
})();
