# Temporary Firestore Rules for Development

These rules are **only for development** and should never be used in production as they allow anyone to read and write to your database!

Copy and paste these into the Firebase Console > Firestore Database > Rules tab:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Allow read and write access to all users during development
      allow read, write: if true;
    }
  }
}
```

After testing is complete and you're ready for production, replace these rules with the more secure rules from `firestore.rules`. 