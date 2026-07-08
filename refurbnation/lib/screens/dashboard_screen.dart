import 'package:flutter/material.dart';
import 'package:refurbnation/screens/profile_screen.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';
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
  int _currentTabIndex = 0;

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
      AppLogger.log("Error pulling services", e);
      setState(() {
        _isLoadingServices =
            false; // Prevents the loader from spinning forever on failure
      });
    }
  }

  Widget _buildBookServiceTab() {
    if (_isLoadingServices) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'service_title_${service.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            service.name,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        service.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "⏱️ ${service.duration} hrs",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => BookingScreen(service: service),
                      ),
                    );
                  },
                  child: const Text('Book'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabsList = [
      _buildBookServiceTab(),
      const MyBookingsTab(),
      const ProfileView(),
    ];

    return Scaffold(
      // Scaffold color is automatically inherited from AppTheme
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0
              ? "Workshop Menu"
              : _currentTabIndex == 1
              ? "Pipeline"
              : "Account",
        ),
      ),
      body: tabsList[_currentTabIndex],
      // BottomNav uses the global theme now
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle_outlined),
            activeIcon: Icon(Icons.build_circle),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
