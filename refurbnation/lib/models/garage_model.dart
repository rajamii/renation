class VehicleMaster {
  final int id;
  final String brand;
  final String name;
  final String category;

  VehicleMaster({
    required this.id,
    required this.brand,
    required this.name,
    required this.category,
  });

  factory VehicleMaster.fromJson(Map<String, dynamic> json) {
    return VehicleMaster(
      id: json['id'] ?? 0,
      brand: json['brand'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class GarageVehicle {
  final int id;
  final String licensePlate;
  final VehicleMaster vehicle;

  GarageVehicle({
    required this.id,
    required this.licensePlate,
    required this.vehicle,
  });

  factory GarageVehicle.fromJson(Map<String, dynamic> json) {
    return GarageVehicle(
      id: json['id'] ?? 0,
      licensePlate: json['license_plate'] ?? '',
      vehicle: VehicleMaster.fromJson(json['vehicle_details'] ?? {}),
    );
  }
}
