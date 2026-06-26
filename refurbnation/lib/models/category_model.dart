class CategoryModel {
  final String code;
  final String name;

  CategoryModel({required this.code, required this.name});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      code: json['code'], // primary key code in Master table
      name: json['name'],
    );
  }
}