import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/planner.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:kitchenowl/services/transactions/planner.dart';
import 'package:kitchenowl/services/transactions/recipe.dart';
import 'package:kitchenowl/services/transactions/shoppinglist.dart';

class RecipeCubit extends Cubit<RecipeState> {
  final Household? household;

  RecipeCubit({this.household, required Recipe recipe, int? selectedYields})
      : super(RecipeState(recipe: recipe, selectedYields: selectedYields)) {
    refresh();
  }

  void itemSelected(RecipeItem item) {
    final List<String> selectedItems = List.from(state.selectedItems);
    if (selectedItems.contains(item.name)) {
      selectedItems.remove(item.name);
    } else {
      selectedItems.add(item.name);
    }
    emit(state.copyWith(selectedItems: selectedItems));
  }

  void setSelectedYields(int selectedYields) {
    emit(state.copyWith(
      selectedYields: selectedYields,
    ));
  }

  void setUpdateState(UpdateEnum updateState) {
    emit(state.copyWith(updateState: updateState));
  }

  Future<void> refresh() async {
    final recipe = await TransactionHandler.getInstance()
        .runTransaction(TransactionRecipeGetRecipe(recipe: state.recipe));
    emit(RecipeState(
      recipe: recipe,
      updateState: state.updateState,
      selectedYields: state.selectedYields,
    ));
  }

  Future<void> addItemsToList() async {
    if (household != null && household!.defaultShoppingList != null) {
      await TransactionHandler.getInstance()
          .runTransaction(TransactionShoppingListAddRecipeItems(
        shoppinglist: household!.defaultShoppingList!,
        items: state.dynamicRecipe.items
            .where((item) => state.selectedItems.contains(item.name))
            .toList(),
      ));
    }
  }

  Future<void> addRecipeToPlanner({int? day, bool updateOnAdd = false}) async {
    if (household != null) {
      await TransactionHandler.getInstance()
          .runTransaction(TransactionPlannerAddRecipe(
        household: household!,
        recipePlan: RecipePlan(
          recipe: state.recipe,
          day: day,
          yields: state.recipe.yields != state.selectedYields &&
                  state.selectedYields > 0
              ? state.selectedYields
              : null,
        ),
      ));
      if (updateOnAdd) setUpdateState(UpdateEnum.updated);
    }
  }
}

class RecipeState extends Equatable {
  final List<String> selectedItems;
  final Recipe recipe;
  final Recipe dynamicRecipe;
  final int selectedYields;
  final UpdateEnum updateState;

  RecipeState.custom({
    required this.recipe,
    required this.selectedItems,
    this.selectedYields = 0,
    this.updateState = UpdateEnum.unchanged,
  }) : dynamicRecipe = recipe.withYields(selectedYields);

  RecipeState({
    required this.recipe,
    this.updateState = UpdateEnum.unchanged,
    int? selectedYields,
  })  : selectedYields = selectedYields ?? recipe.yields,
        dynamicRecipe = recipe.withYields(selectedYields ?? recipe.yields),
        selectedItems =
            recipe.items.where((e) => !e.optional).map((e) => e.name).toList();

  RecipeState copyWith({
    Recipe? recipe,
    List<String>? selectedItems,
    int? selectedYields,
    UpdateEnum? updateState,
  }) =>
      RecipeState.custom(
        recipe: recipe ?? this.recipe,
        selectedItems: selectedItems ?? this.selectedItems,
        selectedYields: selectedYields ?? this.selectedYields,
        updateState: updateState ?? this.updateState,
      );

  @override
  List<Object?> get props =>
      [recipe, selectedItems, selectedYields, dynamicRecipe, updateState];
}
