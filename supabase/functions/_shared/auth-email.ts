import { authEmailDomain } from './env.ts';

// Driver Code format, same as drivers.driver_code (0001_core.sql).
const DRIVER_CODE = /^[A-Z]{2,5}-[0-9]{1,6}$/;

export function normalizeDriverCode(raw: string): string | null {
  const code = raw.trim().toUpperCase();
  return DRIVER_CODE.test(code) ? code : null;
}

// DRV-001 -> drv001@<AUTH_EMAIL_DOMAIN> (queue-rules §12). Drivers never see it.
export function authEmailFor(driverCode: string): string {
  return `${driverCode.toLowerCase().replace(/-/g, '')}@${authEmailDomain()}`;
}
