class FoodItem {
  final int id;
  final String name;
  final int kcalPer100g;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const FoodItem({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

const kFoods = [
  FoodItem(id: 1, name: 'Apple', kcalPer100g: 52, proteinG: 0, carbsG: 14, fatG: 0),
  FoodItem(id: 2, name: 'Banana', kcalPer100g: 89, proteinG: 1, carbsG: 23, fatG: 0),
  FoodItem(id: 3, name: 'Orange', kcalPer100g: 47, proteinG: 1, carbsG: 12, fatG: 0),
  FoodItem(id: 4, name: 'Chicken Breast', kcalPer100g: 165, proteinG: 31, carbsG: 0, fatG: 4),
  FoodItem(id: 5, name: 'Egg (boiled)', kcalPer100g: 155, proteinG: 13, carbsG: 1, fatG: 11),
  FoodItem(id: 6, name: 'Rice (cooked)', kcalPer100g: 130, proteinG: 2, carbsG: 28, fatG: 0),
  FoodItem(id: 7, name: 'Oats (dry)', kcalPer100g: 389, proteinG: 17, carbsG: 66, fatG: 7),
  FoodItem(id: 8, name: 'Milk (2%)', kcalPer100g: 50, proteinG: 3, carbsG: 5, fatG: 2),
  FoodItem(id: 9, name: 'Greek Yogurt', kcalPer100g: 59, proteinG: 10, carbsG: 3, fatG: 0),
  FoodItem(id: 10, name: 'Almonds', kcalPer100g: 579, proteinG: 21, carbsG: 22, fatG: 50),
  FoodItem(id: 11, name: 'Broccoli', kcalPer100g: 34, proteinG: 3, carbsG: 7, fatG: 0),
  FoodItem(id: 12, name: 'Potato (boiled)', kcalPer100g: 87, proteinG: 2, carbsG: 20, fatG: 0),
  FoodItem(id: 13, name: 'Salmon', kcalPer100g: 208, proteinG: 20, carbsG: 0, fatG: 13),
  FoodItem(id: 14, name: 'Olive Oil', kcalPer100g: 884, proteinG: 0, carbsG: 0, fatG: 100),
  FoodItem(id: 15, name: 'Paneer', kcalPer100g: 296, proteinG: 18, carbsG: 6, fatG: 22),
];
