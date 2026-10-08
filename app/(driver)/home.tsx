import { useCallback, useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { TrikoBigNumber } from '../../src/design-system/TrikoBigNumber';
import { TrikoButton } from '../../src/design-system/TrikoButton';
import { TrikoOfflineBanner } from '../../src/design-system/TrikoOfflineBanner';
import { TrikoStatusBadge } from '../../src/design-system/TrikoStatusBadge';
import type { BadgeTone } from '../../src/design-system/TrikoStatusBadge';
import { colors, fontSize, spacing } from '../../src/design-system/tokens';
import { logout, useSessionStore } from '../../src/features/auth/session.store';
import { useDriverStatusStore, useDriverStatusSync } from '../../src/features/driver/status.store';
import { homeView } from '../../src/features/driver/status.types';
import { useTricycleNumber } from '../../src/features/driver/tricycle';
import type { HomeView, MyQueueStatus } from '../../src/features/driver/status.types';
import { formatTime, t } from '../../src/i18n';
import type { CopyKey } from '../../src/i18n';
import { useIsOnline } from '../../src/lib/connectivity';

function bigNumberProps(view: HomeView): { value: string; caption?: string } {
  switch (view.kind) {
    case 'next':
      return { value: t('home.nextInLine') };
    case 'waiting':
      return { value: String(view.position), caption: t('home.ahead', { count: view.ahead }) };
    case 'active':
      return { value: view.slot === null ? t('status.active') : t('home.slot', { slot: view.slot }) };
    case 'reserved':
      return { value: view.priority === null ? t('status.reserved') : t('home.reservedRank', { rank: view.priority }) };
    case 'suspended':
      return { value: t('status.suspended') };
    case 'notInQueue':
      return { value: t('home.notInQueue') };
    case 'unknown':
      return { value: '—' };
  }
}

function badge(status: MyQueueStatus | null): { tone: BadgeTone; key: CopyKey } {
  const entryStatus = status?.entry?.status;
  return entryStatus ? { tone: entryStatus, key: `status.${entryStatus}` } : { tone: 'none', key: 'status.none' };
}

export default function DriverHomeScreen() {
  const userId = useSessionStore((s) => s.session?.user.id ?? '');
  const driverCode = useSessionStore((s) => s.driverCode);
  const status = useDriverStatusStore((s) => s.status);
  const lastSyncedAt = useDriverStatusStore((s) => s.lastSyncedAt);
  const syncFailed = useDriverStatusStore((s) => s.syncFailed);
  const isOnline = useIsOnline();
  const tricycleNumber = useTricycleNumber(userId);
  const [loggingOut, setLoggingOut] = useState(false);

  useDriverStatusSync(userId);

  // Logout can take up to a few seconds offline (session.store.ts); block a second tap.
  const onLogout = useCallback(() => {
    setLoggingOut(true);
    void logout();
  }, []);

  const big = useMemo(() => (status ? bigNumberProps(homeView(status)) : { value: '—' }), [status]);
  const { tone, key } = badge(status);
  const updated = lastSyncedAt ? t('common.lastUpdated', { time: formatTime(lastSyncedAt) }) : t('common.neverUpdated');

  return (
    <SafeAreaView style={styles.safe}>
      {!isOnline ? <TrikoOfflineBanner title={t('common.offline')} detail={updated} /> : null}
      <View style={styles.header}>
        <View>
          <Text style={styles.headerText}>{driverCode ?? t('app.name')}</Text>
          {tricycleNumber ? <Text style={styles.subText}>{tricycleNumber}</Text> : null}
        </View>
        {status?.route ? <Text style={styles.headerText}>{status.route.name}</Text> : null}
      </View>

      <View style={styles.main}>
        <TrikoBigNumber value={big.value} caption={big.caption} />
        <TrikoStatusBadge tone={tone} label={t(key)} />
        {status?.route ? (
          <Text style={styles.queueState}>
            {status.route.queueStatus === 'open' ? `🟢 ${t('home.queueOpen')}` : `🔴 ${t('home.queueClosed')}`}
          </Text>
        ) : null}
      </View>

      <View style={styles.footer}>
        {isOnline && syncFailed ? <Text style={styles.updated}>{t('common.syncFailed')}</Text> : null}
        {isOnline ? <Text style={styles.updated}>{updated}</Text> : null}
        <TrikoButton label={t('home.logout')} onPress={onLogout} variant="secondary" busy={loggingOut} />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  headerText: { fontSize: fontSize.md, fontWeight: '800', color: colors.text },
  subText: { fontSize: fontSize.sm, fontWeight: '700', color: colors.muted },
  main: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: spacing.lg, paddingHorizontal: spacing.lg },
  queueState: { fontSize: fontSize.md, fontWeight: '700', color: colors.text },
  footer: { padding: spacing.lg, gap: spacing.md },
  updated: { fontSize: fontSize.sm, color: colors.muted, textAlign: 'center' },
});
