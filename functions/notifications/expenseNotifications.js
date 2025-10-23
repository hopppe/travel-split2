const admin = require('firebase-admin');
const { sendNotificationToUsers, getParticipantTokens } = require('../utils/notificationHelpers');
const { getLocalizedMessage } = require('../utils/localization');

/**
 * Send notification when expense is added
 */
async function handleExpenseAdded(expense, trip, tripId) {
  console.log(`Handling expense added: ${expense.title}`);

  // Get all participants except the one who paid
  const recipients = trip.participants.filter(p => p.id !== expense.paidBy.id);

  // Check if this is a payment (special expense type)
  const isPayment = expense.description === 'Payment';

  if (isPayment) {
    // For payments, only notify the recipient
    const recipient = expense.shares[0]?.user;
    if (!recipient) return;

    return sendNotificationToUsers(
      [recipient.id],
      {
        title: await getLocalizedMessage(recipient.id, 'notification_payment_received_title'),
        body: await getLocalizedMessage(
          recipient.id,
          'notification_payment_received_body',
          {
            name: expense.paidBy.name,
            amount: formatAmount(expense.amount, expense.currencyCode),
            trip: trip.name
          }
        ),
        data: {
          type: 'payment_received',
          tripId: tripId,
          expenseId: expense.id
        }
      }
    );
  } else {
    // Regular expense - notify all participants except payer
    return sendNotificationToUsers(
      recipients.map(r => r.id),
      {
        title: await getLocalizedMessage(recipients[0]?.id, 'notification_expense_added_title'),
        body: await getLocalizedMessage(
          recipients[0]?.id,
          'notification_expense_added_body',
          {
            name: expense.paidBy.name,
            title: expense.title,
            amount: formatAmount(expense.amount, expense.currencyCode),
            trip: trip.name
          }
        ),
        data: {
          type: 'expense_added',
          tripId: tripId,
          expenseId: expense.id
        }
      }
    );
  }
}

/**
 * Send notification when expense is updated
 */
async function handleExpenseUpdated(expense, trip, tripId) {
  console.log(`Handling expense updated: ${expense.title}`);

  // Notify all participants
  const recipients = trip.participants;

  return sendNotificationToUsers(
    recipients.map(r => r.id),
    {
      title: await getLocalizedMessage(recipients[0]?.id, 'notification_expense_updated_title'),
      body: await getLocalizedMessage(
        recipients[0]?.id,
        'notification_expense_updated_body',
        {
          title: expense.title,
          amount: formatAmount(expense.amount, expense.currencyCode),
          trip: trip.name
        }
      ),
      data: {
        type: 'expense_updated',
        tripId: tripId,
        expenseId: expense.id
      }
    }
  );
}

/**
 * Send notification when expense is deleted
 */
async function handleExpenseDeleted(expense, trip, tripId) {
  console.log(`Handling expense deleted: ${expense.title}`);

  // Notify all participants except the one who deleted it
  // Note: We can't easily determine who deleted it, so notify everyone
  const recipients = trip.participants;

  return sendNotificationToUsers(
    recipients.map(r => r.id),
    {
      title: await getLocalizedMessage(recipients[0]?.id, 'notification_expense_deleted_title'),
      body: await getLocalizedMessage(
        recipients[0]?.id,
        'notification_expense_deleted_body',
        {
          title: expense.title,
          trip: trip.name
        }
      ),
      data: {
        type: 'expense_deleted',
        tripId: tripId
      }
    }
  );
}

/**
 * Format amount with currency symbol
 */
function formatAmount(amount, currencyCode) {
  const symbols = {
    'USD': '$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
    'CAD': 'C$', 'AUD': 'A$', 'INR': '₹', 'RUB': '₽',
    'KRW': '₩', 'HKD': 'HK$', 'PHP': '₱', 'TRY': '₺',
    'UAH': '₴', 'NGN': '₦', 'ZAR': 'R', 'SAR': '﷼'
  };
  const symbol = symbols[currencyCode] || '$';
  return `${symbol}${amount.toFixed(2)}`;
}

module.exports = {
  handleExpenseAdded,
  handleExpenseUpdated,
  handleExpenseDeleted
};
