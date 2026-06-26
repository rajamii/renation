import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../models/service_model.dart';
import '../models/category_model.dart';
import '../models/slot_model.dart';

class BookingScreen extends StatefulWidget {
  final ServiceModel service;

  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiClient _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;

  DateTime? _selectedDate;
  List<SlotModel> _slots = [];
  SlotModel? _selectedSlot;

  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();

  bool _isLoadingMetaData = true;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchMetaData();
  }

  // 1. Hit config endpoint just like the Angular implementation
  Future<void> _fetchMetaData() async {
    try {
      final response = await _apiClient.dio.get('/config/meta_lookup/');
      final categoryList = response.data['categories'] as List;

      setState(() {
        _categories = categoryList
            .map((c) => CategoryModel.fromJson(c))
            .toList();
        _isLoadingMetaData = false;
      });
    } catch (e) {
      _showSnackBar("Failed to load vehicle categories");
      setState(() => _isLoadingMetaData = false);
    }
  }

  // 2. Fetch available target operating windows
  Future<void> _fetchSlots(String dateString) async {
    setState(() {
      _isLoadingSlots = true;
      _slots = [];
      _selectedSlot = null;
    });

    try {
      final response = await _apiClient.dio.get(
        '/slots/',
        queryParameters: {'date': dateString},
      );
      final slotList = response.data as List;

      setState(() {
        _slots = slotList.map((s) => SlotModel.fromJson(s)).toList();
        _isLoadingSlots = false;
      });
    } catch (e) {
      _showSnackBar("Error querying slot tracking matrix");
      setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      String formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      _fetchSlots(formattedDate);
    }
  }

  // 3. Post appointment details and handle capacity check errors
  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      _showSnackBar("Please complete all required fields");
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'service': widget.service.id,
      'vehicle_category':
          _selectedCategory!.code, // Primary master lookup matching
      'vehicle_make_model': _vehicleModelController.text,
      'vehicle_license_plate': _licensePlateController.text.trim().isEmpty
          ? null
          : _licensePlateController.text,
      'requested_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'slot': _selectedSlot?.id,
    };

    try {
      await _apiClient.dio.post('/bookings/', data: payload);
      _showSnackBar("Booking confirmed!");
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      // Gracefully catch the DRF validation capacity constraint errors
      if (e.response?.statusCode == 400 && e.response?.data is Map) {
        final backendError = e.response?.data['error'];
        if (backendError != null) {
          _showErrorDialog(backendError.toString());
        } else {
          _showSnackBar("Input parameters failed validation criteria");
        }
      } else {
        _showSnackBar("An processing failure occurred on backend execution");
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text(
          "Capacity Limit",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMetaData) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(
          'Book ${widget.service.name}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<CategoryModel>(
                dropdownColor: const Color(0xFF171717),
                decoration: const InputDecoration(
                  labelText: "Vehicle Scale Class",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.white),
                value: _selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(
                      cat.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
                validator: (val) => val == null ? "Required field" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleModelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Brand & Variant Name (e.g. BMW 3 Series)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? "Required field" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licensePlateController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "License Identifier (Optional)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? "Choose Target Calendar Date"
                      : "Target Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_month, color: Colors.grey),
                onTap: () => _selectDate(context),
                tileColor: const Color(0xFF171717),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoadingSlots)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (!_isLoadingSlots && _selectedDate != null && _slots.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    "All allocation indices filled for this timeline location.",
                  ),
                ),

              if (!_isLoadingSlots && _slots.isNotEmpty)
                DropdownButtonFormField<SlotModel>(
                  dropdownColor: const Color(0xFF171717),
                  decoration: const InputDecoration(
                    labelText: "Operational Hours Window",
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  style: const TextStyle(color: Colors.white),
                  value: _selectedSlot,
                  items: _slots.map((slot) {
                    return DropdownMenuItem(
                      value: slot,
                      child: Text(
                        "${slot.startTime} - ${slot.endTime}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSlot = val),
                  validator: (val) => val == null
                      ? "Please select an operational window"
                      : null,
                ),
              const SizedBox(height: 32),

              _isSubmitting
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _submitBooking,
                      child: const Text(
                        "Confirm Treatment Request",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
