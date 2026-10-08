import { Redirect } from 'expo-router';

import { useSessionStore } from '../src/features/auth/session.store';

export default function Index() {
  const signedIn = useSessionStore((s) => s.session !== null);
  return <Redirect href={signedIn ? '/home' : '/login'} />;
}
