import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_model.dart';
import '../models/garage_model.dart';
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
  ServicePrice? _selectedCategoryPrice;
  List<GarageVehicle> _garageVehicles = [];
  GarageVehicle? _selectedGarageVehicle;
  bool _isLoadingGarage = true;
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchGarageVehicles();
  }

  Future<void> _fetchGarageVehicles() async {
    try {
      final response = await _apiClient.dio.get('/garage/');
      setState(() {
        _garageVehicles = (response.data as List)
            .map((v) => GarageVehicle.fromJson(v))
            .toList();
        _isLoadingGarage = false;
      });
    } catch (e) {
      AppLogger.log("Error fetching garage", e);
      setState(() => _isLoadingGarage = false);
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
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDate == null ||
        _selectedCategoryPrice == null ||
        _selectedGarageVehicle == null ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    final String formattedDate =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await _apiClient.dio.post(
        '/bookings/',
        data: {
          'service': widget.service.id,
          'requested_date': formattedDate,
          'garage_vehicle': _selectedGarageVehicle!.id,
          'booking_source': 'ONLINE',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Submitted! Office will review availability.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.log("Booking submission error", e);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit booking. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFormValid = _selectedDate != null &&
        _selectedCategoryPrice != null &&
        _selectedGarageVehicle != null &&
        !_isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Service Info Header
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
                          child: Text(
                            widget.service.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 20),
                          ),
                        ),
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
                              " ₹${_selectedCategoryPrice!.price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
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

            // Step 1: Select Garage Vehicle
            Text(
              "1. Choose Vehicle from Garage",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 10),
            _isLoadingGarage
                ? const Center(child: CircularProgressIndicator())
                : _garageVehicles.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'Your garage is empty. Please add a vehicle in your Account tab before booking.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<GarageVehicle>(
                            value: _selectedGarageVehicle,
                            hint: Text(
                              'Select Vehicle',
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
                            items: _garageVehicles.map((GarageVehicle vehicle) {
                              return DropdownMenuItem<GarageVehicle>(
                                value: vehicle,
                                child: Text(
                                  '${vehicle.vehicle.brand} ${vehicle.vehicle.name} (${vehicle.licensePlate})',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (GarageVehicle? newValue) {
                              setState(() {
                                _selectedGarageVehicle = newValue;
                                if (newValue != null) {
                                  try {
                                    _selectedCategoryPrice = widget.service.prices
                                        .firstWhere(
                                          (priceObj) =>
                                              priceObj.categoryCode
                                                  .trim()
                                                  .toUpperCase() ==
                                              newValue.vehicle.category
                                                  .trim()
                                                  .toUpperCase(),
                                        );
                                  } catch (e) {
                                    _selectedCategoryPrice = null;
                                  }
                                } else {
                                  _selectedCategoryPrice = null;
                                }
                              });
                            },
                          ),
                        ),
                      ),
            const SizedBox(height: 24),

            // Step 2: Select Date
            Text(
              "2. Select Requested Date",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 10),
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
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null
                              ? 'Tap to pick date'
                              : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
            const SizedBox(height: 36),

            // Submit Button
            ElevatedButton(
              onPressed: isFormValid ? _confirmBooking : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Submit Booking Request'),
            ),
          ],
        ),
      ),
    );
  }
}