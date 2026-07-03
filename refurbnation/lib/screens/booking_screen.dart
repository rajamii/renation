import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../models/service_model.dart';
import '../models/slot_model.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';
import '../providers/auth_provider.dart';

class BookingScreen extends StatefulWidget {
  final ServiceModel service;

  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiClient _apiClient = ApiClient();

  final _vehicleModelController = TextEditingController();

  // Directly manage category selection using the embedded items
  ServicePrice? _selectedCategoryPrice;

  DateTime? _selectedDate;
  List<SlotModel> _slots = [];
  bool _isLoadingSlots = false;
  SlotModel? _selectedSlot;

  @override
  void dispose() {
    _vehicleModelController.dispose();
    super.dispose();
  }

  // Fetch slots strictly matching the targeted date selection
  Future<void> _fetchAvailableSlots(String formattedDate) async {
    setState(() {
      _isLoadingSlots = true;
      _selectedSlot = null;
      _slots = [];
    });

    try {
      final response = await _apiClient.dio.get(
        '/slots/',
        queryParameters: {'date': formattedDate},
      );
      setState(() {
        _slots = (response.data as List)
            .map((s) => SlotModel.fromJson(s))
            .toList();
        _isLoadingSlots = false;
      });
    } catch (e) {
      AppLogger.log("Error pulling targeted slots", e);
      setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFB9FF66),
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E1E),
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF1A1A1A),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1A1A1A),
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? const Color(0xFFB9FF66)
                    : const Color(0xFF1A1A1A),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final String formattedDate =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _selectedDate = picked;
      });
      _fetchAvailableSlots(formattedDate);
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedSlot == null ||
        _selectedDate == null ||
        _selectedCategoryPrice == null ||
        _vehicleModelController.text.trim().isEmpty) {
      return;
    }

    final String formattedDate =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session Error: User context missing. Routing back...',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );

        await authProvider.logout();

        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
      return;
    }

    try {
      await _apiClient.dio.post(
        '/bookings/',
        data: {
          'service': widget.service.id,
          'slot': _selectedSlot!.id,
          'requested_date': formattedDate,
          'vehicle_make_model': _vehicleModelController.text.trim(),
          'vehicle_category': _selectedCategoryPrice!.categoryCode,
          'user': authProvider.userId,
          'status': 'PENDING',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Booking Confirmed!')));
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.log("Booking validation error", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete booking matching server rules.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFormValid =
        _selectedSlot != null &&
        _selectedDate != null &&
        _selectedCategoryPrice != null &&
        _vehicleModelController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('New Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Service Briefing Card Header
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'service_title_${widget.service.id}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                widget.service.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                        // Dynamic Slice-inspired Neon Price Tag Banner
                        if (_selectedCategoryPrice != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "₹${_selectedCategoryPrice!.price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.service.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Vehicle Structural Data Input Form
            TextField(
              controller: _vehicleModelController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Vehicle Make & Model (e.g., Sedan, SUV)',
                prefixIcon: Icon(
                  Icons.directions_car_filled_outlined,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Dropdown Populated from embedded list data inside the service object
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ServicePrice>(
                  value: _selectedCategoryPrice,
                  hint: Text(
                    'Select Vehicle Category',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  isExpanded: true,
                  dropdownColor: Theme.of(context).cardTheme.color,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  items: widget.service.prices.map((ServicePrice priceObj) {
                    return DropdownMenuItem<ServicePrice>(
                      value: priceObj,
                      child: Text(
                        priceObj.categoryName,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (ServicePrice? newValue) {
                    setState(() {
                      _selectedCategoryPrice = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Date Picker Trigger Button Container
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null
                              ? 'Select Booking Date'
                              : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Timeline Windows Panel Container logic checks
            if (_selectedDate == null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    '⚠️ Please pick an operational date first to show available slots.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Available Windows for chosen date',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 12),

              // Look for this section inside lib/screens/booking_screen.dart
              _isLoadingSlots
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : _slots.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text('No slots left on this specific date.'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _slots.length,
                      itemBuilder: (context, index) {
                        final slot = _slots[index];
                        final isSelected = _selectedSlot?.id == slot.id;
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              // Keeps a subtle dark tint for dark mode, or a solid white fill for light mode
                              color: isSelected
                                  ? (isDark
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.08)
                                        : const Color(0xFFF5F5F7))
                                  : Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                // ---> HERE IS THE SHIFT <---
                                // Snaps to neon green in dark mode, or stark ink-black in light mode when selected
                                color: isSelected
                                    ? (isDark
                                          ? const Color(0xFFB9FF66)
                                          : const Color(0xFF1A1A1A))
                                    : (isDark
                                          ? Colors.white10
                                          : const Color(0xFFE8E8ED)),
                                width: isSelected ? 2.0 : 1.5,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick(); // Adds a subtle, premium physical tick
                                setState(() => _selectedSlot = slot);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Shift Window",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? (isDark
                                                          ? const Color(
                                                              0xFFB9FF66,
                                                            )
                                                          : const Color(
                                                              0xFF1A1A1A,
                                                            ))
                                                    : null,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${slot.startTime} - ${slot.endTime}",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    // Animated Radio-style tracking circle
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark
                                                    ? const Color(0xFFB9FF66)
                                                    : const Color(0xFF1A1A1A))
                                              : (isDark
                                                    ? Colors.white24
                                                    : Colors.black26),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isDark
                                                    ? const Color(0xFFB9FF66)
                                                    : const Color(0xFF1A1A1A),
                                              ),
                                            )
                                          : const SizedBox(
                                              width: 10,
                                              height: 10,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isFormValid ? _confirmBooking : null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white24,
              ),
              child: const Text('Confirm Schedule Reservation'),
            ),
          ],
        ),
      ),
    );
  }
}
