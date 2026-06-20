import 'package:flutter/material.dart';

import 'thermostat.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Thermostat Demo', debugShowCheckedModeBanner: false, home: ThermostatPage());
  }
}

class ThermostatPage extends StatefulWidget {
  const ThermostatPage({super.key});

  @override
  State<ThermostatPage> createState() => _ThermostatPageState();
}

class _ThermostatPageState extends State<ThermostatPage> {
  static const double _currentTemp = 65;

  double _targetTemp = 72;

  ThermostatMode get _mode {
    if (_targetTemp > _currentTemp) return ThermostatMode.heating;
    if (_targetTemp < _currentTemp) return ThermostatMode.cooling;
    return ThermostatMode.off;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Thermostat(
            targetTemp: _targetTemp,
            currentTemp: _currentTemp,
            mode: _mode,
            minTemp: 50,
            maxTemp: 90,
            onTargetTempChanged: (t) => setState(() => _targetTemp = t),
          ),
        ),
      ),
    );
  }
}
