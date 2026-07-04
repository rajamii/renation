import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import '../widgets/referral_map_tab.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isEditing = false;
  int _lastCheckedBookingsCount = 0;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _firstNameController = TextEditingController(text: authProvider.firstName);
    _lastNameController = TextEditingController(text: authProvider.lastName);
    _lastCheckedBookingsCount = authProvider.isDarkMode ? 4 : 10;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _triggerCelebrationSequence() async {
    // 1. Fire sequential crisp haptic ticks to mirror a mechanical gear shifting
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();

    if (!mounted) return;

    // 2. Launch Left Corner Confetti Stream Cannon
    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 70,
        angle: 60,
        spread: 55,
        x: 0.0, // Left edge anchor placement boundary
        y: 0.8, // Lower lower quadrant tracking
        colors: const [Color(0xFFB9FF66), Color(0xFF5D33F8), Colors.white],
      ),
    );

    // 3. Launch Right Corner Confetti Stream Cannon
    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 70,
        angle: 120,
        spread: 55,
        x: 1.0, // Right edge anchor placement boundary
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
      {"count": 1, "title": "Ignition", "sub": "First Polish"},
      {"count": 3, "title": "Carbon Clean", "sub": "Sim Credits"},
      {"count": 6, "title": "Boost Engage", "sub": "Deep Wash Off"},
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
                Text(
                  "2026 Performance Map",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 15),
                ),
                Text(
                  "$currentBookings/10 Bookings",
                  style: TextStyle(
                    color: const Color(0xFFB9FF66),
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
                                          ).withOpacity(0.25),
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
                                    ? FontWeight.w900
                                    : FontWeight.bold,
                                color: isUnlocked ? Colors.white : Colors.grey,
                              ),
                            ),
                            Text(
                              milestone["sub"],
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white38,
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fallback assignment loop mock value for state validation test templates
    int userVisitsCount = authProvider.completedBookingsCount;

    return SingleChildScrollView(
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
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await authProvider.logout();
                  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
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
              authProvider.email,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(letterSpacing: 0.2),
            ),
          ),
          const SizedBox(height: 24),

          // INJECTED SECTION: Visual Progression Mapping & Checker hooks
          _buildGamifiedTimeline(userVisitsCount),

          const SizedBox(height: 16),

          // Referral Container Component
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFB9FF66),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFEFEFEF),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REFERRAL CODE",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                        const SnackBar(content: Text('Referral code copied!')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Wrapped Profile Parameters Card Block
          Card(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Identity Details",
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _firstNameController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _lastNameController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            final success = await authProvider
                                .updateUserProfile(
                                  _firstNameController.text.trim(),
                                  _lastNameController.text.trim(),
                                );
                            if (success && mounted) {
                              setState(() => _isEditing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile saved successfully!'),
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
                          _firstNameController.text = authProvider.firstName;
                          _lastNameController.text = authProvider.lastName;
                        }
                      });
                    },
                  ),
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
                  color: const Color(
                    0xFFB9FF66,
                  ).withOpacity(0.1), // Neon Green[cite: 3]
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
                            // Sheet Drag Handle bar
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Your component taking over the layout sheet smoothly
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
    );
  }
}
