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
