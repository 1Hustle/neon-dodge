extends CanvasLayer
## All on-screen text and menus (the heads-up display).
##
## The HUD never changes game state itself. It displays what Main tells
## it to display, and forwards the menu button to Main as a signal.
## That one-way flow keeps every rule of the game inside main.gd.

## Emitted when the player presses the Start / Play Again button.
signal start_game

@onready var _score_label: Label = $ScoreLabel
@onready var _lives_label: Label = $LivesLabel
@onready var _panel: PanelContainer = $MessagePanel
@onready var _title_label: Label = $MessagePanel/Margin/VBox/TitleLabel
@onready var _info_label: Label = $MessagePanel/Margin/VBox/InfoLabel
@onready var _start_button: Button = $MessagePanel/Margin/VBox/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)


func update_score(score: int) -> void:
	_score_label.text = "Score: %d" % score


func update_lives(lives: int) -> void:
	_lives_label.text = "Lives: %d" % lives


## Start screen: title, how to play, and the start button.
func show_start() -> void:
	_title_label.text = "NEON DODGE"
	_info_label.text = "Dodge the falling blocks.\nMove: WASD / arrow keys / drag"
	_start_button.text = "Start Game"
	_panel.show()


## In-game: hide the menu panel so only score and lives remain.
func show_hud() -> void:
	_panel.hide()


## Game-over screen with the final score and a restart button.
func show_game_over(final_score: int) -> void:
	_title_label.text = "GAME OVER"
	_info_label.text = "Final score: %d" % final_score
	_start_button.text = "Play Again"
	_panel.show()


func _on_start_button_pressed() -> void:
	start_game.emit()
