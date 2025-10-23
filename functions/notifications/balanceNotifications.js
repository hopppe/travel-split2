const { sendNotificationToUsers } = require('../utils/notificationHelpers');
const { getLocalizedMessage } = require('../utils/localization');

/**
 * Send notification when user's balance is settled
 */
async function handleBalanceSettled(userId, trip, tripId) {
  console.log(`Handling balance settled for user: ${userId}`);

  return sendNotificationToUsers(
    [userId],
    {
      title: await getLocalizedMessage(userId, 'notification_balance_settled_title'),
      body: await getLocalizedMessage(
        userId,
        'notification_balance_settled_body',
        {
          trip: trip.name
        }
      ),
      data: {
        type: 'balance_settled',
        tripId: tripId
      }
    }
  );
}

module.exports = {
  handleBalanceSettled
};
