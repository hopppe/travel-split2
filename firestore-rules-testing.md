# Firestore Security Rules - Testing Guide

The security rules have been updated to provide proper access control for your Free Split app. Here's how to test and ensure they're working as expected.

## Understanding the Rules

The security rules implement the following permissions:

1. **Authentication Required**: All operations require the user to be signed in
2. **Trip Reading**: A user can only read trips where they are a participant
3. **Trip Lookup by Invite Code**: A user can query trips by invite code to join them
4. **Trip Creation**: Any authenticated user can create a new trip
5. **Trip Updates**: Only participants can update a trip
6. **Trip Deletion**: Only participants can delete a trip, and only if it has 1 or fewer participants (preventing shared trip deletion)

## Testing the Rules

You can test the rules using the Firebase Emulator Suite or by testing your app in development mode:

### Using the Firebase Emulator Suite

1. Install the Firebase CLI if you haven't already:
   ```
   npm install -g firebase-tools
   ```

2. Start the emulator suite:
   ```
   firebase emulators:start
   ```

3. Open the Emulator UI (usually at http://localhost:4000)

4. Use the Firestore Rules Playground to test your rules against different scenarios

### Manual Testing in Your App

Test the following scenarios in your app:

1. **User Authentication**:
   - Try accessing trips without logging in (should fail)
   - Verify anonymous authentication works properly

2. **Trip Reading**:
   - Create a trip and verify you can read it
   - Use a different user account and verify they cannot read your trip
   - Try joining a trip with an invite code

3. **Trip Updates**:
   - Verify you can update trips you're a participant in
   - Verify you cannot update trips you're not a participant in

4. **Trip Deletion**:
   - Verify you cannot delete a trip with multiple participants
   - Verify you can delete a trip with only yourself as a participant

5. **Group Size Testing**:
   - Test with groups of various sizes (up to 50 participants)
   - The rules now support up to 50 participants in a group

## Monitoring Rules in Production

You can monitor security rule rejections in the Firebase Console:

1. Go to **Firestore Database** > **Usage**
2. Look for rejected operations in the charts
3. Check **Logs** for more detailed information about rejected requests

## Debugging Common Issues

If you encounter permission denied errors:

1. **Check Authentication**: Make sure the user is properly authenticated
2. **Check Participant Structure**: Ensure participants are stored as expected
3. **Check Query Format**: For invite code queries, ensure limit=1 and only filtering on inviteCode
4. **Examine Request Logs**: Check the Firebase Console logs for specific rejection reasons

## Rule Implementation Notes

The participant checking has been improved:

1. The previous implementation had a hard limit of checking up to 10 participants
2. The new implementation checks up to 50 participants without using recursion
3. We use a non-recursive approach that's compatible with Firestore Rules restrictions
4. If you need to support more than 50 participants, the rules can be extended with additional helper functions

## Performance Considerations

Be aware of these considerations:

1. The current implementation supports up to 50 participants per trip
2. Using complex data queries might incur additional costs due to rule evaluation
3. The rules require a specific data structure - changing the model may require rule updates 