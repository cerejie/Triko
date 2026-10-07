import { StyleSheet, Text, View } from 'react-native';

// Placeholder until M4 adds auth routing into (driver) / (operator).
export default function Index() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>TRIKO</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#FFFFFF' },
  title: { fontSize: 40, fontWeight: '800', color: '#111111' },
});
