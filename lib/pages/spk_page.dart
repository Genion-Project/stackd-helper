import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SpkPage extends StatefulWidget {
  final Map<String, dynamic>? notionData;

  const SpkPage({super.key, this.notionData});

  @override
  State<SpkPage> createState() => _SpkPageState();
}

class _SpkPageState extends State<SpkPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<dynamic> _databases = [];
  Map<String, dynamic>? _selectedDatabase;
  List<dynamic> _databaseRows = [];
  bool _isLoadingTable = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  DateTime? _filterDate;

  // Professional monochromatic palette (Linear/VS Code style)
  static const Color primaryColor = Color(0xFF0F172A); // Slate 900
  static const Color primaryLight = Color(0xFF334155); // Slate 700
  static const Color primaryDark = Color(0xFF020617); // Slate 950
  static const Color secondaryColor = Color(0xFF64748B); // Slate 500
  static const Color accentColor = Color(0xFF0F172A); 
  static const Color backgroundColor = Color(0xFFF8FAFC); // Very light slate
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic);
    _animationController.forward();
    _fetchDatabases();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _token => widget.notionData?['access_token'] ?? '';

  Future<void> _fetchDatabases() async {
    if (_token.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://api.notion.com/v1/search'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'filter': {'value': 'database', 'property': 'object'}}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _databases = data['results'] ?? []);
      } else {
        debugPrint('Error fetching databases: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDatabaseContent(Map<String, dynamic> database) async {
    _animationController.reverse().then((_) {
      setState(() {
        _selectedDatabase = database;
        _isLoadingTable = true;
        _databaseRows = [];
      });
      _animationController.forward();
    });

    try {
      final properties = database['properties'] as Map<String, dynamic>? ?? {};
      String? peopleProperty;
      
      for (final key in properties.keys) {
        if (properties[key]['type'] == 'people') {
          peopleProperty = key;
          if (key.toLowerCase().contains('pic') || key.toLowerCase().contains('assign') || key.toLowerCase().contains('tugas')) {
            break;
          }
        }
      }

      Map<String, dynamic> body = {};
      final userId = widget.notionData?['owner']?['user']?['id'];
      
      if (userId != null && peopleProperty != null) {
        body['filter'] = {
          "property": peopleProperty,
          "people": {"contains": userId}
        };
      }

      final response = await http.post(
        Uri.parse('https://api.notion.com/v1/databases/${database['id']}/query'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: body.isNotEmpty ? jsonEncode(body) : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _databaseRows = data['results'] ?? []);
      } else {
        debugPrint('Error fetching database rows: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTable = false);
    }
  }

  String _getPropertyPlainText(dynamic property) {
    if (property == null) return '-';
    final type = property['type'];
    if (type == 'title' || type == 'rich_text') {
      final arr = property[type] as List?;
      if (arr == null || arr.isEmpty) return '-';
      return arr.map((e) => e['plain_text']).join('');
    } else if (type == 'number') {
      return property['number']?.toString() ?? '-';
    } else if (type == 'url') {
      return property['url'] ?? '-';
    } else if (type == 'email') {
      return property['email'] ?? '-';
    } else if (type == 'phone_number') {
      return property['phone_number'] ?? '-';
    } else if (type == 'formula') {
      final formulaType = property['formula']?['type'];
      return property['formula']?[formulaType]?.toString() ?? '-';
    } else if (type == 'relation') {
      final arr = property['relation'] as List?;
      return '${arr?.length ?? 0} related';
    } else if (type == 'rollup') {
      final rollupType = property['rollup']?['type'];
      if (rollupType == 'array') {
        return '${(property['rollup']?['array'] as List?)?.length ?? 0} rollups';
      }
      return property['rollup']?[rollupType]?.toString() ?? '-';
    }
    return '-';
  }

  Color _getNotionColor(String color, {required bool isBackground}) {
    switch (color) {
      case 'gray': return isBackground ? const Color(0xFFF1F5F9) : const Color(0xFF475569);
      case 'brown': return isBackground ? const Color(0xFFFFF7ED) : const Color(0xFF92400E);
      case 'orange': return isBackground ? const Color(0xFFFFEDD5) : const Color(0xFFC2410C);
      case 'yellow': return isBackground ? const Color(0xFFFEF9C3) : const Color(0xFFA16207);
      case 'green': return isBackground ? const Color(0xFFDCFCE7) : const Color(0xFF15803D);
      case 'blue': return isBackground ? const Color(0xFFDBEAFE) : const Color(0xFF1D4ED8);
      case 'purple': return isBackground ? const Color(0xFFF3E8FF) : const Color(0xFF7E22CE);
      case 'pink': return isBackground ? const Color(0xFFFCE7F3) : const Color(0xFFBE185D);
      case 'red': return isBackground ? const Color(0xFFFEE2E2) : const Color(0xFFB91C1C);
      default: return isBackground ? const Color(0xFFF8FAFC) : const Color(0xFF64748B);
    }
  }

  Widget _getPropertyWidget(dynamic property) {
    if (property == null) return const Text('-', style: TextStyle(color: textTertiary));
    final type = property['type'];
    
    if (type == 'title' || type == 'rich_text') {
      final text = _getPropertyPlainText(property);
      return Text(
        text,
        style: TextStyle(
          color: textPrimary,
          fontWeight: type == 'title' ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
          height: 1.4,
        ),
      );
    } else if (type == 'select' || type == 'status') {
      final name = property[type]?['name'] ?? '-';
      final colorStr = property[type]?['color'] ?? 'default';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getNotionColor(colorStr, isBackground: true),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withOpacity(0.3)),
        ),
        child: Text(
          name,
          style: TextStyle(color: _getNotionColor(colorStr, isBackground: false), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (type == 'multi_select') {
      final arr = property['multi_select'] as List?;
      if (arr == null || arr.isEmpty) return const Text('-', style: TextStyle(color: textTertiary));
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: arr.map((e) {
          final colorStr = e['color'] ?? 'default';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getNotionColor(colorStr, isBackground: true),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor.withOpacity(0.3)),
            ),
            child: Text(e['name'] ?? '', style: TextStyle(color: _getNotionColor(colorStr, isBackground: false), fontSize: 11, fontWeight: FontWeight.w500)),
          );
        }).toList(),
      );
    } else if (type == 'date') {
      final start = property['date']?['start'] ?? '-';
      if (start == '-') return const Text('-', style: TextStyle(color: textTertiary));
      final date = DateTime.tryParse(start);
      final formatted = date != null ? '${date.day}/${date.month}/${date.year}' : start;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded, size: 14, color: textTertiary),
            const SizedBox(width: 6),
            Text(formatted, style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    } else if (type == 'checkbox') {
      final checked = property['checkbox'] == true;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: checked ? primaryColor.withOpacity(0.1) : backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: checked ? primaryColor : borderColor, width: 1.5),
        ),
        child: Icon(
          checked ? Icons.check_rounded : null,
          color: checked ? primaryColor : null,
          size: 18,
        ),
      );
    } else if (type == 'people') {
      final arr = property['people'] as List?;
      if (arr == null || arr.isEmpty) return const Text('-', style: TextStyle(color: textTertiary));
      
      if (arr.length == 1) {
        final person = arr.first;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Text(
                (person['name'] ?? '?')[0].toUpperCase(),
                style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(person['name'] ?? '?', style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
      }
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, size: 16, color: textTertiary),
          const SizedBox(width: 6),
          Text(
            '${arr.length} people',
            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else if (type == 'url') {
      final url = property['url'] ?? '';
      return url.isEmpty 
        ? const Text('-', style: TextStyle(color: textTertiary))
        : InkWell(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 14, color: primaryColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Link',
                      style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
    } else if (type == 'number') {
      final number = property['number'];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          number?.toString() ?? '-',
          style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getPropertyPlainText(property),
        style: TextStyle(color: textSecondary, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getDatabaseTitle(Map<String, dynamic> db) {
    final titleArr = db['title'] as List?;
    if (titleArr != null && titleArr.isNotEmpty) {
      return titleArr.map((e) => e['plain_text']).join('');
    }
    return 'Untitled Database';
  }

  String _getRowTitle(Map<String, dynamic> row) {
    final props = row['properties'] as Map<String, dynamic>? ?? {};
    for (final key in props.keys) {
      if (props[key]?['type'] == 'title') {
        return _getPropertyPlainText(props[key]);
      }
    }
    return 'Untitled';
  }

  void _showSubmitDialog(Map<String, dynamic> row) {
    final TextEditingController urlController = TextEditingController();
    bool isSubmitting = false;
    final taskTitle = _getRowTitle(row);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Submit Result", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text(taskTitle, style: const TextStyle(fontSize: 13, color: textTertiary), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close_rounded, size: 18, color: textTertiary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(height: 1, color: borderColor),
                    const SizedBox(height: 24),
                    const Text("Result Link", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urlController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "https://drive.google.com/...",
                        hintStyle: TextStyle(color: textTertiary.withOpacity(0.6), fontSize: 14),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Icon(Icons.link_rounded, size: 18, color: textTertiary),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: textTertiary),
                        const SizedBox(width: 6),
                        Text("Isi dengan link pengerjaan anda(Canva, Figma, Git, dll)", style: TextStyle(fontSize: 12, color: textTertiary)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              if (urlController.text.trim().isEmpty) return;
                              setDialogState(() => isSubmitting = true);
                              final now = DateTime.now().toIso8601String().split('T')[0];
                              try {
                                // NOTE: 'Result' is a rich_text in Notion, not a url type.
                                // And 'Submit' must exist in the database as a Date property, otherwise it causes a 400 error.
                                final Map<String, dynamic> updateProperties = {
                                  "Result": {
                                    "rich_text": [
                                      {
                                        "text": {
                                          "content": urlController.text.trim(),
                                          "link": {"url": urlController.text.trim()}
                                        }
                                      }
                                    ]
                                  }
                                };
                                
                                // Check if 'Submit' property actually exists in this database schema
                                // before adding it, to avoid 400 Bad Request
                                final schema = _selectedDatabase!['properties'] as Map<String, dynamic>?;
                                if (schema != null && schema.containsKey('Submit')) {
                                  updateProperties["Submit"] = {
                                    "date": {"start": now}
                                  };
                                }

                                final response = await http.patch(
                                  Uri.parse('https://api.notion.com/v1/pages/${row['id']}'),
                                  headers: {'Authorization': 'Bearer $_token', 'Notion-Version': '2022-06-28', 'Content-Type': 'application/json'},
                                  body: jsonEncode({"properties": updateProperties}),
                                );
                                if (response.statusCode == 200 && mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18), const SizedBox(width: 10), const Text('Result submitted successfully!')]),
                                    backgroundColor: successColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ));
                                  _fetchDatabaseContent(_selectedDatabase!);
                                } else {
                                  setDialogState(() => isSubmitting = false);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.statusCode}'), backgroundColor: errorColor));
                                }
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: errorColor));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.send_rounded, size: 16), const SizedBox(width: 8), const Text("Submit Result", style: TextStyle(fontWeight: FontWeight.w600))]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatabaseList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
              ),
            ),
            const SizedBox(height: 20),
            Text("Loading workspaces...", style: TextStyle(color: textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_databases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: surfaceColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(Icons.table_chart_outlined, size: 64, color: textTertiary),
            ),
            const SizedBox(height: 28),
            Text(
              "No databases found",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              "Make sure your integration has access to a database",
              style: TextStyle(fontSize: 15, color: textSecondary),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: primaryColor),
                  const SizedBox(width: 10),
                  Text("Check Notion integration settings", style: TextStyle(fontSize: 13, color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: _databases.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final db = _databases[index];
        final title = _getDatabaseTitle(db);
        final iconObj = db['icon'];
        String? emoji;
        if (iconObj != null && iconObj['type'] == 'emoji') emoji = iconObj['emoji'];
        final propCount = (db['properties'] as Map?)?.length ?? 0;

        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 40)),
          curve: Curves.easeOutCubic,
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _fetchDatabaseContent(db),
              borderRadius: BorderRadius.circular(6),
              hoverColor: primaryColor.withOpacity(0.02),
              splashColor: primaryColor.withOpacity(0.05),
              highlightColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: borderColor.withOpacity(0.5)),
                      ),
                      child: Center(child: Text(emoji ?? '📋', style: const TextStyle(fontSize: 14))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('$propCount properties', style: const TextStyle(fontSize: 12, color: textTertiary)),
                    const SizedBox(width: 24),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatabaseTable() {
    if (_isLoadingTable) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: surfaceColor, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.08), blurRadius: 24)],
              ),
              child: const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5)),
            ),
            const SizedBox(height: 16),
            const Text("Loading tasks...", style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_selectedDatabase == null) return const SizedBox();

    final dbTitle = _getDatabaseTitle(_selectedDatabase!);
    final properties = _selectedDatabase!['properties'] as Map<String, dynamic>? ?? {};
    final propertyKeys = properties.keys.toList();
    
    int getPropertyWeight(String key, String? type) {
      if (type == 'title') return 0;
      final keyLower = key.toLowerCase();
      if (keyLower.contains('job desc')) return 1;
      if (keyLower.contains('prioritas') || keyLower.contains('priority') || keyLower.contains('status')) return 2;
      if (keyLower.contains('mulai')) return 3;
      if (keyLower.contains('akhir') || keyLower.contains('deadline') || keyLower.contains('revisi')) return 4;
      if (keyLower.contains('pic') || type == 'people') return 5;
      if (type == 'date') return 6;
      if (type == 'select' || type == 'multi_select') return 7;
      if (type == 'rich_text' || type == 'url') return 8;
      return 10;
    }

    propertyKeys.sort((a, b) {
      final wA = getPropertyWeight(a, properties[a]?['type']);
      final wB = getPropertyWeight(b, properties[b]?['type']);
      if (wA != wB) return wA.compareTo(wB);
      return a.compareTo(b);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // — Breadcrumb & Title Bar —
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _animationController.reverse().then((_) {
                    setState(() => _selectedDatabase = null);
                    _animationController.forward();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.arrow_back_rounded, color: textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: borderColor),
              const SizedBox(width: 12),
              // Breadcrumb
              Text("Workspaces", style: TextStyle(fontSize: 13, color: textTertiary, fontWeight: FontWeight.w500)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_right_rounded, size: 16, color: textTertiary)),
              Expanded(
                child: Text(dbTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              // Refresh button
              Tooltip(
                message: 'Refresh data',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _fetchDatabaseContent(_selectedDatabase!),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.refresh_rounded, color: textSecondary, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // — Stats Bar —
        Row(
          children: [
            _buildStatChip(Icons.assignment_rounded, '${_databaseRows.length}', 'Tasks', primaryColor),
            const SizedBox(width: 10),
            _buildStatChip(Icons.view_column_rounded, '${propertyKeys.length}', 'Fields', primaryColor),
            const SizedBox(width: 10),
            _buildStatChip(Icons.person_rounded, 'My View', '', successColor),
            const SizedBox(width: 10),
            InkWell(
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _filterDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null) {
                  setState(() => _filterDate = selected);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _filterDate != null ? primaryColor.withOpacity(0.05) : backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _filterDate != null ? primaryColor.withOpacity(0.2) : borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: _filterDate != null ? primaryColor : textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _filterDate != null ? "${_filterDate!.day}/${_filterDate!.month}/${_filterDate!.year}" : "Filter Date",
                      style: TextStyle(fontSize: 12, color: _filterDate != null ? primaryColor : textSecondary, fontWeight: FontWeight.w600),
                    ),
                    if (_filterDate != null) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _filterDate = null),
                        child: const Icon(Icons.close_rounded, size: 14, color: textSecondary),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderColor)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: successColor),
                  const SizedBox(width: 6),
                  const Text("Synced with Notion", style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // — Table Container —
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _databaseRows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: textTertiary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text("No items assigned to you", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                          const SizedBox(height: 4),
                          const Text("You're all caught up.", style: TextStyle(fontSize: 14, color: textSecondary)),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Custom Header
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      border: Border(bottom: BorderSide(color: borderColor)),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 16),
                                        SizedBox(width: 32, child: Text('#', style: TextStyle(color: textTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
                                        ...propertyKeys.map((key) {
                                          return SizedBox(
                                            width: 180,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(_getIconForPropertyType(properties[key]?['type']), size: 12, color: textTertiary),
                                                const SizedBox(width: 6),
                                                Text(key.toUpperCase(), style: const TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(width: 120, child: Text('ACTION', style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
                                        const SizedBox(width: 16),
                                      ],
                                    ),
                                  ),
                                  // Custom Rows
                                  ...(() {
                                    List<dynamic> rowsToShow = _databaseRows;
                                    if (_filterDate != null) {
                                      final filterStr = _filterDate!.toIso8601String().split('T')[0];
                                      rowsToShow = rowsToShow.where((row) {
                                        final props = row['properties'] as Map<String, dynamic>? ?? {};
                                        bool match = false;
                                        // check 'Submit' or any date field for filter
                                        if (props['Submit'] != null && props['Submit']['date'] != null) {
                                          final d = props['Submit']['date']['start'];
                                          if (d != null && d.toString().startsWith(filterStr)) match = true;
                                        } else {
                                          // fallback check other dates
                                          for (final k in props.keys) {
                                            if (props[k]['type'] == 'date' && props[k]['date'] != null) {
                                              final d = props[k]['date']['start'];
                                              if (d != null && d.toString().startsWith(filterStr)) match = true;
                                            }
                                          }
                                        }
                                        return match;
                                      }).toList();
                                    }
                                    
                                    if (rowsToShow.isEmpty) {
                                      return [
                                        Container(
                                          padding: const EdgeInsets.all(32),
                                          alignment: Alignment.center,
                                          child: const Text("No tasks match the selected date.", style: TextStyle(color: textTertiary, fontSize: 13)),
                                        )
                                      ];
                                    }

                                    return rowsToShow.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final row = entry.value;
                                      final rowProperties = row['properties'] as Map<String, dynamic>? ?? {};
                                      
                                      bool isSubmitted = false;
                                      
                                      // Check if 'Submit' date is filled
                                      if (rowProperties['Submit'] != null && rowProperties['Submit']['date'] != null) {
                                        isSubmitted = true;
                                      } 
                                      // Check if 'Result' has actual text content
                                      else if (rowProperties['Result'] != null && rowProperties['Result']['rich_text'] != null) {
                                        final rt = rowProperties['Result']['rich_text'] as List;
                                        if (rt.isNotEmpty && rt[0]['text'] != null) {
                                          final content = rt[0]['text']['content']?.toString().trim() ?? '';
                                          if (content.isNotEmpty) isSubmitted = true;
                                        }
                                      } 
                                      // Check if 'Status QC' is 'Selesai'
                                      else if (rowProperties['Status QC'] != null && rowProperties['Status QC']['status'] != null && rowProperties['Status QC']['status']['name'] == 'Selesai') {
                                        isSubmitted = true;
                                      }

                                    
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {},
                                        hoverColor: primaryColor.withOpacity(0.02),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: borderColor.withOpacity(0.5))),
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 32, 
                                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, color: textTertiary, fontWeight: FontWeight.w500))
                                              ),
                                              ...propertyKeys.map((key) {
                                                return Container(
                                                  width: 180,
                                                  padding: const EdgeInsets.only(right: 16),
                                                  alignment: Alignment.centerLeft,
                                                  child: _getPropertyWidget(rowProperties[key]),
                                                );
                                              }),
                                              SizedBox(
                                                width: 120,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: isSubmitted 
                                                    ? Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: backgroundColor,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: borderColor),
                                                        ),
                                                        child: const Text("Submitted", style: TextStyle(fontSize: 11, color: textTertiary, fontWeight: FontWeight.w600)),
                                                      )
                                                    : InkWell(
                                                        onTap: () => _showSubmitDialog(row),
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: primaryColor,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text("Submit", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList();
                                })(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7), fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  IconData _getIconForPropertyType(String? type) {
    switch (type) {
      case 'title': return Icons.title_rounded;
      case 'rich_text': return Icons.text_fields_rounded;
      case 'number': return Icons.numbers_rounded;
      case 'select': return Icons.label_rounded;
      case 'multi_select': return Icons.style_rounded;
      case 'date': return Icons.calendar_today_rounded;
      case 'people': return Icons.people_rounded;
      case 'checkbox': return Icons.check_box_rounded;
      case 'url': return Icons.link_rounded;
      case 'email': return Icons.email_rounded;
      case 'phone_number': return Icons.phone_rounded;
      default: return Icons.circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notionData == null || widget.notionData!['access_token'] == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(56),
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, size: 56, color: errorColor),
              ),
              const SizedBox(height: 28),
              Text(
                "No Workspace Connected",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                "Please reconnect from the Login Screen",
                style: TextStyle(fontSize: 15, color: textSecondary),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: primaryColor),
                    const SizedBox(width: 10),
                    Text("Check your authentication", style: TextStyle(fontSize: 13, color: textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDatabase == null) ...[
              FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, primaryLight]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("SPK Dashboard", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5)),
                                  const SizedBox(height: 2),
                                  Text("Select a database to manage your tasks", style: TextStyle(fontSize: 14, color: textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_databases.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 16, color: primaryColor),
                            const SizedBox(width: 8),
                            Text('${_databases.length} databases', style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _selectedDatabase == null ? _buildDatabaseList() : _buildDatabaseTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
