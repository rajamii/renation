import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_client.dart';

class OfficeQrScannerScreen extends StatefulWidget {
  const OfficeQrScannerScreen({super.key});

  @override
  State<OfficeQrScannerScreen> createState() => _OfficeQrScannerScreenState();
}

class _OfficeQrScannerScreenState extends State<OfficeQrScannerScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isProcessing = false;

  void _onDetectBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final String rawData = barcodes.first.rawValue!;

    if (rawData.startsWith("REFURBNATION_ID:")) {
      setState(() => _isProcessing = true);
      final String bookingId = rawData.split(":").last;

      try {
        final response = await _apiClient.dio.get('/bookings/$bookingId/');

        if (mounted) {
          Navigator.pop(context, response.data);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid matrix reference. Record index not found."),
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Desk Check-In QR")),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetectBarcode),
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.8),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Targeting Brackets
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
