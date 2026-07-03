import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _firstNameController = TextEditingController(text: authProvider.firstName);
    _lastNameController = TextEditingController(text: authProvider.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          const SizedBox(height: 28),

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
                          // Reset inputs to database state if editing was cancelled
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
        ],
      ),
    );
  }
}
