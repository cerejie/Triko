// Shape of public.get_my_queue_status() (0005). Every number here is server-computed
// (queue-rules §3); the client only parses and displays it.

export type EntryStatus = 'waiting' | 'active' | 'reserved' | 'priority' | 'suspended';

export type MyQueueEntry = {
  entryId: string;
  status: EntryStatus;
  waitingPosition: number | null;
  waitingAhead: number | null;
  reservationPriority: number | null;
  activeSlot: number | null;
};

export type MyQueueStatus = {
  route: { id: string; name: string; queueStatus: 'open' | 'closed' } | null;
  queueVersion: number | null;
  entry: MyQueueEntry | null;
};

// What the driver home shows (queue-rules §13, decided 2026-10-08: waiting_position, NEXT IN LINE at 1).
export type HomeView =
  | { kind: 'next' }
  | { kind: 'waiting'; position: number; ahead: number }
  | { kind: 'active'; slot: number | null }
  | { kind: 'reserved'; priority: number | null }
  | { kind: 'suspended' }
  | { kind: 'notInQueue' }
  // Server data without a position for a waiting entry: show a dash, never guess one.
  | { kind: 'unknown' };

const ENTRY_STATUSES: readonly EntryStatus[] = ['waiting', 'active', 'reserved', 'priority', 'suspended'];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function numOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function parseEntry(value: unknown): MyQueueEntry | null {
  if (!isRecord(value) || typeof value.entry_id !== 'string') return null;
  const status = ENTRY_STATUSES.find((s) => s === value.status);
  if (!status) return null;
  return {
    entryId: value.entry_id,
    status,
    waitingPosition: numOrNull(value.waiting_position),
    waitingAhead: numOrNull(value.waiting_ahead),
    reservationPriority: numOrNull(value.reservation_priority),
    activeSlot: numOrNull(value.active_slot),
  };
}

function parseRoute(value: unknown): MyQueueStatus['route'] {
  if (!isRecord(value) || typeof value.id !== 'string' || typeof value.name !== 'string') return null;
  return { id: value.id, name: value.name, queueStatus: value.queue_status === 'open' ? 'open' : 'closed' };
}

// Accepts the raw RPC jsonb (or a cached copy of it). Returns null if it is not that shape.
export function parseMyQueueStatus(value: unknown): MyQueueStatus | null {
  if (!isRecord(value)) return null;
  return {
    route: parseRoute(value.route),
    queueVersion: numOrNull(value.queue_version),
    entry: parseEntry(value.entry),
  };
}

export function homeView(status: MyQueueStatus): HomeView {
  const entry = status.entry;
  if (!entry) return { kind: 'notInQueue' };
  switch (entry.status) {
    case 'active':
      return { kind: 'active', slot: entry.activeSlot };
    case 'reserved':
      return { kind: 'reserved', priority: entry.reservationPriority };
    case 'suspended':
      return { kind: 'suspended' };
    case 'waiting':
    case 'priority':
      if (entry.waitingPosition === 1) return { kind: 'next' };
      if (entry.waitingPosition !== null) {
        return { kind: 'waiting', position: entry.waitingPosition, ahead: entry.waitingAhead ?? 0 };
      }
      return { kind: 'unknown' };
  }
}
