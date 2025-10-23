# Firebase Cloud Functions Setup Guide

**Purpose:** Backend notification system for EquiSplit push notifications
**Technology:** Firebase Cloud Functions (Node.js)
**Trigger:** Firestore document changes

---

## Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Node.js 18+ installed
3. Firebase project created (already done for EquiSplit)
4. Firebase Admin SDK access

---

## Quick Setup

```bash
# 1. Create functions directory in your project root
cd "/Users/ethanhoppe/Desktop/travel split"
mkdir functions
cd functions

# 2. Initialize Firebase Functions
firebase login
firebase init functions

# When prompted:
# - Select existing project (your EquiSplit project)
# - Choose JavaScript
# - Do you want to use ESLint? No
# - Do you want to install dependencies now? Yes

# 3. Copy the code files below into the functions directory

# 4. Deploy
firebase deploy --only functions
```

---

## File Structure

```
functions/
├── package.json (created by firebase init, modify as shown below)
├── index.js (main entry point)
├── .gitignore
├── notifications/
│   ├── expenseNotifications.js
│   ├── participantNotifications.js
│   └── balanceNotifications.js
└── utils/
    ├── notificationHelpers.js
    └── localization.js
```

---

## File: `package.json`

```json
{
  "name": "functions",
  "description": "Cloud Functions for EquiSplit Push Notifications",
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  },
  "devDependencies": {
    "firebase-functions-test": "^3.1.0"
  },
  "private": true
}
```

---

## File: `index.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Import notification handlers
const {
  handleExpenseAdded,
  handleExpenseUpdated,
  handleExpenseDeleted,
  handlePaymentRecorded
} = require('./notifications/expenseNotifications');

const {
  handleParticipantJoined,
  handleParticipantLeft,
  handleParticipantClaimed,
  handleParticipantAdded
} = require('./notifications/participantNotifications');

const {
  handleBalanceSettled
} = require('./notifications/balanceNotifications');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Main Cloud Function - Triggers when a trip document changes
 * Detects what changed and sends appropriate notifications
 */
exports.onTripChanged = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const tripId = context.params.tripId;

    console.log(`Trip ${tripId} changed, analyzing...`);

    try {
      // Detect expense changes
      const expensesAdded = detectExpensesAdded(before.expenses, after.expenses);
      const expensesUpdated = detectExpensesUpdated(before.expenses, after.expenses);
      const expensesDeleted = detectExpensesDeleted(before.expenses, after.expenses);

      // Detect participant changes
      const participantsAdded = detectParticipantsAdded(before.participants, after.participants);
      const participantsLeft = detectParticipantsLeft(before.participants, after.participants);
      const participantsClaimed = detectParticipantsClaimed(before.participants, after.participants);

      // Detect balance changes
      const balancesSettled = detectBalancesSettled(before, after);

      // Send notifications based on changes
      const promises = [];

      if (expensesAdded.length > 0) {
        console.log(`Detected ${expensesAdded.length} new expense(s)`);
        promises.push(...expensesAdded.map(expense =>
          handleExpenseAdded(expense, after, tripId)
        ));
      }

      if (expensesUpdated.length > 0) {
        console.log(`Detected ${expensesUpdated.length} updated expense(s)`);
        promises.push(...expensesUpdated.map(expense =>
          handleExpenseUpdated(expense, after, tripId)
        ));
      }

      if (expensesDeleted.length > 0) {
        console.log(`Detected ${expensesDeleted.length} deleted expense(s)`);
        promises.push(...expensesDeleted.map(expense =>
          handleExpenseDeleted(expense, after, tripId)
        ));
      }

      if (participantsAdded.length > 0) {
        console.log(`Detected ${participantsAdded.length} new participant(s)`);
        promises.push(...participantsAdded.map(participant =>
          handleParticipantJoined(participant, after, tripId)
        ));
      }

      if (participantsLeft.length > 0) {
        console.log(`Detected ${participantsLeft.length} participant(s) left`);
        promises.push(...participantsLeft.map(participant =>
          handleParticipantLeft(participant, after, tripId)
        ));
      }

      if (participantsClaimed.length > 0) {
        console.log(`Detected ${participantsClaimed.length} participant(s) claimed`);
        promises.push(...participantsClaimed.map(participant =>
          handleParticipantClaimed(participant, after, tripId)
        ));
      }

      if (balancesSettled.length > 0) {
        console.log(`Detected ${balancesSettled.length} balance(s) settled`);
        promises.push(...balancesSettled.map(userId =>
          handleBalanceSettled(userId, after, tripId)
        ));
      }

      // Wait for all notifications to be sent
      await Promise.all(promises);
      console.log(`Successfully processed ${promises.length} notification(s) for trip ${tripId}`);

    } catch (error) {
      console.error('Error processing trip changes:', error);
      throw error;
    }
  });

