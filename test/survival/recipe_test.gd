extends GdUnitTestSuite


func _recipe(output: int) -> Recipe:
	for recipe: Recipe in Recipe.all():
		if recipe.output_item == output:
			return recipe
	return null


func test_there_are_four_recipes() -> void:
	assert_int(Recipe.all().size()).is_equal(4)


func test_one_log_makes_four_planks() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.LOG, 2)

	assert_bool(_recipe(BlockTable.PLANKS).craft(inventory)).is_true()

	assert_int(inventory.count_of(BlockTable.LOG)).is_equal(1)
	assert_int(inventory.count_of(BlockTable.PLANKS)).is_equal(4)


func test_stone_pickaxe_uses_planks_and_stone() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.PLANKS, 2)
	inventory.add(BlockTable.STONE, 3)

	assert_bool(_recipe(ItemTable.STONE_PICKAXE).craft(inventory)).is_true()

	assert_int(inventory.count_of(ItemTable.STONE_PICKAXE)).is_equal(1)
	assert_int(inventory.count_of(BlockTable.PLANKS)).is_equal(0)
	assert_int(inventory.count_of(BlockTable.STONE)).is_equal(0)


func test_missing_ingredients_change_nothing() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.SAND, 3)

	assert_bool(_recipe(BlockTable.GLASS).can_craft(inventory)).is_false()
	assert_bool(_recipe(BlockTable.GLASS).craft(inventory)).is_false()
	assert_int(inventory.count_of(BlockTable.SAND)).is_equal(3)


func test_result_must_fit_after_the_ingredients_are_used() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.add(BlockTable.STONE, (Inventory.SLOTS - 1) * 64)
	inventory.add(BlockTable.PLANKS, 5)

	assert_bool(_recipe(ItemTable.WOODEN_PICKAXE).can_craft(inventory)).is_true()

	inventory.add(BlockTable.PLANKS, 59)
	assert_bool(_recipe(ItemTable.WOODEN_PICKAXE).can_craft(inventory)).is_false()


func test_description_lists_ingredients_and_result() -> void:
	assert_str(_recipe(ItemTable.STONE_PICKAXE).describe()).is_equal("Piccone di pietra: 2 assi e 3 pietra → 1")
