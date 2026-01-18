# Parking Slot Booking System

A real-time parking slot booking system using Python socket server and Flutter mobile app with SQLite database integration.

## 📋 Features

- **Real-time slot booking** - View and book available parking slots
- **Network communication** - Client-server architecture using TCP sockets
- **Database integration** - SQLite for persistent data storage
- **Multi-threaded server** - Handle multiple clients simultaneously
- **Cross-platform app** - Flutter app works on Android, iOS, Linux, and Web

## 🏗️ Architecture

```
Flutter Mobile App → WiFi/Network → Python Socket Server → SQLite Database
```

## 🛠️ Technologies Used

- **Backend:** Python 3, Socket Programming, SQLite3
- **Frontend:** Flutter (Dart)
- **Protocol:** TCP/IP, JSON
- **Database:** SQLite

## 📁 Project Structure

```
ParkingBookingSystem/
├── init_db.py          # Database initialization
├── Park_Server.py      # Python socket server
├── test_client.py      # Python test client
└── parking_app/        # Flutter mobile application
    └── lib/
        └── main.dart
```

## 🚀 Setup & Installation

### Prerequisites

- Python 3.x
- Flutter SDK
- SQLite3

### Server Setup

```bash
# 1. Initialize database
python3 init_db.py

# 2. Start server
python3 Park_Server.py
```

Server runs on `0.0.0.0:5555`

### Mobile App Setup

```bash
# 1. Navigate to app directory
cd parking_app

# 2. Update server IP in lib/main.dart
# Change '127.0.0.1' to your server's IP address

# 3. Run app
flutter run
```

## 💻 Usage

### Available Operations

1. **View Slots** - See all parking slots and their status
2. **Book Slot** - Reserve a parking slot with duration
3. **My Bookings** - View your booking history
4. **Cancel Booking** - Cancel an active booking


## 🗄️ Database Schema

### parking_slots
```sql
slot_id         INTEGER PRIMARY KEY
slot_number     TEXT UNIQUE
status          TEXT (Available/Occupied)
```

### bookings
```sql
booking_id      INTEGER PRIMARY KEY
slot_id         INTEGER FOREIGN KEY
user_name       TEXT
vehicle_number  TEXT
start_time      TIMESTAMP
booking_status  TEXT (Active/Cancelled)
```

## 🌐 Network Configuration

### For Local Testing
- Server IP: `127.0.0.1`
- Port: `5555`

### For LAN/WiFi Testing
```bash
# Find your IP
hostname -I

# Update in Flutter app (lib/main.dart)
ParkingService({this.host = 'YOUR_IP_HERE', this.port = 5555});
```

**Database Error:**
- Run `python3 init_db.py` to reset database
- Check file permissions
