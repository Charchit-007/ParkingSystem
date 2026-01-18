import sqlite3

def initialize_database(db_name='parking_system.db'):
    """Create database tables and initialize parking slots"""
    conn = sqlite3.connect(db_name)
    cursor = conn.cursor()
    
    print("Initializing database...")
    
    # Parking slots table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS parking_slots (
            slot_id INTEGER PRIMARY KEY AUTOINCREMENT,
            slot_number TEXT UNIQUE NOT NULL,
            status TEXT DEFAULT 'Available'
        )
    ''')
    print("✓ Created parking_slots table")
    
    # Bookings table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS bookings (
            booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
            slot_id INTEGER NOT NULL,
            user_name TEXT NOT NULL,
            vehicle_number TEXT NOT NULL,
            start_time TIMESTAMP NOT NULL,
            booking_status TEXT DEFAULT 'Active',
            FOREIGN KEY (slot_id) REFERENCES parking_slots(slot_id)
        )
    ''')
    print("✓ Created bookings table")
    
    conn.commit()
    
    # Initialize parking slots if empty
    cursor.execute('SELECT COUNT(*) FROM parking_slots')
    if cursor.fetchone()[0] == 0:
        create_initial_slots(cursor)
        conn.commit()
        print("✓ Initialized parking slots")
    else:
        print("✓ Parking slots already exist")
    
    conn.close()
    print("Database initialization complete!\n")

def create_initial_slots(cursor):
    """Create initial parking slots A1 to A10"""
    slots = []
    for i in range(1, 11):
        slots.append((f'A{i}', 'Available'))
    
    cursor.executemany(
        'INSERT INTO parking_slots (slot_number, status) VALUES (?, ?)',
        slots
    )
    print(f"  Created {len(slots)} parking slots (A1-A10)")

def reset_database(db_name='parking_system.db'):
    """Reset database - Delete all tables and reinitialize"""
    conn = sqlite3.connect(db_name)
    cursor = conn.cursor()
    
    print("Resetting database...")
    
    # Drop existing tables
    cursor.execute('DROP TABLE IF EXISTS bookings')
    cursor.execute('DROP TABLE IF EXISTS parking_slots')
    print("✓ Dropped existing tables")
    
    conn.commit()
    conn.close()
    
    # Reinitialize
    initialize_database(db_name)

if __name__ == '__main__':
    # Run this file directly to initialize the database
    print("=" * 50)
    print("Parking System Database Setup")
    print("=" * 50)
    print("\nOptions:")
    print("1. Initialize database (safe - won't delete existing data)")
    print("2. Reset database (WARNING - will delete all data)")
    
    choice = input("\nEnter your choice (1 or 2): ")
    
    if choice == '1':
        initialize_database()
    elif choice == '2':
        confirm = input("Are you sure you want to reset? This will delete all data. (yes/no): ")
        if confirm.lower() == 'yes':
            reset_database()
        else:
            print("Reset cancelled.")
    else:
        print("Invalid choice. Running default initialization...")
        initialize_database()