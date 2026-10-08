import { memo } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, fontSize, spacing } from './tokens';

// "⚠ OFFLINE" + when the shown data was last confirmed by the server (CLAUDE.md offline rule).
type Props = { title: string; detail?: string };

export const TrikoOfflineBanner = memo(function TrikoOfflineBanner({ title, detail }: Props) {
  return (
    <View style={styles.banner} accessibilityRole="alert">
      <Text style={styles.title}>{title}</Text>
      {detail ? <Text style={styles.detail}>{detail}</Text> : null}
    </View>
  );
});

const styles = StyleSheet.create({
  banner: {
    backgroundColor: colors.warningBg,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    alignItems: 'center',
  },
  title: { fontSize: fontSize.md, fontWeight: '900', color: colors.warningText },
  detail: { fontSize: fontSize.sm, color: colors.warningText },
});
