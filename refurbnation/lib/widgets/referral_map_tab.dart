import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:provider/provider.dart';
import '../services/logger_util.dart';
import '../providers/auth_provider.dart';

class ReferralMapTab extends StatefulWidget {
  const ReferralMapTab({super.key});

  @override
  State<ReferralMapTab> createState() => _ReferralMapTabState();
}

class _ReferralMapTabState extends State<ReferralMapTab> {
  final ApiClient _apiClient = ApiClient();
  Map<String, dynamic> _rewardsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNetworkTelemetry();
  }

  Future<void> _fetchNetworkTelemetry() async {
    try {
      final data = await _apiClient.getRewardSummary();
      setState(() {
        _rewardsData = data;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log("Failed to compile referral mapping fields", e);
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMetricNode(
    String title,
    String count,
    IconData icon,
    Color nodeColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE8E8ED),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nodeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: nodeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    final int directCount = _rewardsData['direct_referrals_count'] ?? 0;
    final int indirectCount = _rewardsData['indirect_referrals_count'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Central Engine Hub Node Graphic
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB9FF66).withOpacity(0.08),
                  border: Border.all(color: const Color(0xFFB9FF66), width: 2),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFB9FF66),
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "MY REFERRAL CODE",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
              Text(
                authProvider.referralCode.isNotEmpty
                    ? authProvider.referralCode
                    : "FETCHING...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),

        // Vertical node connection pipe line graphic
        Center(
          child: Container(
            width: 3,
            height: 32,
            color: const Color(0xFFB9FF66).withOpacity(0.4),
          ),
        ),

        // 2. Direct Referral Node Block
        _buildMetricNode(
          "Direct Referrals",
          "$directCount Activations",
          Icons.arrow_downward_rounded,
          Colors.blueAccent,
        ),

        Center(
          child: Container(
            width: 3,
            height: 32,
            color: Colors.purpleAccent.withOpacity(0.4),
          ),
        ),

        // 3. Indirect Referral Network Node Block
        _buildMetricNode(
          "Indirect Referrals",
          "$indirectCount Activations",
          Icons.hub_rounded,
          Colors.purpleAccent,
        ),

        const SizedBox(height: 24),

        // Informational System Policy Footnote
        Text(
          "*Referral Program Terms and Conditions applied.",
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 11, color: Colors.white24),
        ),
      ],
    );
  }
}
