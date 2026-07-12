const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const REGION = 'asia-south1';

/**
 * Send FCM notification to all tokens registered for a user.
 */
async function sendNotificationToUser(uid, title, body, data = {}) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    const tokens = userDoc.data()?.fcmTokens || [];

    if (!Array.isArray(tokens) || tokens.length === 0) {
      console.log(`No FCM tokens for user ${uid}`);
      return;
    }

    const messages = tokens.map((token) => ({
      token,
      notification: { title, body },
      data,
      android: {
        notification: {
          channelId: 'high_importance_channel',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            badge: 1,
            sound: 'default',
          },
        },
      },
    }));

    const response = await admin.messaging().sendEach(messages);
    console.log(`Sent notifications to ${uid}: ${response.successCount} success, ${response.failureCount} failure`);

    // Remove invalid tokens
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error;
        console.error(`FCM error for token ${tokens[idx]}:`, error.code, error.message);
        if (
          error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await admin.firestore().collection('users').doc(uid).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
      console.log(`Removed ${invalidTokens.length} invalid tokens for ${uid}`);
    }
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}

/**
 * Trigger: new chat message
 */
exports.onNewMessage = functions.region(REGION).firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const toUid = data.toUid;
    const fromName = data.fromName || 'Someone';

    if (!toUid) return;

    const title = fromName;
    const body = data.imageUrl ? 'Sent you an image' : (data.message || 'New message');
    await sendNotificationToUser(toUid, title, body, {
      type: 'chat',
      fromUid: data.fromUid || '',
      chatRoomId: data.chatRoomId || '',
    });
  });

/**
 * Trigger: new friend invitation
 */
exports.onNewInvitation = functions.region(REGION).firestore
  .document('invitations/{invitationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const toUid = data.toUid;
    const fromName = data.fromName || 'Someone';

    if (!toUid) return;

    await sendNotificationToUser(toUid, 'New Friend Request', `${fromName} sent you a friend request`, {
      type: 'invitation',
      fromUid: data.fromUid || '',
      invitationId: context.params.invitationId,
    });
  });

/**
 * Trigger: new game request
 */
exports.onNewGameRequest = functions.region(REGION).firestore
  .document('gameRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const toUid = data.toUid;
    const fromName = data.fromName || 'Someone';

    if (!toUid) return;

    await sendNotificationToUser(toUid, 'Play Request', `${fromName} wants to play with you`, {
      type: 'gameRequest',
      fromUid: data.fromUid || '',
      requestId: context.params.requestId,
    });
  });
