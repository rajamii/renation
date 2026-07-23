import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';

class GamingLoungeTab extends StatefulWidget {
  const GamingLoungeTab({super.key});

  @override
  State<GamingLoungeTab> createState() => _GamingLoungeTabState();
}

class _GamingLoungeTabState extends State<GamingLoungeTab> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _stations = [];
  bool _isLoading = true;
  bool _isProcessingReservation = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final response = await _apiClient.dio.get('/gaming/');
      if (mounted) {
        setState(() {
          _stations = response.data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log("Failed to Load Gaming Stations", e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reserveStation(dynamic station) async {
    if (_isProcessingReservation) return;

    setState(() => _isProcessingReservation = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await _apiClient.dio.post(
        '/client-services/book_console/',
        data: {'station_id': station['id']},
      );

      final int freeMinutes = response.data['free_minutes'] ?? 0;
      final String successMessage = freeMinutes > 0
          ? 'Reserved! $freeMinutes free minutes applied to tab.'
          : 'Console Reserved and added to tab!';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      AppLogger.log("Failed to reserve console", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reserve console. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingReservation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (_stations.isEmpty) {
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
                Icons.gamepad_rounded,
                size: 48,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : Colors.black38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "LOUNGE UNAVAILABLE",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "No consoles are currently active.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
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
                        station['name'] ?? 'Console',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "₹${station['hourly_rate']} / hr",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blueAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isProcessingReservation
                      ? null
                      : () => _reserveStation(station),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text(
                    'Reserve',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
