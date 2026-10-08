import { memo } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text } from 'react-native';

import { colors, fontSize, minTarget, spacing } from './tokens';

type Props = {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  busy?: boolean;
  variant?: 'primary' | 'secondary';
};

export const TrikoButton = memo(function TrikoButton({
  label,
  onPress,
  disabled = false,
  busy = false,
  variant = 'primary',
}: Props) {
  const inactive = disabled || busy;
  const primary = variant === 'primary';
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: inactive, busy }}
      onPress={onPress}
      disabled={inactive}
      style={[styles.base, primary ? styles.primary : styles.secondary, inactive && styles.inactive]}
    >
      {busy ? (
        <ActivityIndicator color={primary ? colors.onPrimary : colors.text} />
      ) : (
        <Text style={[styles.label, primary ? styles.primaryLabel : styles.secondaryLabel]}>{label}</Text>
      )}
    </Pressable>
  );
});

const styles = StyleSheet.create({
  base: {
    minHeight: minTarget,
    borderRadius: 8,
    paddingHorizontal: spacing.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primary: { backgroundColor: colors.primary },
  secondary: { backgroundColor: colors.background, borderWidth: 2, borderColor: colors.text },
  inactive: { opacity: 0.4 },
  label: { fontSize: fontSize.md, fontWeight: '800' },
  primaryLabel: { color: colors.onPrimary },
  secondaryLabel: { color: colors.text },
});
