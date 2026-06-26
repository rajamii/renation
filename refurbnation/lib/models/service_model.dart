class ServiceModel {
  final int id;
  final String name;
  final String description;
  final double duration;

  ServiceModel({required this.id, required this.name, required this.description, required this.duration});

  // Maps to the Service model and ServiceSerializer data
  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      duration: double.parse(json['estimated_duration_hours'].toString()),
    );
  }
}