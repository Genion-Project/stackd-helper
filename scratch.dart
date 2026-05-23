import 'dart:convert';
import 'dart:io';

void main() async {
  final env = File('.env').readAsStringSync();
  final tokenLine = env.split('\n').firstWhere((l) => l.startsWith('NOTION_TOKEN='));
  final dbLine = env.split('\n').firstWhere((l) => l.startsWith('NOTION_DATABASE_ID='));
  
  final token = tokenLine.split('=')[1].trim();
  final db = dbLine.split('=')[1].trim();
  
  final req = await HttpClient().getUrl(Uri.parse('https://api.notion.com/v1/databases/$db'));
  req.headers.add('Authorization', 'Bearer $token');
  req.headers.add('Notion-Version', '2022-06-28');
  
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  
  final json = jsonDecode(body);
  final props = json['properties'] as Map<String, dynamic>?;
  
  if (props != null) {
    props.forEach((key, value) {
      print('$key: ${value['type']}');
    });
  } else {
    print(body);
  }
}
