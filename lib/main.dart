import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speed Tracker (GPS Only)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SpeedTrackerScreen(),
    );
  }
}

class SpeedTrackerScreen extends StatefulWidget {
  const SpeedTrackerScreen({super.key});

  @override
  State<SpeedTrackerScreen> createState() => _SpeedTrackerScreenState();
}

class _SpeedTrackerScreenState extends State<SpeedTrackerScreen> {
  double _currentSpeed = 0.0; // Speed in m/s
  double _currentSpeedKmh = 0.0; // Speed in km/h
  Position? _currentPosition;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  // For sensor-based speed calculation (optional)
  double _accelerometerSpeed = 0.0;
  DateTime? _lastAccelerometerTime;
  double _lastAccelerometerVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request location permissions
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
  }

  Future<void> _startTracking() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled. Please enable GPS.');
      return;
    }

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Location permissions are permanently denied.');
      return;
    }

    setState(() {
      _isTracking = true;
    });

    // Configure location settings for high accuracy GPS (satellite only)
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0, // Update on every movement
    );

    // Start listening to position stream
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        setState(() {
          _currentPosition = position;
          // Speed is provided in m/s by GPS
          _currentSpeed = position.speed;
          _currentSpeedKmh = position.speed * 3.6; // Convert to km/h
        });
      },
      onError: (error) {
        _showError('Error getting location: $error');
      },
    );

    // Start accelerometer stream for additional sensor data
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _processAccelerometerData(event);
      },
    );
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // Calculate magnitude of acceleration
    double acceleration = sqrt(event.x * event.x + 
                               event.y * event.y + 
                               event.z * event.z);
    
    DateTime now = DateTime.now();
    
    if (_lastAccelerometerTime != null) {
      // Calculate time difference in seconds
      double deltaTime = (now.difference(_lastAccelerometerTime!).inMilliseconds) / 500.0;
      
      if (deltaTime > 0) {
        // Integrate acceleration to get velocity change
        // This is a simplified calculation
        double deltaVelocity = acceleration * deltaTime;
        _lastAccelerometerVelocity += deltaVelocity;
        
        // Apply some filtering to reduce noise
        _lastAccelerometerVelocity *= 0.95; // Decay factor
        
        setState(() {
          _accelerometerSpeed = _lastAccelerometerVelocity.abs() * 3.6; // Convert to km/h
        });
      }
    }
    
    _lastAccelerometerTime = now;
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    setState(() {
      _isTracking = false;
      _currentSpeed = 0.0;
      _currentSpeedKmh = 0.0;
      _accelerometerSpeed = 0.0;
      _lastAccelerometerVelocity = 0.0;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Tracker (GPS Only)'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main Speed Display
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Current Speed',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${_currentSpeedKmh.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: _getSpeedColor(_currentSpeedKmh),
                        ),
                      ),
                      const Text(
                        'km/h',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        '${_currentSpeed.toStringAsFixed(2)} m/s',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // GPS Information
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GPS Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Status', _isTracking ? 'Tracking' : 'Stopped'),
                      if (_currentPosition != null) ...[
                        _buildInfoRow(
                          'Accuracy',
                          '${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                        ),
                        _buildInfoRow(
                          'Altitude',
                          '${_currentPosition!.altitude.toStringAsFixed(1)} m',
                        ),
                        _buildInfoRow(
                          'Latitude',
                          _currentPosition!.latitude.toStringAsFixed(6),
                        ),
                        _buildInfoRow(
                          'Longitude',
                          _currentPosition!.longitude.toStringAsFixed(6),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Sensor Information
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Column(
                      //   children: [
                        //   const Text(
                        //     'Sensor Speed',
                        //     style: TextStyle(
                        //       fontSize: 12,
                        //       color: Colors.grey,
                        //     ),
                        //   ),
                        //   Text(
                        //     '${_accelerometerSpeed.toStringAsFixed(1)} km/h',
                        //     style: const TextStyle(
                        //       fontSize: 18,
                        //       fontWeight: FontWeight.bold,
                        //     ),
                        //   ),
                        // ],
                      // ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          const Text(
                            'GPS Source',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Text(
                            'Satellite',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Control Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isTracking ? _stopTracking : _startTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      _isTracking ? 'Stop Tracking' : 'Start Tracking',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 30) return Colors.green;
    if (speed < 60) return Colors.orange;
    if (speed < 100) return Colors.deepOrange;
    return Colors.red;
  }
}

