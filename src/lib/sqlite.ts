import * as SQLite from 'expo-sqlite';

// Local cache only — never the queue (CLAUDE.md "The one rule"). Server state always replaces a row.

export type QueueSnapshotRow = {
  payload: string;
  queueVersion: number | null;
  lastSyncedAt: string;
};

const SCHEMA_VERSION = 1;

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;

async function open(): Promise<SQLite.SQLiteDatabase> {
  const db = await SQLite.openDatabaseAsync('triko.db');
  const row = await db.getFirstAsync<{ user_version: number }>('pragma user_version');
  if ((row?.user_version ?? 0) < SCHEMA_VERSION) {
    await db.execAsync(`
      create table if not exists local_queue_snapshot (
        user_id        text primary key not null,
        payload        text not null,
        queue_version  integer,
        last_synced_at text not null
      );
      pragma user_version = ${SCHEMA_VERSION};
    `);
  }
  return db;
}

function db(): Promise<SQLite.SQLiteDatabase> {
  dbPromise ??= open();
  return dbPromise;
}

export async function readQueueSnapshot(userId: string): Promise<QueueSnapshotRow | null> {
  const row = await (await db()).getFirstAsync<{
    payload: string;
    queue_version: number | null;
    last_synced_at: string;
  }>('select payload, queue_version, last_synced_at from local_queue_snapshot where user_id = ?', userId);
  return row ? { payload: row.payload, queueVersion: row.queue_version, lastSyncedAt: row.last_synced_at } : null;
}

export async function writeQueueSnapshot(userId: string, snapshot: QueueSnapshotRow): Promise<void> {
  await (await db()).runAsync(
    'insert or replace into local_queue_snapshot (user_id, payload, queue_version, last_synced_at) values (?, ?, ?, ?)',
    userId,
    snapshot.payload,
    snapshot.queueVersion,
    snapshot.lastSyncedAt,
  );
}

export async function clearQueueSnapshots(): Promise<void> {
  await (await db()).runAsync('delete from local_queue_snapshot');
}
