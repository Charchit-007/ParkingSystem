import socket
import threading
import json
import sqlite3
from datetime import datetime
from Init_DB_Park import initialize_database

class ParkingServer:
    def __init__(self, host='0.0.0.0', port=5555):
        self.host = host
        self.port = port
        self.server_socket = None
        self.db_name = 'parking_system.db'
        # Initialize database using external module
        initialize_database(self.db_name)
    
    def get_db_connection(self):
        """Get database connection"""
        conn = sqlite3.connect(self.db_name)
        conn.row_factory = sqlite3.Row
        return conn
    
    def handle_get_slots(self, data):
        """Get all parking slots with their status"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('SELECT * FROM parking_slots ORDER BY slot_number')
            slots = cursor.fetchall()
            conn.close()
            
            slots_list = []
            for slot in slots:
                slots_list.append({
                    'slot_id': slot['slot_id'],
                    'slot_number': slot['slot_number'],
                    'status': slot['status']
                })
            
            return {
                'status': 'success',
                'slots': slots_list
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': str(e)
            }
    
    def handle_book_slot(self, data):
        """Handle parking slot booking"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            slot_id = data.get('slot_id')
            user_name = data.get('user_name')
            vehicle_number = data.get('vehicle_number')
            
            # Check if slot is available
            cursor.execute('SELECT status, slot_number FROM parking_slots WHERE slot_id = ?', (slot_id,))
            slot = cursor.fetchone()
            
            if not slot:
                conn.close()
                return {'status': 'error', 'message': 'Slot not found'}
            
            if slot['status'] != 'Available':
                conn.close()
                return {'status': 'error', 'message': 'Slot is already occupied'}
            
            # Create booking
            start_time = datetime.now()
            
            cursor.execute(
                '''INSERT INTO bookings (slot_id, user_name, vehicle_number, start_time)
                   VALUES (?, ?, ?, ?)''',
                (slot_id, user_name, vehicle_number, start_time)
            )
            booking_id = cursor.lastrowid
            
            # Update slot status to Occupied
            cursor.execute(
                'UPDATE parking_slots SET status = ? WHERE slot_id = ?',
                ('Occupied', slot_id)
            )
            
            conn.commit()
            conn.close()
            
            return {
                'status': 'success',
                'message': f'Slot {slot["slot_number"]} booked successfully',
                'booking_id': booking_id,
                'slot_number': slot['slot_number'],
                'start_time': start_time.strftime('%Y-%m-%d %H:%M:%S')
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': str(e)
            }
    
    def handle_cancel_booking(self, data):
        """Cancel a booking"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            booking_id = data.get('booking_id')
            
            # Get booking details
            cursor.execute(
                'SELECT slot_id, booking_status FROM bookings WHERE booking_id = ?',
                (booking_id,)
            )
            booking = cursor.fetchone()
            
            if not booking:
                conn.close()
                return {'status': 'error', 'message': 'Booking not found'}
            
            if booking['booking_status'] == 'Cancelled':
                conn.close()
                return {'status': 'error', 'message': 'Booking already cancelled'}
            
            # Update booking status
            cursor.execute(
                'UPDATE bookings SET booking_status = ? WHERE booking_id = ?',
                ('Cancelled', booking_id)
            )
            
            # Update slot status to Available
            cursor.execute(
                'UPDATE parking_slots SET status = ? WHERE slot_id = ?',
                ('Available', booking['slot_id'])
            )
            
            conn.commit()
            conn.close()
            
            return {
                'status': 'success',
                'message': 'Booking cancelled successfully'
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': str(e)
            }
    
    def handle_my_bookings(self, data):
        """Get bookings for a specific user"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            user_name = data.get('user_name')
            
            cursor.execute(
                '''SELECT b.*, p.slot_number
                   FROM bookings b
                   JOIN parking_slots p ON b.slot_id = p.slot_id
                   WHERE b.user_name = ?
                   ORDER BY b.start_time DESC''',
                (user_name,)
            )
            
            bookings = cursor.fetchall()
            conn.close()
            
            bookings_list = []
            for booking in bookings:
                bookings_list.append({
                    'booking_id': booking['booking_id'],
                    'slot_number': booking['slot_number'],
                    'vehicle_number': booking['vehicle_number'],
                    'start_time': booking['start_time'],
                    'booking_status': booking['booking_status']
                })
            
            return {
                'status': 'success',
                'bookings': bookings_list
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': str(e)
            }
    
    def process_request(self, data):
        """Process client request based on action"""
        action = data.get('action')
        
        if action == 'get_slots':
            return self.handle_get_slots(data)
        elif action == 'book_slot':
            return self.handle_book_slot(data)
        elif action == 'cancel_booking':
            return self.handle_cancel_booking(data)
        elif action == 'my_bookings':
            return self.handle_my_bookings(data)
        else:
            return {
                'status': 'error',
                'message': 'Unknown action'
            }
    
    def handle_client(self, client_socket, address):
        """Handle individual client connection"""
        print(f"New connection from {address}")
        
        try:
            # Receive data from client
            data = client_socket.recv(4096).decode('utf-8')
            
            if not data:
                return
            
            # Parse JSON request
            request = json.loads(data)
            print(f"Request from {address}: {request.get('action')}")
            
            # Process request
            response = self.process_request(request)
            
            # Send response
            response_json = json.dumps(response)
            print(f"Sending response to {address}: {response_json[:100]}...")  # Print first 100 chars
            client_socket.sendall(response_json.encode('utf-8'))
            
            # Wait a bit to ensure data is sent
            import time
            time.sleep(0.1)
                
        except Exception as e:
            print(f"Error handling client {address}: {e}")
        finally:
            client_socket.close()
            print(f"Connection closed: {address}")
    
    def start(self):
        """Start the server"""
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(5)
        
        print(f"Server started on {self.host}:{self.port}")
        print("Waiting for connections...")
        
        try:
            while True:
                client_socket, address = self.server_socket.accept()
                
                # Create new thread for each client
                client_thread = threading.Thread(
                    target=self.handle_client,
                    args=(client_socket, address)
                )
                client_thread.daemon = True
                client_thread.start()
                
        except KeyboardInterrupt:
            print("\nShutting down server...")
        finally:
            self.server_socket.close()

if __name__ == '__main__':
    server = ParkingServer(host='0.0.0.0', port=5555)
    server.start()