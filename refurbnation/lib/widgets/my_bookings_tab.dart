import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';

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

  Future<void> _loadUserBookings() async {
    try {
      final response = await _apiClient.dio.get('/bookings/');
      setState(() {
        _userBookings = response.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log("Failed to load pipeline tracking", e);
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.amberAccent;
      case 'CONFIRMED':
        return const Color(0xFFB9FF66); // Neon Green match
      case 'DELIVERED':
        return Colors.blueAccent;
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _showQrModal(BuildContext context, dynamic booking) {
    final String qrPayload =
        "Booking ID: #${booking['id']}\n"
        "      Vehicle: ${booking['vehicle_make_model'] ?? 'N/A'}\n"
        "      License Plate: ${booking['license_plate'] ?? 'null'}\n"
        "      Category: ${booking['vehicle_category'] ?? 'N/A'}\n"
        "      Date: ${booking['requested_date'] ?? 'N/A'}\n"
        "      Slot Reference: Slot #${booking['slot']}";

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                booking['service_name'] ?? 'Workshop Treatment',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "REFERENCE #${booking['id']}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 180.0,
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
              const SizedBox(height: 24),
              Text(
                "Present code at desk for operation dispatch lookup",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
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

    if (_userBookings.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _userBookings.length,
      itemBuilder: (context, index) {
        final booking = _userBookings[index];
        final String status = booking['status'] ?? 'PENDING';
        final statusColor = _getStatusColor(status);

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
                        booking['service_name'] ?? 'Workshop Treatment',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${booking['vehicle_make_model']} • ${booking['vehicle_category']}",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "📅 ${booking['requested_date']}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                    // Pill Badge for Status tracking
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
                    // Action Trigger for QR Code modal
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 28),
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
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
    );
  }
}
