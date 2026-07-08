import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/logger_util.dart';
import '../providers/auth_provider.dart';
import '../models/garage_model.dart';

class MyGarageTab extends StatefulWidget {
  const MyGarageTab({super.key});

  @override
  State<MyGarageTab> createState() => _MyGarageTabState();
}

class _MyGarageTabState extends State<MyGarageTab> {
  final ApiClient _apiClient = ApiClient();

  List<GarageVehicle> _garageVehicles = [];
  List<VehicleMaster> _masterVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Run both network requests concurrently
      final responses = await Future.wait([
        _apiClient.dio.get('/garage/'),
        _apiClient.dio.get('/vehicles/'),
      ]);

      setState(() {
        _garageVehicles = (responses[0].data as List)
            .map((v) => GarageVehicle.fromJson(v))
            .toList();

        _masterVehicles = (responses[1].data as List)
            .map((v) => VehicleMaster.fromJson(v))
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log("Error fetching garage data", e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load garage data.')),
        );
      }
    }
  }

  Future<void> _deleteVehicle(int id) async {
    HapticFeedback.mediumImpact();
    try {
      await _apiClient.dio.delete('/garage/$id/');
      setState(() {
        _garageVehicles.removeWhere((v) => v.id == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle removed from garage.')),
        );
      }
    } catch (e) {
      AppLogger.log("Error deleting vehicle", e);
    }
  }

  void _showAddVehicleSheet() {
    HapticFeedback.selectionClick();

    final List<String> availableBrands =
        _masterVehicles.map((v) => v.brand).toSet().toList()
          ..sort((a, b) => a.compareTo(b));

    String? selectedBrand;
    VehicleMaster? selectedModel;

    final SearchController brandSearchController = SearchController();
    final SearchController modelSearchController = SearchController();
    final TextEditingController licensePlateController =
        TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final List<VehicleMaster> filteredModels =
                selectedBrand == null
                      ? []
                      : _masterVehicles
                            .where((v) => v.brand == selectedBrand)
                            .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Add New Vehicle",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 24),

                  SearchAnchor(
                    searchController: brandSearchController,
                    builder:
                        (BuildContext context, SearchController controller) {
                          return SearchBar(
                            controller: controller,
                            hintText: 'Select Brand (Type to Search)',
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onTap: () => controller.openView(),
                            onChanged: (_) => controller.openView(),
                            leading: const Icon(Icons.apartment_rounded),
                            trailing: [
                              if (selectedBrand != null)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedBrand = null;
                                      selectedModel = null;
                                      brandSearchController.clear();
                                      modelSearchController.clear();
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                    suggestionsBuilder:
                        (BuildContext context, SearchController controller) {
                          final String keyword = controller.text.toLowerCase();
                          final matches = availableBrands.where(
                            (brand) => brand.toLowerCase().contains(keyword),
                          );

                          return matches.map((String brand) {
                            return ListTile(
                              title: Text(brand),
                              onTap: () {
                                setModalState(() {
                                  selectedBrand = brand;
                                  selectedModel = null;
                                  brandSearchController.text = brand;
                                  modelSearchController.clear();
                                });
                                controller.closeView(brand);
                              },
                            );
                          });
                        },
                  ),

                  const SizedBox(height: 16),

                  SearchAnchor(
                    searchController: modelSearchController,
                    builder:
                        (BuildContext context, SearchController controller) {
                          final bool isEnabled = selectedBrand != null;
                          return SearchBar(
                            controller: controller,
                            hintText: isEnabled
                                ? 'Select Model (Type to Search)'
                                : 'Choose a brand first',
                            enabled: isEnabled,
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onTap: isEnabled
                                ? () => controller.openView()
                                : null,
                            onChanged: isEnabled
                                ? (_) => controller.openView()
                                : null,
                            leading: Icon(
                              Icons.directions_car_filled_outlined,
                              color: isEnabled
                                  ? null
                                  : Theme.of(context).disabledColor,
                            ),
                            trailing: [
                              if (selectedModel != null)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedModel = null;
                                      modelSearchController.clear();
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                    suggestionsBuilder:
                        (BuildContext context, SearchController controller) {
                          final String keyword = controller.text.toLowerCase();
                          final matches = filteredModels.where(
                            (model) =>
                                model.name.toLowerCase().contains(keyword),
                          );

                          return matches.map((VehicleMaster model) {
                            return ListTile(
                              title: Text(model.name),
                              subtitle: Text(model.category),
                              onTap: () {
                                setModalState(() {
                                  selectedModel = model;
                                  modelSearchController.text = model.name;
                                });
                                controller.closeView(model.name);
                              },
                            );
                          });
                        },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: licensePlateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'License Plate Number',
                      hintText: 'e.g. SK 01 PB 9008',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed:
                        (selectedModel == null ||
                            licensePlateController.text.trim().isEmpty ||
                            isSubmitting)
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );

                            try {
                              await _apiClient.dio.post(
                                '/garage/',
                                data: {
                                  'vehicle': selectedModel!.id,
                                  'license_plate': licensePlateController.text
                                      .trim()
                                      .toUpperCase(),
                                  'user': authProvider.userId,
                                },
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                _fetchData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vehicle added to your studio profile!',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              AppLogger.log(
                                "Error posting unique asset registration index",
                                e,
                              );
                              setModalState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to link vehicle. Verify plate formatting rules.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Save to Garage'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _garageVehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_filled_outlined,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Your garage is empty",
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _garageVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _garageVehicles[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFEFEFEF),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.directions_car_rounded,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        title: Text(
                          '${vehicle.vehicle.brand} ${vehicle.vehicle.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            vehicle.licensePlate.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteVehicle(vehicle.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Add Button pinned to bottom
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('ADD NEW VEHICLE'),
            onPressed: _showAddVehicleSheet,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ),
      ],
    );
  }
}
