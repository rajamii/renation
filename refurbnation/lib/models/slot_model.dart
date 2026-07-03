class SlotModel {
  final int id;
  final String startTime;
  final String endTime;

  SlotModel({required this.id, required this.startTime, required this.endTime});

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'],
      startTime: json['start_time'],
      endTime: json['end_time'],
    );
  }
}
