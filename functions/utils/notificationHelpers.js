const admin = require('firebase-admin');

/**
 * Send notification to multiple users
 * @param {string[]} userIds - Array of user IDs to send notification to
 * @param {object} notification - Notification payload
 */
async function sendNotificationToUsers(userIds, notification) {
  if (!userIds || userIds.length === 0) {
    console.log('No recipients for notification');
    return;
  }

  try {
    // Get FCM tokens for all users
    const tokens = await getParticipantTokens(userIds);

    if (tokens.length === 0) {
      console.log('No FCM tokens found for recipients');
      return;
    }

    // Build notification message
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
        sound: 'default'
      },
      data: notification.data,
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: 'default'
          }
        }
      },
      tokens: tokens
    };

    // Send multicast message
    const response = await admin.messaging().sendMulticast(message);

    console.log(`Successfully sent ${response.successCount} notification(s)`);

    if (response.failureCount > 0) {
      console.warn(`Failed to send ${response.failureCount} notification(s)`);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`Error sending to token ${tokens[idx]}:`, resp.error);
        }
      });
    }

    return response;
  } catch (error) {
    console.error('Error sending notifications:', error);
    throw error;
  }
}

/**
 * Get FCM tokens for participant IDs
 * Also checks if notifications are enabled for each user
 */
async function getParticipantTokens(participantIds) {
  const tokens = [];

  for (const participantId of participantIds) {
    try {
      // Skip unclaimed participants
      if (participantId.startsWith('unclaimed_')) {
        continue;
      }

      const userDoc = await admin.firestore()
        .collection('users')
        .doc(participantId)
        .get();

      if (!userDoc.exists) {
        console.log(`User ${participantId} not found`);
        continue;
      }

      const userData = userDoc.data();

      // Check if user has notifications enabled
      const notificationsEnabled = userData.notificationsEnabled !== false; // Default to true

      if (!notificationsEnabled) {
        console.log(`User ${participantId} has notifications disabled`);
        continue;
      }

      // Get FCM token
      const fcmToken = userData.fcmToken;

      if (fcmToken) {
        tokens.push(fcmToken);
      } else {
        console.log(`User ${participantId} has no FCM token`);
      }
    } catch (error) {
      console.error(`Error fetching token for user ${participantId}:`, error);
    }
  }

  return tokens;
}

module.exports = {
  sendNotificationToUsers,
  getParticipantTokens
};
