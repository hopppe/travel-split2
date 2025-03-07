import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct YourApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
      }
    }
  }
}

# Firebase Setup Guide for Travel Split

This guide will walk you through setting up Firebase with your Travel Split app to enable trip sharing functionality between different users and devices.

## 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and follow the prompts
3. Name your project (e.g., "Travel Split")
4. Choose whether to enable Google Analytics (recommended)
5. Follow the setup wizard to complete project creation

## 2. Register Your iOS App

1. In the Firebase Console, click on your project
2. Click the iOS icon (+ button) to add an iOS app
3. Enter your app's Bundle ID (check your Xcode project settings)
4. Enter a nickname for your app (optional)
5. Click "Register app"
6. Download the `GoogleService-Info.plist` file

## 3. Add the Firebase SDK to Your Project

The simplest way is to use Swift Package Manager:

1. In Xcode, go to File > Add Packages
2. Enter the Firebase iOS SDK URL: `https://github.com/firebase/firebase-ios-sdk.git`
3. Select the following packages:
   - FirebaseCore
   - FirebaseFirestore
   - FirebaseAuth (if you want user authentication)
4. Click "Add Package"

## 4. Add GoogleService-Info.plist to Your Project

1. Drag the downloaded `GoogleService-Info.plist` into your Xcode project
2. Make sure "Copy items if needed" is checked
3. Add to your main app target
4. Verify that the file's Build Phase is set to "Copy Bundle Resources"

## 5. Initialize Firebase in Your App

1. Open your `AppDelegate.swift` file (or create it if using SwiftUI lifecycle)
2. Import Firebase: `import FirebaseCore`
3. Add the following to `didFinishLaunchingWithOptions` or SwiftUI's app initializer:
   ```swift
   FirebaseApp.configure()
   ```

## 6. Set Up Firestore Database

1. In the Firebase Console, go to Firestore Database
2. Click "Create Database"
3. Choose a starting mode (Test Mode is fine for development)
4. Select a location for your database (choose the one closest to most of your users)

## 7. Set Up Firestore Security Rules

In the Firebase Console:

1. Go to Firestore Database > Rules
2. Set up the following basic rules (customize as needed):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /trips/{tripId} {
      allow read: if request.auth != null && 
                  resource.data.participants[request.auth.uid] != null;
      allow write: if request.auth != null;
    }
  }
}
```

## 8. Uncomment Firestore Code in the App

1. Open `FirebaseService.swift`
2. Uncomment the imports at the top:
   ```swift
   import FirebaseCore
   import FirebaseFirestore
   ```
3. Uncomment the Firestore implementation code in each method
4. Remove any placeholder/mock implementations

## 9. Test Firestore Integration

1. Run your app
2. Create a new trip
3. Check the Firebase Console > Firestore Database to verify the trip was created
4. Try sharing a trip with another device/simulator to test the functionality

## Troubleshooting

- **Build errors**: Make sure all required Firebase packages are included
- **Runtime crashes**: Ensure `FirebaseApp.configure()` is called once during app startup
- **Missing data**: Check Firestore Console to verify data is being saved
- **Authentication issues**: Implement Firebase Authentication if needed for more security

## Next Steps

Once basic sharing is working, you can enhance your app with:

1. User authentication (Firebase Auth)
2. User profile photos (Firebase Storage)
3. Push notifications for expense updates (Cloud Messaging)
4. Trip statistics and insights (Firebase Analytics)

For more detailed information, visit the [Firebase documentation](https://firebase.google.com/docs).