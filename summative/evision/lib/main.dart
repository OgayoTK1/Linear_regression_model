import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const EVRangeApp());

// ── App Root ──────────────────────────────────────────────────────────────────
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

// ── Prediction Page ───────────────────────────────────────────────────────────
class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  // ── API URL ───────────────────────────────────────────────────────────────
  // For local testing on Android emulator use: http://10.0.2.2:8000/predict
  // For iOS simulator use:                     http://127.0.0.1:8000/predict
  static const String _apiUrl =
      'https://ev-range-predictor.onrender.com/predict';

  // ── Form + Controllers (one per input variable = 6 text fields) ───────────
  final _formKey     = GlobalKey<FormState>();
  final _battCtrl    = TextEditingController();  // battery_capacity_kwh
  final _powerCtrl   = TextEditingController();  // motor_power_kw
  final _weightCtrl  = TextEditingController();  // vehicle_weight_kg
  final _dragCtrl    = TextEditingController();  // drag_coefficient
  final _motorsCtrl  = TextEditingController();  // num_motors
  final _chargeCtrl  = TextEditingController();  // fast_charge_kw

  // ── Dropdown + Switch (encoded as integers in the API call) ───────────────
  String _driveType    = 'FWD';   // FWD | AWD | RWD
  bool   _regenBraking = false;

  // ── Output state ──────────────────────────────────────────────────────────
  bool    _isLoading      = false;
  double? _predictedRange;
  String? _errorMessage;

  @override
  void dispose() {
    _battCtrl.dispose();
    _powerCtrl.dispose();
    _weightCtrl.dispose();
    _dragCtrl.dispose();
    _motorsCtrl.dispose();
    _chargeCtrl.dispose();
    super.dispose();
  }

  // ── API Call ──────────────────────────────────────────────────────────────
  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading      = true;
      _errorMessage   = null;
      _predictedRange = null;
    });

    try {
      final body = jsonEncode({
        'battery_capacity_kwh': double.parse(_battCtrl.text),
        'motor_power_kw':       double.parse(_powerCtrl.text),
        'vehicle_weight_kg':    double.parse(_weightCtrl.text),
        'drag_coefficient':     double.parse(_dragCtrl.text),
        'num_motors':           int.parse(_motorsCtrl.text),
        'regen_braking':        _regenBraking ? 1 : 0,
        'fast_charge_kw':       double.parse(_chargeCtrl.text),
        'drive_AWD':            _driveType == 'AWD' ? 1 : 0,
        'drive_RWD':            _driveType == 'RWD' ? 1 : 0,
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
          _predictedRange =
              (data['predicted_range_km'] as num).toDouble();
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

  // ── Reusable Text Field Builder ───────────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    String? suffix,
    bool isInt = false,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
          preferredSize: const Size.fromHeight(26),
          child: Container(
            color: const Color(0xFF0A5C60),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: const Center(
              child: Text(
                'Enter EV specs to predict driving range',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Section heading ──────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  'Vehicle Specifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0D7377),
                  ),
                ),
              ),
              const Divider(height: 8),
              const SizedBox(height: 4),

              // ── Field 1: Battery capacity ────────────────────────────
              _field(
                ctrl: _battCtrl,
                label: 'Battery Capacity',
                hint: '75.0',
                suffix: 'kWh',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 20 || n > 200) {
                    return 'Must be between 20 and 200 kWh';
                  }
                  return null;
                },
              ),

              // ── Field 2: Motor power ─────────────────────────────────
              _field(
                ctrl: _powerCtrl,
                label: 'Motor Power',
                hint: '300',
                suffix: 'kW',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 50 || n > 750) {
                    return 'Must be between 50 and 750 kW';
                  }
                  return null;
                },
              ),

              // ── Field 3: Vehicle weight ──────────────────────────────
              _field(
                ctrl: _weightCtrl,
                label: 'Vehicle Weight',
                hint: '2100',
                suffix: 'kg',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 1200 || n > 3500) {
                    return 'Must be between 1200 and 3500 kg';
                  }
                  return null;
                },
              ),

              // ── Field 4: Drag coefficient ────────────────────────────
              _field(
                ctrl: _dragCtrl,
                label: 'Drag Coefficient (Cd)',
                hint: '0.24',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0.18 || n > 0.45) {
                    return 'Must be between 0.18 and 0.45';
                  }
                  return null;
                },
              ),

              // ── Field 5: Number of motors ────────────────────────────
              _field(
                ctrl: _motorsCtrl,
                label: 'Number of Motors',
                hint: '2',
                isInt: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 4) {
                    return 'Must be between 1 and 4';
                  }
                  return null;
                },
              ),

              // ── Field 6: Fast charge rate ────────────────────────────
              _field(
                ctrl: _chargeCtrl,
                label: 'Fast Charge Rate',
                hint: '250',
                suffix: 'kW',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0 || n > 350) {
                    return 'Must be between 0 and 350 kW';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ── Drive type dropdown ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                  value: _driveType,
                  decoration: const InputDecoration(
                    labelText: 'Drive Type',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF2F3F4),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  items: ['FWD', 'RWD', 'AWD']
                      .map((d) =>
                      DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _driveType = v!),
                ),
              ),

              // ── Regen braking switch ─────────────────────────────────
              Card(
                color: const Color(0xFFF2F3F4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Color(0xFFCACACA)),
                ),
                child: SwitchListTile(
                  title: const Text('Regenerative Braking'),
                  subtitle: Text(
                    _regenBraking ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: _regenBraking
                          ? const Color(0xFF0D7377)
                          : Colors.grey,
                    ),
                  ),
                  value: _regenBraking,
                  onChanged: (v) => setState(() => _regenBraking = v),
                  activeColor: const Color(0xFF0D7377),
                ),
              ),

              const SizedBox(height: 20),

              // ── Predict button ───────────────────────────────────────
              SizedBox(
                height: 54,
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
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Predicting...',
                          style: TextStyle(fontSize: 16)),
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

              const SizedBox(height: 22),

              // ── Output display field ─────────────────────────────────
              if (_predictedRange != null)
                Card(
                  elevation: 3,
                  color: const Color(0xFFE6F4F5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                        color: Color(0xFF0D7377), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 20),
                    child: Column(
                      children: [
                        const Text(
                          'Predicted Driving Range',
                          style: TextStyle(
                              fontSize: 15, color: Color(0xFF0A5C60)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_predictedRange!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D7377),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Note:  Prediction successful',
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

              // ── Error display field ──────────────────────────────────
              if (_errorMessage != null)
                Card(
                  elevation: 2,
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
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