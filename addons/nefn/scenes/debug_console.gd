extends Control

signal command_entered(command: String)

@onready var output: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Output
@onready var input: LineEdit = $Panel/MarginContainer/VBoxContainer/Input

func _ready() -> void:
	visible = false  # Set initial visibility state
	input.text_submitted.connect(_on_input_submitted)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # This is ESC key
		visible = !visible
		if visible:
			input.grab_focus()

func set_visible(should_show: bool) -> void:
	visible = should_show
	if visible:
		input.grab_focus()

func log_message(message: String) -> void:
	output.append_text("\n" + message)

func log_error(message: String) -> void:
	output.append_text("\n[color=red]ERROR: %s[/color]" % message)

func _on_input_submitted(text: String) -> void:
	if text.is_empty():
		return
	
	output.append_text("\n> " + text)
	input.clear()
	
	command_entered.emit(text) 
