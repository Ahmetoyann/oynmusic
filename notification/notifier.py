import os
import random
import time
import schedule
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, messaging

# ---------------------------------------------------------
# SETUP INSTRUCTIONS:
# 1. Firebase Console -> Project Settings -> Service Accounts
# 2. Click "Generate new private key", download the JSON file.
# 3. Rename the downloaded file to 'serviceAccountKey.json' 
#    and place it in this 'notification' folder.
# 4. Make sure your Flutter app subscribes to the 'all_users' topic:
#    FirebaseMessaging.instance.subscribeToTopic('all_users');
# ---------------------------------------------------------

SERVICE_ACCOUNT_FILE = 'serviceAccountKey.json'
TOPIC_NAME = 'all_users'

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"Error: {SERVICE_ACCOUNT_FILE} not found!")
        print("Please download it from Firebase Console and place it here.")
        exit(1)
        
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        print(f"Failed to initialize Firebase: {e}")
        exit(1)

def send_random_notification():
    """Sends a push notification to all users subscribed to the topic"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Sending random notification...")
    
    # List of possible messages
    messages = [
        ("Günün Şarkısı Seni Bekliyor!", "Hemen uygulamaya girip dinlemeye başla."),
        ("Müzik Molası Zamanı!", "En sevdiğin parçaları dinlemek için harika bir zaman."),
        ("Yeni Listeni Keşfet!", "Senin için harika müziklerimiz var, uygulamaya dön!"),
        ("Kulaklıklarını Tak!", "Dünyadan biraz uzaklaşmak için favori müziklerini aç.")
    ]
    title, body = random.choice(messages)
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        topic=TOPIC_NAME,
    )
    
    try:
        response = messaging.send(message)
        print(f"Successfully sent message: {response}")
    except Exception as e:
        print(f"Error sending message: {e}")

def schedule_daily_notifications():
    """Schedules 3 random notifications for the current day."""
    print(f"[{datetime.now().strftime('%Y-%m-%d')}] Scheduling new times for today...")
    
    # Clear any existing jobs to avoid duplicates when rescheduling next day
    schedule.clear()
    
    # Generate 3 random times between 09:00 and 22:00
    times = []
    for _ in range(3):
        hour = random.randint(9, 21)
        minute = random.randint(0, 59)
        time_str = f"{hour:02d}:{minute:02d}"
        times.append(time_str)
    
    # Sort for cleaner logging
    times.sort()
    
    for t in times:
        schedule.every().day.at(t).do(send_random_notification)
        print(f" -> Scheduled notification for {t}")
        
    # Also schedule tomorrow's randomization at midnight
    schedule.every().day.at("00:01").do(schedule_daily_notifications)

def main():
    initialize_firebase()
    
    # Run the scheduler setup for today
    schedule_daily_notifications()
    
    print("Notification service is running. Press Ctrl+C to exit.")
    
    # Keep the script running
    while True:
        schedule.run_pending()
        time.sleep(60) # check every minute

if __name__ == "__main__":
    main()
