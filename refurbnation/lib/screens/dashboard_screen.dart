import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/service_model.dart';
// import booking_screen.dart (to be created in the next step)

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  List<ServiceModel> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await _apiClient.dio.get('/services/');
      setState(() {
        services = (response.data as List).map((s) => ServiceModel.fromJson(s)).toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching services: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Services')),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return ListTile(
                title: Text(service.name),
                subtitle: Text('${service.duration} hours'),
                trailing: ElevatedButton(
                  onPressed: () {
                    // Navigate to Booking Form passing the Service ID
                  },
                  child: const Text('Book'),
                ),
              );
            },
          ),
    );
  }
}