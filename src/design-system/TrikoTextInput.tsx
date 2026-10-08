import { memo } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import type { TextInputProps } from 'react-native';

import { colors, fontSize, minTarget, spacing } from './tokens';

type Props = Pick<
  TextInputProps,
  'value' | 'onChangeText' | 'placeholder' | 'keyboardType' | 'secureTextEntry' | 'maxLength' | 'autoCapitalize'
  | 'onSubmitEditing' | 'returnKeyType' | 'editable'
> & { label: string };

export const TrikoTextInput = memo(function TrikoTextInput({ label, ...input }: Props) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        {...input}
        accessibilityLabel={label}
        autoCorrect={false}
        placeholderTextColor={colors.muted}
        style={styles.input}
      />
    </View>
  );
});

const styles = StyleSheet.create({
  field: { gap: spacing.xs },
  label: { fontSize: fontSize.sm, fontWeight: '700', color: colors.text },
  input: {
    minHeight: minTarget,
    borderWidth: 2,
    borderColor: colors.border,
    borderRadius: 8,
    paddingHorizontal: spacing.md,
    fontSize: fontSize.lg,
    fontWeight: '700',
    color: colors.text,
    letterSpacing: 2,
  },
});
