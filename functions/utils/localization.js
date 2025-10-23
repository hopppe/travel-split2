const admin = require('firebase-admin');

// Notification message templates
const messages = {
  en: {
    // Expense notifications
    notification_expense_added_title: 'New Expense',
    notification_expense_added_body: '{name} added {title} - {amount} in {trip}',
    notification_expense_updated_title: 'Expense Updated',
    notification_expense_updated_body: '{title} updated to {amount} in {trip}',
    notification_expense_deleted_title: 'Expense Deleted',
    notification_expense_deleted_body: '{title} was deleted from {trip}',

    // Payment notifications
    notification_payment_received_title: 'Payment Received',
    notification_payment_received_body: '{name} paid you {amount} in {trip}',

    // Balance notifications
    notification_balance_settled_title: 'Balance Settled',
    notification_balance_settled_body: 'Your balance is settled in {trip} ✓',

    // Participant notifications
    notification_participant_joined_title: 'New Participant',
    notification_participant_joined_body: '{name} joined {trip}',
    notification_participant_left_title: 'Participant Left',
    notification_participant_left_body: '{name} left {trip}',
    notification_participant_claimed_title: 'Account Claimed',
    notification_participant_claimed_body: '{name} claimed their account in {trip}',
    notification_added_to_trip_title: 'Added to Trip',
    notification_added_to_trip_body: 'You were added to {trip}'
  },
  ar: {
    // Expense notifications (Arabic - RTL)
    notification_expense_added_title: 'مصروف جديد',
    notification_expense_added_body: 'أضاف {name} {title} - {amount} في {trip}',
    notification_expense_updated_title: 'تحديث المصروف',
    notification_expense_updated_body: 'تم تحديث {title} إلى {amount} في {trip}',
    notification_expense_deleted_title: 'حذف المصروف',
    notification_expense_deleted_body: 'تم حذف {title} من {trip}',

    // Payment notifications
    notification_payment_received_title: 'تم استلام الدفع',
    notification_payment_received_body: 'دفع لك {name} {amount} في {trip}',

    // Balance notifications
    notification_balance_settled_title: 'تم تسوية الرصيد',
    notification_balance_settled_body: 'تم تسوية رصيدك في {trip} ✓',

    // Participant notifications
    notification_participant_joined_title: 'مشارك جديد',
    notification_participant_joined_body: 'انضم {name} إلى {trip}',
    notification_participant_left_title: 'غادر المشارك',
    notification_participant_left_body: 'غادر {name} {trip}',
    notification_participant_claimed_title: 'تم المطالبة بالحساب',
    notification_participant_claimed_body: 'طالب {name} بحسابه في {trip}',
    notification_added_to_trip_title: 'تمت الإضافة إلى الرحلة',
    notification_added_to_trip_body: 'تمت إضافتك إلى {trip}'
  }
};

/**
 * Get localized notification message
 * @param {string} userId - User ID to get language preference
 * @param {string} key - Message key
 * @param {object} params - Template parameters
 */
async function getLocalizedMessage(userId, key, params = {}) {
  try {
    // Get user's language preference
    let language = 'en'; // Default to English

    if (userId && !userId.startsWith('unclaimed_')) {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (userDoc.exists) {
        language = userDoc.data().language || 'en';
      }
    }

    // Get message template
    const template = messages[language]?.[key] || messages.en[key] || key;

    // Replace parameters
    let message = template;
    for (const [param, value] of Object.entries(params)) {
      message = message.replace(`{${param}}`, value);
    }

    return message;
  } catch (error) {
    console.error('Error getting localized message:', error);
    return key; // Fallback to key itself
  }
}

module.exports = {
  getLocalizedMessage
};
