// The whole combat_hud code is mostly c0mb1ne's (Training Polygon), I just rewrote it to fit my needs

notificationContainer=$('#popup').GetParent()
var id = 0

var welcome_num = Math.floor(Math.random() * 3)
welcome_msg = "RoundStart"+welcome_num
$.Msg(welcome_msg)
$.Schedule(3, function(){Game.EmitSound(welcome_msg)})

function createNotification(text, time = -1, killer)
{
    id = id + 1;
    var notification=$.CreatePanel('Panel', notificationContainer, 'notify_'+id)
    var slashContainer=$.CreatePanel('Panel',notification,'SlashContainer')
	var teamColorBar=$.CreatePanel('Panel',slashContainer,'TeamColorBar')
	var eventLabel=$.CreatePanel('Label',notification,'EventLabel')
    eventLabel.AddClass('EventListLabel')
    //notification.ToggleClass("HUDFlipped")

	notification.AddClass('NotificationPanel')
    if (time == -1)
        eventLabel.text=text
    else
    {
        var t = parseFloat(time)
        eventLabel.text=text + t.toFixed(3) + "s"
    }
    $.Msg(eventLabel.text)

    if (killer == "hero")
    {
        notification.AddClass('AllyEvent')
		Game.EmitSound("GoodCS0")
        eventLabel.AddClass('Skilled')
        var skillIcon=$.CreatePanel('Panel',eventLabel,'notifyIcon')
        skillIcon.AddClass('gotCS')
    }
    else
    {
        notification.AddClass('EnemyEvent')
		Game.EmitSound("BadCS0")
        eventLabel.AddClass('Skilled')
        var skillIcon=$.CreatePanel('Panel',eventLabel,'notifyIcon')
        skillIcon.AddClass('missedCS')
    }

    notification.AddClass('NotPanelAnimate')
	$.Schedule(8, function(){ hideNotification(notification);})
}

function hideNotification(panel){
	panel.AddClass('NotificationCollapse')
}
function showNotification(panel){
	panel.RemoveClass('NotificationCollapse')
}

function showNotify(data){
	createNotification(data.text, data.time, data.killer)
}

 GameEvents.Subscribe("show_notification", showNotify);