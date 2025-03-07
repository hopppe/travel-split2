# Travel Split Firebase Setup Guide

## Configuration Steps

1. **Enable Anonymous Authentication**:
   - Go to the [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Click on "Authentication" in the left sidebar
   - Select the "Sign-in method" tab
   - Find "Anonymous" in the list of providers
   - Click on it and toggle the switch to "Enabled"
   - Click "Save"

2. **Set up Firestore Database**:
   - In the Firebase Console, click on "Firestore Database" in the left sidebar
   - Click "Create database" if you haven't already
   - Choose "Start in test mode" for development (we'll update security rules later)
   - Select a location close to your users
   - Click "Enable"

3. **Update Firestore Security Rules**:
   - In the Firestore Database section, click on the "Rules" tab
   - Copy and paste the rules from `firestore.rules` in your project
   - Click "Publish"
   - Note that rule changes may take a few minutes to propagate

## Troubleshooting

### Authentication Issues

If you see errors like "Error signing in anonymously: An internal error has occurred":

1. **Double-check Anonymous Authentication**:
   - Verify that Anonymous Authentication is enabled as described above
   - If you just enabled it, wait a few minutes for changes to propagate

2. **Check Firebase Configuration**:
   - Ensure your `GoogleService-Info.plist` file is up-to-date and correctly placed in your project
   - Verify that your app's Bundle ID matches what's configured in Firebase

3. **Development Workaround**:
   - For testing, you can use the "Continue Without Authentication" button in the profile setup
   - This will allow local-only functionality

### Permission Errors

If you see "missing or insufficient permissions" errors:

1. **Check Authentication**:
   - Ensure authentication is working (you should see a Firebase User ID in the console logs)
   - Verify that the user ID matches between your app and Firestore documents

2. **Review Security Rules**:
   - Make sure your Firestore security rules match what's in `firestore.rules`
   - Remember that rule changes can take a few minutes to apply

3. **Temporary Test Mode**:
   - For development, you can temporarily set Firestore to test mode:
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if true;
         }
       }
     }
     ```

## Firebase Services Used

- **Firebase Authentication**: For user identity management
- **Cloud Firestore**: For storing and syncing trip data in real-time
- **Security Rules**: For controlling access to your data

## Best Practices

1. **Always authenticate users first** before attempting Firestore operations
2. **Use proper security rules** to protect your data
3. **Handle authentication failures gracefully** with clear user feedback
4. **Keep local state updated** even when cloud operations fail
5. **Test on different networks** to ensure your app works in various connectivity scenarios

## Contact Support

If you continue to experience issues, please check the [Firebase documentation](https://firebase.google.com/docs) or contact support with specific error logs. 