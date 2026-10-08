import { ceb } from './ceb';
import { en } from './en';
import type { CopyKey } from './en';

export type { CopyKey };

// Cebuano first, English fallback. A language switch comes later; keep calls going through t().
export function t(key: CopyKey, params?: Record<string, string | number>): string {
  const template: string = ceb[key] ?? en[key];
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in params ? String(params[name]) : match,
  );
}

// Short local time for "last updated" (3:42 PM); adds the date when it is not today.
export function formatTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  const time = date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  if (date.toDateString() === new Date().toDateString()) return time;
  return `${date.toLocaleDateString([], { month: 'short', day: 'numeric' })} ${time}`;
}
