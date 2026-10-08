import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';

import { startSessionSync, useSessionStore } from '../src/features/auth/session.store';

export default function RootLayout() {
  const ready = useSessionStore((s) => s.ready);
  const signedIn = useSessionStore((s) => s.session !== null);

  useEffect(() => {
    startSessionSync();
  }, []);

  // The stored session is a local read (no network), so this blank frame is brief.
  if (!ready) return null;

  return (
    <>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Protected guard={signedIn}>
          <Stack.Screen name="(driver)" />
        </Stack.Protected>
        <Stack.Protected guard={!signedIn}>
          <Stack.Screen name="(auth)" />
        </Stack.Protected>
      </Stack>
      <StatusBar style="dark" />
    </>
  );
}
