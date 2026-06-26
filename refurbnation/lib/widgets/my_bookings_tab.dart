import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_client.dart';

class MyBookingsTab extends StatefulWidget {
  const MyBookingsTab({super.key});

  @override
  State<MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends State<MyBookingsTab> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _userBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserBookings();
  }

  // Exact endpoint lookup used by loadUserBookings() in Angular
  Future<void> _loadUserBookings() async {
    try {
      final response = await _apiClient.dio.get('/bookings/');
      setState(() {
        _userBookings = response.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print("Failed to load pipeline tracking: $e");
    }
  }

  // Color mapping based on your Angular status classes
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.amber;
      case 'CONFIRMED':
        return Colors.green;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showQrModal(BuildContext context, dynamic booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171717), // neutral-900 surface theme
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                booking['service_name'] ?? 'Workshop Treatment',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "ID Reference: #${booking['id']}",
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: "REFURBNATION_ID:${booking['id']}",
                  version: QrVersions.auto,
                  size: 180.0,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Present this QR code at the desk for instant operational tracking lookup",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_userBookings.isEmpty) {
      return const Center(
        child: Text(
          "No active pipeline bookings found.",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userBookings.length,
      itemBuilder: (context, index) {
        final booking = _userBookings[index];
        final String status = booking['status'] ?? 'PENDING';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171717), // neutral-900
            border: Border.all(color: const Color(0xFF262626)), // neutral-800
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['service_name'] ?? 'Workshop Treatment',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${booking['vehicle_make_model']} (${booking['vehicle_category']})",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📅 Date: ${booking['requested_date']}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.qr_code,
                      color: Colors.white70,
                      size: 24,
                    ),
                    onPressed: () => _showQrModal(context, booking),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
