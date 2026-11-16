extends CanvasLayer
## All on-screen text, menus and buttons (the heads-up display).
##
## The HUD never changes game state itself. It displays what Main tells
## it to display, and forwards every button press to Main as a signal.
## That one-way flow keeps every rule of the game inside main.gd.
##
## The HUD's process mode is set to Always in hud.tscn so its buttons
## still work while the tree is paused (the pause menu lives here).

signal start_game
signal resume_game
signal restart_game
signal quit_to_menu
signal pause_request

@onready var _score_label: Label = $ScoreLabel
@onready var _lives_label: Label = $LivesLabel
@onready var _pause_button: Button = $PauseButton
@onready var _panel: PanelContainer = $MessagePanel
@onready var _title_label: Label = $MessagePanel/Margin/VBox/TitleLabel
@onready var _info_label: Label = $MessagePanel/Margin/VBox/InfoLabel
@onready var _best_label: Label = $MessagePanel/Margin/VBox/BestLabel
@onready var _start_button: Button = $MessagePanel/Margin/VBox/StartButton
@onready var _pause_panel: PanelContainer = $PausePanel


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_game.emit())
	_pause_button.pressed.connect(func() -> void: pause_request.emit())
	$PausePanel/Margin/VBox/ResumeButton.pressed.connect(func() -> void: resume_game.emit())
	$PausePanel/Margin/VBox/PauseRestartButton.pressed.connect(func() -> void: restart_game.emit())
	$PausePanel/Margin/VBox/MenuButton.pressed.connect(func() -> void: quit_to_menu.emit())


func update_score(score: int) -> void:
	_score_label.text = "Score: %d" % score


func update_lives(lives: int) -> void:
	_lives_label.text = "Lives: %d" % lives


## Start screen: title, how to play, saved best, and the start button.
func show_start(high_score: int) -> void:
	_title_label.text = "NEON DODGE"
	_info_label.text = "Dodge the falling blocks.\nMove: WASD / arrow keys / drag"
	_best_label.text = "Best: %d" % high_score
	_start_button.text = "Start Game"
	_pause_button.hide()
	_panel.show()


## In-game: hide the menu panel so only score, lives and the pause
## button remain.
func show_hud() -> void:
	_panel.hide()
	_pause_button.show()


## Game-over screen with the final score, the saved best, and a
## restart button. new_best is true when this run just set the record.
func show_game_over(final_score: int, high_score: int, new_best: bool) -> void:
	_title_label.text = "GAME OVER"
	_info_label.text = "Final score: %d" % final_score
	_best_label.text = "NEW BEST!" if new_best else "Best: %d" % high_score
	_start_button.text = "Play Again"
	_pause_button.hide()
	_panel.show()


## Shows or hides the pause menu. Called by Main when the tree pauses
## or resumes, whatever triggered it (key, button, or menu choice).
func show_pause(paused: bool) -> void:
	_pause_panel.visible = paused
