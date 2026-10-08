import { Stack } from 'expo-router';

// Driver tabs (QUEUE, ALERTS) come with later milestones; HOME only for M5.
export default function DriverLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
