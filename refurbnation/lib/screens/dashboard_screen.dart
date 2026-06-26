import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/service_model.dart';
import '../widgets/my_bookings_tab.dart';
import 'booking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  List<ServiceModel> _services = [];
  bool _isLoadingServices = true;
  int _currentTabIndex = 0; // Navigation cursor tracking handle

  @override
  void initState() {
    super.initState();
    _fetchServicesList();
  }

  Future<void> _fetchServicesList() async {
    try {
      final response = await _apiClient.dio.get('/services/');
      setState(() {
        _services = (response.data as List)
            .map((s) => ServiceModel.fromJson(s))
            .toList();
        _isLoadingServices = false;
      });
    } catch (e) {
      print("Error pulling treatment menus: $e");
    }
  }

  // Tab 0 UI Content View: "Book Service"
  Widget _buildBookServiceTab() {
    if (_isLoadingServices) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171717), // neutral-900 design matching
            border: Border.all(color: const Color(0xFF262626)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "⏱️ ${service.duration} hours",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // Un-commented and active: Pushes cleanly to the standalone mult-step workflow sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => BookingScreen(service: service),
                    ),
                  );
                },
                child: const Text(
                  'Book',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic tab switching matrix
    final List<Widget> tabsList = [
      _buildBookServiceTab(),
      const MyBookingsTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(
        0xFF0A0A0A,
      ), // neutral-950 backend theme canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTabIndex == 0
                  ? "Workshop Treatment Menu"
                  : "Appointments Pipeline",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "RefurbNation Client Console",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
      body: tabsList[_currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        backgroundColor: const Color(0xFF171717), // neutral-900 surface
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle_outlined),
            activeIcon: Icon(Icons.build_circle),
            label: 'Book Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'My Bookings',
          ),
        ],
      ),
    );
  }
}
