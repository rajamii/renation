import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';

class CafeMenuTab extends StatefulWidget {
  const CafeMenuTab({super.key});

  @override
  State<CafeMenuTab> createState() => _CafeMenuTabState();
}

class _CafeMenuTabState extends State<CafeMenuTab> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _menuItems = [];
  bool _isLoading = true;
  bool _isProcessingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final response = await _apiClient.dio.get('/cafe/');
      if (mounted) {
        setState(() {
          _menuItems = response.data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log("Failed to Load Cafe Menu", e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _orderItem(dynamic item) async {
    if (_isProcessingOrder) return;

    setState(() => _isProcessingOrder = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await _apiClient.dio.post(
        '/client-services/order_cafe_item/',
        data: {'item_id': item['id'], 'quantity': 1},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added to Tab! Total: ₹${response.data['final_price']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.log("Failed to place cafe order", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to place order. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOrder = false);
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

    if (_menuItems.isEmpty) {
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
                Icons.local_cafe_rounded,
                size: 48,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : Colors.black38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "MENU UNAVAILABLE",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "The cafe is currently closed or updating its menu.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
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
                        item['name'] ?? 'Menu Item',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (item['category'] ?? 'General')
                            .toString()
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "₹${item['price']}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isProcessingOrder ? null : () => _orderItem(item),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text('Add to Tab'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
