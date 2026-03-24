// ignore_for_file: duplicate_ignore, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const EVRangeApp());

class EVRangeApp extends StatelessWidget {
  const EVRangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Range Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0D7377),
        useMaterial3: true,
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  // For Android emulator use http://10.0.2.2:8000/predict
  // For physical device use your computer IP e.g. http://192.168.1.45:8000/predict
  // For production use https://ev-range-predictor.onrender.com/predict
  static const String _apiUrl = 'http://10.0.2.2:8000/predict';

  final _formKey = GlobalKey<FormState>();

  // 12 controllers — one per feature
  final _topSpeedCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  final _numCellsCtrl = TextEditingController();
  final _torqueCtrl = TextEditingController();
  final _efficiencyCtrl = TextEditingController();
  final _accelCtrl = TextEditingController();
  final _fastChargeCtrl = TextEditingController();
  final _towingCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  bool _isLoading = false;
  double? _predictedRange;
  String? _errorMessage;

  @override
  void dispose() {
    _topSpeedCtrl.dispose();
    _batteryCtrl.dispose();
    _numCellsCtrl.dispose();
    _torqueCtrl.dispose();
    _efficiencyCtrl.dispose();
    _accelCtrl.dispose();
    _fastChargeCtrl.dispose();
    _towingCtrl.dispose();
    _seatsCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _predictedRange = null;
    });

    try {
      final body = jsonEncode({
        'top_speed_kmh': double.parse(_topSpeedCtrl.text),
        'battery_capacity_kwh': double.parse(_batteryCtrl.text),
        'number_of_cells': int.parse(_numCellsCtrl.text),
        'torque_nm': double.parse(_torqueCtrl.text),
        'efficiency_wh_per_km': double.parse(_efficiencyCtrl.text),
        'acceleration_0_100_s': double.parse(_accelCtrl.text),
        'fast_charging_power_kw_dc': double.parse(_fastChargeCtrl.text),
        'towing_capacity_kg': double.parse(_towingCtrl.text),
        'seats': int.parse(_seatsCtrl.text),
        'length_mm': double.parse(_lengthCtrl.text),
        'width_mm': double.parse(_widthCtrl.text),
        'height_mm': double.parse(_heightCtrl.text),
      });

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _predictedRange = (data['predicted_range_km'] as num).toDouble();
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: ${err['detail'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Check your network.\n$e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    String? suffix,
    bool isInt = false,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isInt
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: const Color(0xFFF2F3F4),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('⚡ EV Range Predictor'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Container(
            color: const Color(0xFF0A5C60),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Center(
              child: Text(
                'Enter EV specifications to predict driving range',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Vehicle Specifications (12 inputs)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0D7377),
                ),
              ),
              const Divider(height: 12),

              // Field 1
              _field(
                ctrl: _topSpeedCtrl,
                label: 'Top Speed',
                hint: '250',
                suffix: 'km/h',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 50 || n > 500) return '50 – 500 km/h';
                  return null;
                },
              ),

              // Field 2
              _field(
                ctrl: _batteryCtrl,
                label: 'Battery Capacity',
                hint: '75.0',
                suffix: 'kWh',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 10 || n > 300) return '10 – 300 kWh';
                  return null;
                },
              ),

              // Field 3
              _field(
                ctrl: _numCellsCtrl,
                label: 'Number of Battery Cells',
                hint: '4416',
                isInt: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 10000) return '1 – 10000';
                  return null;
                },
              ),

              // Field 4
              _field(
                ctrl: _torqueCtrl,
                label: 'Torque',
                hint: '420',
                suffix: 'Nm',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 50 || n > 3000) return '50 – 3000 Nm';
                  return null;
                },
              ),

              // Field 5
              _field(
                ctrl: _efficiencyCtrl,
                label: 'Efficiency',
                hint: '160',
                suffix: 'Wh/km',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 50 || n > 500) return '50 – 500 Wh/km';
                  return null;
                },
              ),

              // Field 6
              _field(
                ctrl: _accelCtrl,
                label: '0-100 km/h Acceleration',
                hint: '5.0',
                suffix: 's',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 1 || n > 30) return '1 – 30 seconds';
                  return null;
                },
              ),

              // Field 7
              _field(
                ctrl: _fastChargeCtrl,
                label: 'Fast Charging Power (DC)',
                hint: '250',
                suffix: 'kW',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 1000) return '0 – 1000 kW';
                  return null;
                },
              ),

              // Field 8
              _field(
                ctrl: _towingCtrl,
                label: 'Towing Capacity',
                hint: '1000',
                suffix: 'kg',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 5000) return '0 – 5000 kg';
                  return null;
                },
              ),

              // Field 9
              _field(
                ctrl: _seatsCtrl,
                label: 'Number of Seats',
                hint: '5',
                isInt: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 9) return '1 – 9 seats';
                  return null;
                },
              ),

              // Field 10
              _field(
                ctrl: _lengthCtrl,
                label: 'Vehicle Length',
                hint: '4694',
                suffix: 'mm',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 2000 || n > 7000)
                    // ignore: curly_braces_in_flow_control_structures
                    return '2000 – 7000 mm';
                  return null;
                },
              ),

              // Field 11
              _field(
                ctrl: _widthCtrl,
                label: 'Vehicle Width',
                hint: '1849',
                suffix: 'mm',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 1400 || n > 3000)
                    return '1400 – 3000 mm';
                  return null;
                },
              ),

              // Field 12
              _field(
                ctrl: _heightCtrl,
                label: 'Vehicle Height',
                hint: '1443',
                suffix: 'mm',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 1000 || n > 3000)
                    return '1000 – 3000 mm';
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Predict button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _predict,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7377),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Predicting...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                      : const Text(
                          'Predict',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Output display
              if (_predictedRange != null)
                Card(
                  elevation: 3,
                  color: const Color(0xFFE6F4F5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFF0D7377),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 26,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Predicted Driving Range',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0A5C60),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_predictedRange!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D7377),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '  Prediction successful',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0D7377),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error display
              if (_errorMessage != null)
                Card(
                  elevation: 2,
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
