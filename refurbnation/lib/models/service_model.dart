class ServicePrice {
  final int id;
  final String categoryCode;
  final String categoryName;
  final double price;

  ServicePrice({
    required this.id,
    required this.categoryCode,
    required this.categoryName,
    required this.price,
  });

  factory ServicePrice.fromJson(Map<String, dynamic> json) {
    return ServicePrice(
      id: json['id'],
      categoryCode: json['category'],
      categoryName: json['category_name'],
      price: double.parse(json['price_in_rupees'].toString()),
    );
  }
}

class ServiceModel {
  final int id;
  final String name;
  final String description;
  final double duration;
  final List<ServicePrice> prices; // Embedded category configurations

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.prices,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    var pricesList = json['prices'] as List? ?? [];

    return ServiceModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      duration: double.parse(json['estimated_duration_hours'].toString()),
      prices: pricesList.map((p) => ServicePrice.fromJson(p)).toList(),
    );
  }
}
