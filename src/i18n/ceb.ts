import type { CopyKey } from './en';

// Cebuano (primary). Missing keys fall back to English.
export const ceb: Partial<Record<CopyKey, string>> = {
  'common.lastUpdated': 'Na-update {time}',
  'common.neverUpdated': 'Wala pa ma-update',
  'common.syncFailed': 'Dili ma-update. Ang katapusang na-save ang gipakita.',

  'login.driverCode': 'Code sa Drayber',
  'login.pin': 'PIN (6 ka numero)',
  'login.submit': 'SULOD',
  'login.offline': 'Walay internet. Konek una aron makasulod.',
  'login.error.LOGIN_FAILED': 'Sayop ang code o PIN.',
  'login.error.LOGIN_LOCKED': 'Daghan na kaayo nga sulay. Hulat {minutes} ka minuto.',
  'login.error.INVALID_INPUT': 'Isulat ang imong code ug 6 ka numero nga PIN.',
  'login.error.UNAVAILABLE': 'Dili makasulod karon. Sulayi pag-usab.',

  'home.nextInLine': 'SUNOD NA KA',
  'home.ahead': '{count} SA UNAHAN',
  'home.reservedRank': 'RESERBADO #{rank}',
  'home.notInQueue': 'WALA SA PILA',
  'home.queueOpen': 'Abli ang pila',
  'home.queueClosed': 'Sirado ang pila',
  'home.logout': 'GAWAS',

  'status.waiting': 'NAGHULAT',
  'status.priority': 'PRAYORIDAD',
  'status.active': 'AKTIBO',
  'status.reserved': 'RESERBADO',
  'status.suspended': 'GI-SUSPEND',
  'status.none': 'WALA SA PILA',
};
