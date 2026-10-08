import { memo } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, fontSize, spacing } from './tokens';

export type BadgeTone = 'waiting' | 'priority' | 'active' | 'reserved' | 'suspended' | 'none';

// Icon + text always; colour is never the only signal (reference §4.4).
const ICONS: Record<BadgeTone, string> = {
  waiting: '🟡',
  priority: '⭐',
  active: '🟢',
  reserved: '🔵',
  suspended: '⏸',
  none: '⚪',
};

type Props = { tone: BadgeTone; label: string };

export const TrikoStatusBadge = memo(function TrikoStatusBadge({ tone, label }: Props) {
  return (
    <View style={styles.badge} accessible accessibilityLabel={label}>
      <Text style={styles.icon}>{ICONS[tone]}</Text>
      <Text style={styles.label}>{label}</Text>
    </View>
  );
});

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    borderWidth: 2,
    borderColor: colors.text,
    borderRadius: 999,
  },
  icon: { fontSize: fontSize.md },
  label: { fontSize: fontSize.md, fontWeight: '800', color: colors.text },
});
