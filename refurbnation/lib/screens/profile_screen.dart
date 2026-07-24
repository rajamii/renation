import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import '../widgets/referral_map_tab.dart';
import '../widgets/my_garage.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ApiClient _apiClient = ApiClient();
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditing = false;

  // Dashboard states for the milestone count tracker
  int _yearlyBookingsCount = 0;
  bool _isLoadingDashboard = true;
  int _lastCheckedBookingsCount = 0;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _emailController = TextEditingController(text: authProvider.email);
    _phoneController = TextEditingController(text: authProvider.phoneNumber);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final results = await Future.wait([
        authProvider.fetchUserProfile(),
        _apiClient.getRewardSummary(),
      ]);

      final dashboardData = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _yearlyBookingsCount = dashboardData['yearly_bookings_count'] ?? 0;
          _emailController.text = authProvider.email;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading dashboard data on profile screen", e);
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
    }
  }

  void _triggerCelebrationSequence() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();

    if (!mounted) return;

    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 70,
        angle: 60,
        spread: 55,
        x: 0.0,
        y: 0.8,
        colors: const [Color(0xFFB9FF66), Color(0xFF5D33F8), Colors.white],
      ),
    );

    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 70,
        angle: 120,
        spread: 55,
        x: 1.0,
        y: 0.8,
        colors: const [Color(0xFFB9FF66), Color(0xFF5D33F8), Colors.white],
      ),
    );
  }

  Widget _buildGamifiedTimeline(int currentBookings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentBookings > _lastCheckedBookingsCount &&
        (currentBookings == 3 ||
            currentBookings == 6 ||
            currentBookings == 10)) {
      _lastCheckedBookingsCount = currentBookings;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerCelebrationSequence();
      });
    }

    final List<Map<String, dynamic>> milestones = [
      {"count": 1, "title": "Ignition", "sub": "First Wash"},
      {"count": 3, "title": "Carbon Clean", "sub": "20% Discount"},
      {"count": 6, "title": "Boost Engage", "sub": "Free Basic Wash"},
      {"count": 10, "title": "Stage 1 Tuned", "sub": "ELITE Coupon!"},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded( // 👈 Wrap title in Expanded to prevent right-side overflows
      child: Text(
        "2026 Performance Map",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
        overflow: TextOverflow.ellipsis, // Cleanly truncates with '...' if needed
      ),
    ),
    const SizedBox(width: 8), // Clean spacing between title & indicator
    _isLoadingDashboard
        ? const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            "$currentBookings/10 Bookings",
            style: const TextStyle(
              color: Color(0xFFB9FF66),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
  ],
),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(milestones.length, (index) {
                  final milestone = milestones[index];
                  final int targetCount = milestone["count"];
                  final bool isUnlocked = currentBookings >= targetCount;
                  final bool isNextUp =
                      currentBookings < targetCount &&
                      (index == 0 ||
                          currentBookings >= milestones[index - 1]["count"]);

                  return Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (isUnlocked) {
                            HapticFeedback.mediumImpact();
                          }
                        },
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isUnlocked
                                    ? const Color(0xFFB9FF66)
                                    : (isDark
                                          ? Colors.white10
                                          : Colors.black12),
                                border: Border.all(
                                  color: isUnlocked
                                      ? const Color(0xFFB9FF66)
                                      : isNextUp
                                      ? const Color(0xFFB9FF66)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isUnlocked
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFB9FF66,
                                          ).withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Icon(
                                isUnlocked
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_clock_outlined,
                                size: 18,
                                color: isUnlocked ? Colors.black : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              milestone["title"],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isUnlocked
                                    ? FontWeight.w700
                                    : FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              milestone["sub"],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isUnlocked
                                    ? FontWeight.w700
                                    : FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < milestones.length - 1)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 45,
                          height: 3.5,
                          margin: const EdgeInsets.only(
                            bottom: 38,
                            left: 6,
                            right: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                currentBookings >=
                                    milestones[index + 1]["count"]
                                ? const Color(0xFFB9FF66)
                                : (isDark ? Colors.white10 : Colors.black12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to log out of your studio session?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black54,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final rootNavigator = Navigator.of(this.context);
                await authProvider.logout();

                rootNavigator.pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Combine parameters safely for a unified read-only display
    final String fullName = "${authProvider.firstName} ${authProvider.lastName}"
        .trim();
    final String displayName = fullName.isNotEmpty ? fullName : "Name";

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: const Color(0xFFB9FF66),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Minimalist Header Control Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 22,
                  ),
                  onPressed: () => authProvider.toggleTheme(!isDark),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showLogoutConfirmation(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // User Identity Card
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFEFEFEF),
                child: Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            _buildGamifiedTimeline(_yearlyBookingsCount),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFB9FF66).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.garage_rounded,
                    color: Color(0xFFB9FF66),
                    size: 20,
                  ),
                ),
                title: const Text(
                  "My Garage",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white38,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (context) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.75,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        expand: false,
                        builder: (context, scrollController) {
                          return Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Expanded(child: MyGarageTab()),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Account Details",
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 15),
                        ),

                        const SizedBox(height: 20),

                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _emailController,
                          enabled: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _phoneController,
                          enabled: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone, size: 20),
                          ),
                        ),

                        if (_isEditing) ...[
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              final success = await authProvider
                                  .updateUserProfile(
                                    _emailController.text.trim(),
                                    _phoneController.text.trim(),
                                  );
                              if (success && context.mounted) {
                                setState(() => _isEditing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Profile updated successfully!',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Save Profile Changes'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(
                        _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                        size: 20,
                      ),
                      color: Theme.of(context).primaryColor,
                      onPressed: () {
                        setState(() {
                          _isEditing = !_isEditing;
                          if (!_isEditing) {
                            _emailController.text = authProvider.email;
                            _phoneController.text = authProvider.phoneNumber;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Theme.of(context).primaryColor.withAlpha(128),
      width: 1.5,
    ),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_activity,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "REFERRAL CODE",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              authProvider.referralCode.isNotEmpty
                  ? authProvider.referralCode
                  : "Fetching...",
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'monospace',
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: Icon(
          Icons.copy_all_rounded,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 20,
        ),
        onPressed: () {
          if (authProvider.referralCode.isNotEmpty) {
            Clipboard.setData(
              ClipboardData(text: authProvider.referralCode),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Referral code copied!'),
              ),
            );
          }
        },
      ),
    ],
  ),
),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB9FF66).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    color: Color(0xFFB9FF66),
                    size: 20,
                  ),
                ),
                title: const Text(
                  "My Referral Network Map",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white38,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (context) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.75,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        expand: false,
                        builder: (context, scrollController) {
                          return Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Expanded(child: ReferralMapTab()),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
