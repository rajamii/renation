import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../models/service_model.dart';
import '../widgets/my_bookings_tab.dart';
import '../providers/auth_provider.dart';
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
      print("Error pulling services: $e");
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
        // Using the global CardTheme now
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
                      Text(
                        service.name,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 18),
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
                          ).primaryColor.withOpacity(0.1),
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
                // Notice we removed all custom styling. It will automatically be neon green!
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

  Widget _buildProfileTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final firstNameController = TextEditingController(
      text: authProvider.firstName,
    );
    final lastNameController = TextEditingController(
      text: authProvider.lastName,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: const Icon(Icons.person, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              authProvider.email,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name'),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () async {
              bool success = await authProvider.updateUserProfile(
                firstNameController.text.trim(),
                lastNameController.text.trim(),
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
          const SizedBox(height: 16),
          // Using global OutlinedButton theme, overriding just the border color for destructive action
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            onPressed: () async {
              await authProvider.logout();
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabsList = [
      _buildBookServiceTab(),
      const MyBookingsTab(), // Ensure this tab is also stripped of hardcoded colors
      _buildProfileTab(),
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
