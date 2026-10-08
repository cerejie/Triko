import { memo } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, fontSize, spacing } from './tokens';

// The driver's one big thing on screen: a number, or a short phrase like NEXT IN LINE.
type Props = { value: string; caption?: string; accessibilityLabel?: string };

export const TrikoBigNumber = memo(function TrikoBigNumber({ value, caption, accessibilityLabel }: Props) {
  const isNumber = /^\d+$/.test(value);
  return (
    <View style={styles.wrap} accessible accessibilityLabel={accessibilityLabel ?? [value, caption].join(' ')}>
      <Text
        style={[styles.value, !isNumber && styles.phrase]}
        adjustsFontSizeToFit
        numberOfLines={1}
        minimumFontScale={0.5}
      >
        {value}
      </Text>
      {caption ? <Text style={styles.caption}>{caption}</Text> : null}
    </View>
  );
});

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', gap: spacing.sm },
  value: { fontSize: fontSize.huge, fontWeight: '900', color: colors.text, includeFontPadding: false },
  phrase: { fontSize: fontSize.xl * 1.4 },
  caption: { fontSize: fontSize.lg, fontWeight: '800', color: colors.text },
});
