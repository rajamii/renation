import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "refurbnation.",
      "subtitle":
          "Track and optimize your workshop assets seamlessly in real-time.",
    },
    {
      "title": "smart pipeline.",
      "subtitle":
          "Book precision operations and check service windows on the go.",
    },
    {
      "title": "desk scan check-in.",
      "subtitle":
          "Present instant dynamic matrix codes for direct operation lookup.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Skip option
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: widget.onFinish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Swipeable Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _onboardingData.length,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _onboardingData[index]["title"]!,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2.0,
                                color: index == 0 ? primaryColor : null,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _onboardingData[index]["subtitle"]!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 18, height: 1.4),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom Control Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        height: 6,
                        width: _currentPage == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? primaryColor
                              : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),

                  // Floating Navigation Action Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _onboardingData.length - 1) {
                        widget.onFinish();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    child: Icon(
                      _currentPage == _onboardingData.length - 1
                          ? Icons.done_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
