// English fallback. Keys are the source of truth for copy; ceb.ts may leave any key out.
export const en = {
  'app.name': 'TRIKO',
  'common.offline': '⚠ OFFLINE',
  'common.lastUpdated': 'Updated {time}',
  'common.neverUpdated': 'Not updated yet',
  'common.syncFailed': 'Could not update. Showing last saved.',

  'login.driverCode': 'Driver Code',
  'login.driverCodePlaceholder': 'DRV-001',
  'login.pin': 'PIN (6 numbers)',
  'login.submit': 'LOG IN',
  'login.offline': 'No internet. Connect to log in.',
  'login.error.LOGIN_FAILED': 'Wrong code or PIN.',
  'login.error.LOGIN_LOCKED': 'Too many tries. Wait {minutes} min.',
  'login.error.INVALID_INPUT': 'Enter your code and 6-number PIN.',
  'login.error.UNAVAILABLE': 'Cannot log in right now. Try again.',

  'home.nextInLine': 'NEXT IN LINE',
  'home.ahead': '{count} AHEAD',
  'home.slot': 'SLOT {slot}',
  'home.reservedRank': 'RESERVED #{rank}',
  'home.notInQueue': 'NOT IN QUEUE',
  'home.queueOpen': 'Queue open',
  'home.queueClosed': 'Queue closed',
  'home.logout': 'LOG OUT',

  'status.waiting': 'WAITING',
  'status.priority': 'PRIORITY',
  'status.active': 'ACTIVE',
  'status.reserved': 'RESERVED',
  'status.suspended': 'SUSPENDED',
  'status.none': 'NOT IN QUEUE',
} as const;

export type CopyKey = keyof typeof en;
