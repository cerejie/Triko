import { useNetInfo } from '@react-native-community/netinfo';

// Event-driven (NetInfo listener), no polling. Unknown reachability counts as online
// so a slow first probe never disables the app; a failed request still shows as not updated.
export function useIsOnline(): boolean {
  const { isConnected, isInternetReachable } = useNetInfo();
  return isConnected !== false && isInternetReachable !== false;
}
