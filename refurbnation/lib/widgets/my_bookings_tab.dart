import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';
import 'active_tab_modal.dart';

class MyBookingsTab extends StatefulWidget {
  const MyBookingsTab({super.key});

  @override
  State<MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends State<MyBookingsTab> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _userBookings = [];
  Map<int, dynamic> _garageMap = {};
  Map<String, dynamic>? _tabData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await Future.wait([
        _apiClient.dio.get('/bookings/'),
        _apiClient.dio.get('/garage/'),
        _apiClient.dio.get('/client-services/my_tab/'),
      ]);
      final List<dynamic> bookingsData = response[0].data ?? [];
      final List<dynamic> garageData = response[1].data ?? [];
      final Map<String, dynamic>? tabData = response[2].data;

      final Map<int, dynamic> tempGarageMap = {};
      for (var item in garageData) {
        if (item['id'] != null) {
          tempGarageMap[item['id']] = item;
        }
      }

      setState(() {
        _userBookings = bookingsData;
        _garageMap = tempGarageMap;
        _tabData = tabData;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log("Failed to Load Data", e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payOnline() async {
    HapticFeedback.mediumImpact();
    try {
      await _apiClient.dio.post('/client-services/pay_online/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Tab settled.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment failed. Ensure bill is finalized by staff.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openTabModal() {
    if (_tabData == null) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ActiveTabModal(tabData: _tabData!, onPaymentSuccess: _payOnline),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.deepOrangeAccent;
      case 'CONFIRMED':
        return const Color(0xFFB9FF66);
      case 'DELIVERED':
        return Colors.green;
      case 'WORK IN PROGRESS':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getVehicleName(dynamic booking) {
    final int? vehicleId = booking['garage_vehicle'];
    if (vehicleId != null && _garageMap.containsKey(vehicleId)) {
      final details = _garageMap[vehicleId]['vehicle_details'];
      if (details != null) {
        return "${details['brand'] ?? ''} ${details['name'] ?? ''}".trim();
      }
    }
    return 'Unknown Vehicle';
  }

  String _getVehicleCategory(dynamic booking) {
    final int? vehicleId = booking['garage_vehicle'];
    if (vehicleId != null && _garageMap.containsKey(vehicleId)) {
      final details = _garageMap[vehicleId]['vehicle_details'];
      if (details != null) {
        return details['category_name'] ?? details['category'] ?? 'N/A';
      }
    }
    return 'N/A';
  }

  String _getLicensePlate(dynamic booking) {
    final int? vehicleId = booking['garage_vehicle'];
    if (vehicleId != null && _garageMap.containsKey(vehicleId)) {
      return _garageMap[vehicleId]['license_plate'] ?? 'N/A';
    }
    return 'N/A';
  }

  // lib/widgets/my_bookings_tab.dart

void _showQrModal(BuildContext context, dynamic booking) {
  final String vehicleName = _getVehicleName(booking);
  final String category = _getVehicleCategory(booking);
  final String licensePlate = _getLicensePlate(booking);
  final String qrPayload =
      "Booking ID: #${booking['id']}\n"
      "Vehicle: $vehicleName\n"
      "License Plate: $licensePlate\n"
      "Category: $category\n"
      "Date: ${booking['requested_date'] ?? 'N/A'}";

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // 👈 Allows the modal to expand appropriately
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 20.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
        ),
        child: SingleChildScrollView( // 👈 Prevents vertical RenderFlex overflows
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                booking['service_name'] ?? 'Workshop Treatment',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "REFERENCE #${booking['id']}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 160.0, // Scaled slightly down to fit compact viewports comfortably
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Present code at desk for operation dispatch lookup",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    final hasActiveTab =
        _tabData != null && (_tabData!['line_items'] as List).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _userBookings.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 48,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "PIPELINE CLEAR",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Your workspace is currently empty.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount: _userBookings.length,
                itemBuilder: (context, index) {
                  final booking = _userBookings[index];
                  final String status = booking['status'] ?? 'PENDING';
                  final statusColor = _getStatusColor(status);
                  final String vehicleName = _getVehicleName(booking);
                  final String vehicleCategory = _getVehicleCategory(booking);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking['service_name'] ??
                                      'Workshop Treatment',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 17),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "$vehicleName • $vehicleCategory",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  "${booking['requested_date']}${booking['slot_start'] != null ? ' • ${booking['slot_start']} - ${booking['slot_end']}' : ''}",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 28,
                                ),
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color
                                    ?.withValues(alpha: 0.8),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showQrModal(context, booking),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: hasActiveTab
          ? FloatingActionButton.extended(
              onPressed: _openTabModal,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text(
                "View Active Tab",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