/**
 * Helper function to detect new expenses
 */
function detectExpensesAdded(beforeExpenses, afterExpenses) {
  const beforeIds = new Set(beforeExpenses.map(e => e.id));
  return afterExpenses.filter(e => !beforeIds.has(e.id));
}

/**
 * Helper function to detect updated expenses
 */
function detectExpensesUpdated(beforeExpenses, afterExpenses) {
  const beforeMap = new Map(beforeExpenses.map(e => [e.id, e]));
  const updated = [];

  for (const afterExpense of afterExpenses) {
    const beforeExpense = beforeMap.get(afterExpense.id);
    if (beforeExpense && hasExpenseChanged(beforeExpense, afterExpense)) {
      updated.push(afterExpense);
    }
  }

  return updated;
}

/**
 * Helper function to detect deleted expenses
 */
function detectExpensesDeleted(beforeExpenses, afterExpenses) {
  const afterIds = new Set(afterExpenses.map(e => e.id));
  return beforeExpenses.filter(e => !afterIds.has(e.id));
}

/**
 * Helper function to check if expense changed
 */
function hasExpenseChanged(before, after) {
  return before.title !== after.title ||
         before.amount !== after.amount ||
         before.paidBy.id !== after.paidBy.id ||
         JSON.stringify(before.shares) !== JSON.stringify(after.shares);
}

/**
 * Helper function to detect new participants
 */
function detectParticipantsAdded(beforeParticipants, afterParticipants) {
  const beforeIds = new Set(beforeParticipants.map(p => p.id));
  return afterParticipants.filter(p => !beforeIds.has(p.id));
}

/**
 * Helper function to detect participants who left
 */
function detectParticipantsLeft(beforeParticipants, afterParticipants) {
  const afterIds = new Set(afterParticipants.map(p => p.id));
  return beforeParticipants.filter(p => !afterIds.has(p.id));
}

/**
 * Helper function to detect claimed participants
 */
function detectParticipantsClaimed(beforeParticipants, afterParticipants) {
  const beforeMap = new Map(beforeParticipants.map(p => [p.id, p]));
  const claimed = [];

  for (const afterParticipant of afterParticipants) {
    const beforeParticipant = beforeMap.get(afterParticipant.id);
    if (beforeParticipant &&
        !beforeParticipant.isClaimed &&
        afterParticipant.isClaimed) {
      claimed.push(afterParticipant);
    }
  }

  return claimed;
}

/**
 * Helper function to detect settled balances
 * Returns array of user IDs whose balance reached zero
 */
function detectBalancesSettled(before, after) {
  const beforeBalances = calculateAllBalances(before);
  const afterBalances = calculateAllBalances(after);
  const settled = [];

  for (const [userId, afterBalance] of Object.entries(afterBalances)) {
    const beforeBalance = beforeBalances[userId] || 0;
    // Check if balance was non-zero and is now zero
    if (Math.abs(beforeBalance) > 0.01 && Math.abs(afterBalance) < 0.01) {
      settled.push(userId);
    }
  }

  return settled;
}

/**
 * Calculate balances for all participants
 */
function calculateAllBalances(trip) {
  const balances = {};

  // Initialize balances
  for (const participant of trip.participants) {
    balances[participant.id] = 0;
  }

  // Calculate from expenses
  for (const expense of trip.expenses) {
    // Payer gets credited
    balances[expense.paidBy.id] = (balances[expense.paidBy.id] || 0) + expense.amount;

    // Shares get debited
    for (const share of expense.shares) {
      balances[share.user.id] = (balances[share.user.id] || 0) - share.amount;
    }
  }

  return balances;
}
```

---

## File: `notifications/expenseNotifications.js`

```javascript
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
```

---

## File: `notifications/participantNotifications.js`

```javascript
const { sendNotificationToUsers } = require('../utils/notificationHelpers');
const { getLocalizedMessage } = require('../utils/localization');

/**
 * Send notification when participant joins trip
 */
async function handleParticipantJoined(participant, trip, tripId) {
  console.log(`Handling participant joined: ${participant.name}`);

  // Notify all existing participants except the one who joined
  const recipients = trip.participants.filter(p => p.id !== participant.id);

  return sendNotificationToUsers(
    recipients.map(r => r.id),
    {
      title: await getLocalizedMessage(recipients[0]?.id, 'notification_participant_joined_title'),
      body: await getLocalizedMessage(
        recipients[0]?.id,
        'notification_participant_joined_body',
        {
          name: participant.name,
          trip: trip.name
        }
      ),
      data: {
        type: 'participant_joined',
        tripId: tripId
      }
    }
  );
}

/**
 * Send notification when participant leaves trip
 */
