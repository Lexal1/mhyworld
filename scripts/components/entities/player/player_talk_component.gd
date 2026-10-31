class_name PlayerTalkComponent extends PlayerComponent
## Right click an entity you're looking at to talk to it.


func tick(_delta: float) -> void:
	if Global.is_paused() or not Input.is_action_just_pressed("mouse2"): return
	var dialogue := DialogueComponent.talkable(player.target_entity)
	if dialogue != null: dialogue.interact(player)
