// Uniform random 6-digit PIN (rejection sampling avoids modulo bias).
export function generatePin(): string {
  const limit = Math.floor(0x1_0000_0000 / 1_000_000) * 1_000_000;
  const buffer = new Uint32Array(1);
  for (;;) {
    crypto.getRandomValues(buffer);
    const value = buffer[0];
    if (value < limit) return String(value % 1_000_000).padStart(6, '0');
  }
}

export function isPin(value: string): boolean {
  return /^[0-9]{6}$/.test(value);
}