async function handleParticipantLeft(participant, trip, tripId) {
  console.log(`Handling participant left: ${participant.name}`);

  // Notify all remaining participants
  const recipients = trip.participants;

  return sendNotificationToUsers(
    recipients.map(r => r.id),
    {
      title: await getLocalizedMessage(recipients[0]?.id, 'notification_participant_left_title'),
      body: await getLocalizedMessage(
        recipients[0]?.id,
        'notification_participant_left_body',
        {
          name: participant.name,
          trip: trip.name
        }
      ),
      data: {
        type: 'participant_left',
        tripId: tripId
      }
    }
  );
}

/**
 * Send notification when participant claims their account
 */
async function handleParticipantClaimed(participant, trip, tripId) {
  console.log(`Handling participant claimed: ${participant.name}`);

  // Find who created this unclaimed participant (from the participant ID pattern)
  // unclaimed_{creatorId}_{random}_{name}
  const creatorId = participant.id.split('_')[1];

  if (!creatorId) {
    console.warn('Could not determine creator of unclaimed participant');
    return;
  }

  // Notify the creator
  return sendNotificationToUsers(
    [creatorId],
    {
      title: await getLocalizedMessage(creatorId, 'notification_participant_claimed_title'),
      body: await getLocalizedMessage(
        creatorId,
        'notification_participant_claimed_body',
        {
          name: participant.name,
          trip: trip.name
        }
      ),
      data: {
        type: 'participant_claimed',
        tripId: tripId
      }
    }
  );
}

/**
 * Send notification when user is added to a trip
 */
async function handleParticipantAdded(participant, trip, tripId) {
  console.log(`Handling participant added: ${participant.name}`);

  // Notify the newly added participant
  return sendNotificationToUsers(
    [participant.id],
    {
      title: await getLocalizedMessage(participant.id, 'notification_added_to_trip_title'),
      body: await getLocalizedMessage(
        participant.id,
        'notification_added_to_trip_body',
        {
          trip: trip.name
        }
      ),
      data: {
        type: 'added_to_trip',
        tripId: tripId
      }
    }
  );
}

module.exports = {
  handleParticipantJoined,
  handleParticipantLeft,
  handleParticipantClaimed,
  handleParticipantAdded
};
```

---

## File: `notifications/balanceNotifications.js`

```javascript
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
```

---

## File: `utils/notificationHelpers.js`

```javascript
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
```

---

## File: `utils/localization.js`

```javascript
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
```

---

## File: `.gitignore`

```
# Dependency directories
node_modules/

# Firebase
.firebase/
firebase-debug.log
firestore-debug.log
ui-debug.log

# Logs
*.log
npm-debug.log*

# Environment variables
.env
.env.local
```

---

## Deployment

```bash
# From the functions directory
cd functions

# Install dependencies (if not done during init)
npm install

# Test locally with emulator (optional)
firebase emulators:start --only functions

# Deploy to Firebase
firebase deploy --only functions

# View logs
firebase functions:log
```

---

## Testing Cloud Functions

```bash
# Test in emulator
firebase emulators:start --only functions,firestore

# Make a test change to a trip document in Firestore
# Watch the function logs to see if it triggers

# View production logs
firebase functions:log --only onTripChanged
```

---

## Monitoring

After deployment, monitor your functions:

1. **Firebase Console → Functions**
   - View invocation count
   - View error rate
   - View execution time

2. **Firebase Console → Cloud Messaging**
   - View notification delivery rate
   - View notification open rate

3. **Command Line Logs**
   ```bash
   firebase functions:log --only onTripChanged --limit 50
   ```

---

## Troubleshooting

### Function not triggering
- Check Firebase Console → Functions → Logs
- Verify function deployed: `firebase functions:list`
- Check Firestore document path matches exactly: `trips/{tripId}`

### Notifications not sending
- Check FCM tokens exist in Firestore `/users/{userId}/fcmToken`
- Verify APNs key uploaded in Firebase Console
- Check function logs for errors
- Verify user has `notificationsEnabled: true`

### Wrong language
- Check user's `language` field in Firestore
- Verify localization strings in `utils/localization.js`

---

## Cost Estimate

Firebase Free Tier (Spark Plan):
- Cloud Functions: 125K invocations/month FREE
- Cloud Messaging: Unlimited FREE

For a small app with ~100 active users:
- Expected monthly invocations: ~5,000
- **Cost: $0/month (well within free tier)**

---

## Next Steps

1. Copy all code files above into `functions/` directory
2. Run `npm install` in functions directory
3. Deploy: `firebase deploy --only functions`
4. Test with Firestore changes
5. Monitor logs: `firebase functions:log`

---

**Note for Next Claude Session:**

If Firebase MCP is available, you can deploy these functions directly using:
- `mcp__firebase__deploy_function` (if available)
- Or manually copy these files and deploy via CLI

The iOS app is waiting for these Cloud Functions to be deployed before notifications will work end-to-end.
