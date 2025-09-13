class FoodItem {
  final String name;
  final int kcalPer100g;
  final int protein;
  final int carbs;
  final int fat;
  const FoodItem(this.name, this.kcalPer100g, {this.protein = 0, this.carbs = 0, this.fat = 0});
}

const kFoods = <FoodItem>[
  FoodItem('Apple', 52, carbs: 14, protein: 0, fat: 0),
  FoodItem('Banana', 89, carbs: 23, protein: 1, fat: 0),
  FoodItem('Boiled egg', 155, protein: 13, fat: 11, carbs: 1),
  FoodItem('Chicken breast (grilled)', 165, protein: 31, fat: 4, carbs: 0),
  FoodItem('Rice, cooked', 130, carbs: 28, protein: 2, fat: 0),
  FoodItem('Paneer', 296, protein: 18, fat: 22, carbs: 4),
  FoodItem('Dal (cooked)', 116, protein: 9, carbs: 20, fat: 0),
  FoodItem('Chapati', 120, carbs: 18, protein: 3, fat: 3),
  FoodItem('Milk (250ml)', 103, protein: 8, carbs: 12, fat: 2),
  FoodItem('Oats (dry)', 379, protein: 13, carbs: 67, fat: 7),
];
