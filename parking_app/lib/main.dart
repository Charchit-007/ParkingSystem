// main.dart
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking Slot Booking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// API Service Class
class ParkingService {
  final String host;
  final int port;

  ParkingService({this.host = '127.0.0.1', this.port = 5555});

  Future<Map<String, dynamic>> sendRequest(Map<String, dynamic> request) async {
    try {
      print('Connecting to $host:$port...');
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: 5),
      );

      print('Connected! Sending request: $request');

      // Send request
      socket.write(jsonEncode(request));
      await socket.flush();

      // Receive response
      final completer = Completer<String>();
      final buffer = StringBuffer();

      socket.listen(
        (data) {
          buffer.write(utf8.decode(data));
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      final response = await completer.future;
      socket.close();

      print('Response received: $response');
      return jsonDecode(response);
    } catch (e) {
      print('Error in sendRequest: $e');
      return {
        'status': 'error',
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getSlots() async {
    return await sendRequest({'action': 'get_slots'});
  }

  Future<Map<String, dynamic>> bookSlot({
    required int slotId,
    required String userName,
    required String vehicleNumber,
    required int duration,
  }) async {
    return await sendRequest({
      'action': 'book_slot',
      'slot_id': slotId,
      'user_name': userName,
      'vehicle_number': vehicleNumber,
      'duration': duration,
    });
  }

  Future<Map<String, dynamic>> getMyBookings(String userName) async {
    return await sendRequest({'action': 'my_bookings', 'user_name': userName});
  }

  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    return await sendRequest({
      'action': 'cancel_booking',
      'booking_id': bookingId,
    });
  }
}

// Home Page
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _nameController = TextEditingController();
  String? userName;

  @override
  Widget build(BuildContext context) {
    if (userName == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Parking Slot Booking')),
        body: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_parking, size: 100, color: Colors.blue),
              SizedBox(height: 30),
              Text(
                'Welcome to Parking System',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Enter Your Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    setState(() {
                      userName = _nameController.text.trim();
                    });
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  child: Text('Continue', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DashboardPage(userName: userName!);
  }
}

// Dashboard Page
class DashboardPage extends StatefulWidget {
  final String userName;

  const DashboardPage({super.key, required this.userName});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ParkingSlotsPage(userName: widget.userName),
      MyBookingsPage(userName: widget.userName),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${widget.userName}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: 'Book Slot',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'My Bookings'),
        ],
      ),
    );
  }
}

// Parking Slots Page
class ParkingSlotsPage extends StatefulWidget {
  final String userName;

  const ParkingSlotsPage({super.key, required this.userName});

  @override
  // ignore: library_private_types_in_public_api
  _ParkingSlotsPageState createState() => _ParkingSlotsPageState();
}

class _ParkingSlotsPageState extends State<ParkingSlotsPage> {
  final ParkingService _service = ParkingService(host: '192.168.1.6');
  List<dynamic> slots = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  Future<void> loadSlots() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final response = await _service.getSlots();
    print('Load slots response: $response');

