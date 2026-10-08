// Shared visual tokens. High contrast, large targets for outdoor use on low-end Android.
export const colors = {
  background: '#FFFFFF',
  text: '#111111',
  muted: '#555555',
  border: '#BBBBBB',
  primary: '#111111',
  onPrimary: '#FFFFFF',
  disabled: '#BBBBBB',
  danger: '#B00020',
  warningBg: '#FFE08A',
  warningText: '#3D2B00',
} as const;

export const spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 40 } as const;

export const fontSize = { sm: 16, md: 20, lg: 28, xl: 40, huge: 120 } as const;

// Minimum touch target (dp).
export const minTarget = 56;
