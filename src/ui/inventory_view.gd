class_name InventoryView
extends Control

## Inventory screen, opened with E in survival. It frees the mouse and pauses
## the game; a click picks a stack up and a second click puts it down.

signal opened
signal closed

const SLOT_SIZE: float = 56.0
const COLUMNS: int = 8
const COLOR_DIM: Color = Color(0.0, 0.0, 0.0, 0.55)

@export var atlas: Texture2D

var enabled: bool = false

var _inventory: Inventory
var _recipes: Array[Recipe] = Recipe.all()
var _slot_buttons: Array[Button] = []
var _recipe_buttons: Array[Button] = []
var _held: Label


func _ready() -> void:
	visible = false


func setup(inventory: Inventory) -> void:
	_inventory = inventory
	_build()
	_inventory.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not enabled or key == null or not key.pressed or key.echo:
		return
	# The pause menu or the death screen already stopped the game.
	if not visible and get_tree().paused:
		return
	if key.physical_keycode == KEY_E:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()


func close() -> void:
	_inventory.return_held()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Clicks a slot, as a mouse click on its button does.
func click_slot(slot: int) -> void:
	_inventory.click(slot)


## Crafts a recipe, as a click on its button does.
func craft(index: int) -> bool:
	return _recipes[index].craft(_inventory)


func is_recipe_available(index: int) -> bool:
	return not _recipe_buttons[index].disabled


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = COLOR_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = "Inventario"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	column.add_child(grid)
	# The backpack first, then the hotbar as the last row, as it sits on screen.
	_slot_buttons.resize(Inventory.SLOTS)
	for slot: int in range(Inventory.HOTBAR_SLOTS, Inventory.SLOTS):
		grid.add_child(_slot_button(slot))
	for slot: int in Inventory.HOTBAR_SLOTS:
		grid.add_child(_slot_button(slot))
	_held = Label.new()
	column.add_child(_held)
	var recipes_title: Label = Label.new()
	recipes_title.text = "Ricette"
	column.add_child(recipes_title)
	for index: int in _recipes.size():
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = _recipes[index].describe()
		button.pressed.connect(craft.bind(index))
		column.add_child(button)
		_recipe_buttons.append(button)


func _slot_button(slot: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2.ONE * SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.pressed.connect(click_slot.bind(slot))
	_slot_buttons[slot] = button
	return button


func _refresh() -> void:
	for slot: int in Inventory.SLOTS:
		var item: int = _inventory.items[slot]
		var count: int = _inventory.counts[slot]
		_slot_buttons[slot].icon = null if item == ItemTable.NONE else ItemIcons.icon(atlas, item)
		_slot_buttons[slot].text = str(count) if count > 1 else ""
		_slot_buttons[slot].tooltip_text = ItemTable.display_name(item)
	if _inventory.held_count > 0:
		_held.text = "In mano: %s × %d" % [ItemTable.display_name(_inventory.held_item), _inventory.held_count]
	else:
		_held.text = ""
	for index: int in _recipes.size():
		_recipe_buttons[index].disabled = not _recipes[index].can_craft(_inventory)
