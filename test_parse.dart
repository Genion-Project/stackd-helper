import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('debug_notion.json').readAsStringSync();
  final data = jsonDecode(file) as List;

  for (final row in data) {
    bool isSubmitted = false;
    // simulating the logic
    final result = row['result'] as List?;
    if (result != null && result.isNotEmpty) isSubmitted = true;
    
    print('Row ${row['id']}: isSubmitted=$isSubmitted');
  }
}
