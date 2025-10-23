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