    setState(() {
      isLoading = false;
      if (response['status'] == 'success') {
        slots = response['slots'] ?? [];

        slots.sort((a, b) {
          final numA = int.parse(a['slot_number'].substring(1));
          final numB = int.parse(b['slot_number'].substring(1));
          return numA.compareTo(numB);
        });

        print('Loaded ${slots.length} slots');
      } else {
        errorMessage = response['message'] ?? 'Failed to load slots';
        print('Error: $errorMessage');
      }
    });
  }

  void bookSlot(Map<String, dynamic> slot) {
    showDialog(
      context: context,
      builder: (context) => BookSlotDialog(
        slot: slot,
        userName: widget.userName,
        onBooked: loadSlots,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading slots...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 20),
            Text('Error: $errorMessage'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: loadSlots, child: Text('Retry')),
          ],
        ),
      );
    }

    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 60, color: Colors.grey),
            SizedBox(height: 20),
            Text('No parking slots available'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: loadSlots, child: Text('Refresh')),
          ],
        ),
      );
    }

    final availableCount = slots
        .where((s) => s['status'] == 'Available')
        .length;
    final occupiedCount = slots.where((s) => s['status'] == 'Occupied').length;

    return RefreshIndicator(
      onRefresh: loadSlots,
      child: ListView(
        padding: EdgeInsets.all(10),
        children: [
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusIndicator(
                    'Available',
                    availableCount,
                    Colors.green,
                  ),
                  _buildStatusIndicator('Occupied', occupiedCount, Colors.red),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final isAvailable = slot['status'] == 'Available';

              return GestureDetector(
                onTap: isAvailable ? () => bookSlot(slot) : null,
                child: Card(
                  color: isAvailable ? Colors.green[100] : Colors.red[100],
                  elevation: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_parking,
                        size: 40,
                        color: isAvailable ? Colors.green : Colors.red,
                      ),
                      SizedBox(height: 8),
                      Text(
                        slot['slot_number'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        isAvailable ? 'Available' : 'Occupied',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAvailable
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }
}

// Book Slot Dialog
class BookSlotDialog extends StatefulWidget {
  final Map<String, dynamic> slot;
  final String userName;
  final VoidCallback onBooked;

  const BookSlotDialog({
    super.key,
    required this.slot,
    required this.userName,
    required this.onBooked,
  });

  @override
  // ignore: library_private_types_in_public_api
  _BookSlotDialogState createState() => _BookSlotDialogState();
}

class _BookSlotDialogState extends State<BookSlotDialog> {
  final TextEditingController _vehicleController = TextEditingController();
  final ParkingService _service = ParkingService(host: '192.168.1.6');
  int selectedDuration = 1;
  bool isBooking = false;

  Future<void> confirmBooking() async {
    if (_vehicleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter vehicle number')));
      return;
    }

    setState(() {
      isBooking = true;
    });

    final response = await _service.bookSlot(
      slotId: widget.slot['slot_id'],
      userName: widget.userName,
      vehicleNumber: _vehicleController.text.trim(),
      duration: selectedDuration,
    );

    setState(() {
      isBooking = false;
    });

    if (response['status'] == 'success') {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      widget.onBooked();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slot booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Booking failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Book Slot ${widget.slot['slot_number']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _vehicleController,
            decoration: InputDecoration(
              labelText: 'Vehicle Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_car),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Text('Duration: ', style: TextStyle(fontSize: 16)),
              SizedBox(width: 10),
              DropdownButton<int>(
                value: selectedDuration,
                items: List.generate(12, (index) => index + 1)
                    .map(
                      (hours) => DropdownMenuItem(
                        value: hours,
                        child: Text('$hours hour${hours > 1 ? 's' : ''}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDuration = value!;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isBooking ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isBooking ? null : confirmBooking,
          child: isBooking
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Book Now'),
        ),
      ],
    );
  }
}

// My Bookings Page
class MyBookingsPage extends StatefulWidget {
  final String userName;

  const MyBookingsPage({super.key, required this.userName});

  @override
  // ignore: library_private_types_in_public_api
  _MyBookingsPageState createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final ParkingService _service = ParkingService(host: '192.168.1.6');
  List<dynamic> bookings = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final response = await _service.getMyBookings(widget.userName);

    setState(() {
      isLoading = false;
      if (response['status'] == 'success') {
        bookings = response['bookings'] ?? [];
      } else {
        errorMessage = response['message'] ?? 'Failed to load bookings';
      }
    });
  }

  Future<void> cancelBooking(int bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await _service.cancelBooking(bookingId);

      if (response['status'] == 'success') {
        loadBookings();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Cancellation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 20),
            Text('Error: $errorMessage'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: loadBookings, child: Text('Retry')),
          ],
        ),
      );
    }

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text('No bookings yet', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadBookings,
      child: ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final isActive = booking['booking_status'] == 'Active';

          return Card(
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isActive ? Colors.green : Colors.grey,
                child: Icon(Icons.local_parking, color: Colors.white),
              ),
              title: Text(
                'Slot ${booking['slot_number']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicle: ${booking['vehicle_number']}'),
                  Text('Time: ${booking['start_time']}'),
                  Text(
                    'Status: ${booking['booking_status']}',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: isActive
                  ? IconButton(
                      icon: Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => cancelBooking(booking['booking_id']),
                    )
                  : null,
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
