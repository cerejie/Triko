import { useCallback, useState } from 'react';
import { KeyboardAvoidingView, Platform, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { TrikoButton } from '../../src/design-system/TrikoButton';
import { TrikoOfflineBanner } from '../../src/design-system/TrikoOfflineBanner';
import { TrikoTextInput } from '../../src/design-system/TrikoTextInput';
import { colors, fontSize, spacing } from '../../src/design-system/tokens';
import { loginDriver } from '../../src/features/auth/login';
import type { LoginResult } from '../../src/features/auth/login';
import { t } from '../../src/i18n';
import { useIsOnline } from '../../src/lib/connectivity';

function errorCopy(result: Exclude<LoginResult, { ok: true }>): string {
  if (result.error === 'LOGIN_LOCKED') {
    return t('login.error.LOGIN_LOCKED', { minutes: Math.max(1, Math.ceil(result.retryAfterSeconds / 60)) });
  }
  return t(`login.error.${result.error}`);
}

export default function LoginScreen() {
  const isOnline = useIsOnline();
  const [driverCode, setDriverCode] = useState('');
  const [pin, setPin] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = isOnline && !busy && driverCode.trim().length > 0 && pin.length === 6;

  const submit = useCallback(async () => {
    if (!canSubmit) return;
    setBusy(true);
    setError(null);
    const result = await loginDriver(driverCode, pin);
    // On success the root layout swaps to the driver stack; nothing else to do here.
    if (!result.ok) {
      setError(errorCopy(result));
      setPin('');
      setBusy(false);
    }
  }, [canSubmit, driverCode, pin]);

  return (
    <SafeAreaView style={styles.safe}>
      {!isOnline ? <TrikoOfflineBanner title={t('common.offline')} detail={t('login.offline')} /> : null}
      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.content}>
          <Text style={styles.title}>{t('app.name')}</Text>
          <TrikoTextInput
            label={t('login.driverCode')}
            placeholder={t('login.driverCodePlaceholder')}
            value={driverCode}
            onChangeText={setDriverCode}
            autoCapitalize="characters"
            maxLength={12}
            returnKeyType="next"
            editable={!busy}
          />
          <TrikoTextInput
            label={t('login.pin')}
            value={pin}
            onChangeText={(text) => setPin(text.replace(/\D/g, ''))}
            keyboardType="number-pad"
            secureTextEntry
            maxLength={6}
            returnKeyType="done"
            onSubmitEditing={submit}
            editable={!busy}
          />
          {error ? (
            <Text style={styles.error} accessibilityRole="alert">
              {error}
            </Text>
          ) : null}
          <TrikoButton label={t('login.submit')} onPress={submit} disabled={!canSubmit} busy={busy} />
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  flex: { flex: 1 },
  content: { flex: 1, justifyContent: 'center', padding: spacing.lg, gap: spacing.lg },
  title: { fontSize: fontSize.xl, fontWeight: '900', color: colors.text, textAlign: 'center' },
  error: { fontSize: fontSize.md, fontWeight: '700', color: colors.danger, textAlign: 'center' },
});
