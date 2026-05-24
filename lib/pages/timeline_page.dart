import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/ui_utils.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  List<NotionTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotionData();
  }

  Future<void> _fetchNotionData() async {
    setState(() => _isLoading = true);
    try {
      final token = dotenv.isInitialized ? dotenv.env['NOTION_TOKEN'] : null;
      final databaseId = dotenv.isInitialized ? dotenv.env['NOTION_DATABASE_ID'] : null;

      if (token == null || databaseId == null) {
        throw Exception("API keys not found in .env");
      }

      final url = Uri.parse('https://api.notion.com/v1/databases/$databaseId/query');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        setState(() {
          _tasks = results.map((json) => NotionTask.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) showCustomToast(context, "Error: $e", isError: true);
    }
  }

  Future<void> _openLink(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) showCustomToast(context, "Could not open link", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.view_timeline_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Team Timeline", style: TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text("View and track active assignments from Notion", style: TextStyle(color: const Color(0xFF64748B), fontSize: 14)),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Refresh Timeline',
                  child: InkWell(
                    onTap: () {
                      showCustomToast(context, "Syncing with Notion...", isError: false);
                      _fetchNotionData();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.refresh_rounded, color: Color(0xFF475569), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _tasks.isEmpty 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFFCBD5E1))),
                            const SizedBox(height: 16),
                            const Text("No tasks in timeline", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        )
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          
                          Color accentColor;
                          String displayStatus = task.status;
                          
                          if (task.statusQc.toLowerCase().contains("revisi")) {
                            accentColor = const Color(0xFFEF4444); // Red
                            displayStatus = "REVISI DIBUTUHKAN";
                          } else if (task.status.toLowerCase().contains("selesai")) {
                            accentColor = const Color(0xFF10B981); // Green
                          } else if (task.status.toLowerCase().contains("berlangsung") || task.status.toLowerCase().contains("progress")) {
                            accentColor = const Color(0xFF2563EB); // Blue
                          } else {
                            accentColor = const Color(0xFFFACC15); // Yellow default
                          }
 
                          bool hasUrl = task.jobDesc.startsWith('http');

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0, top: 0, bottom: 0, width: 4,
                                    child: Container(color: accentColor),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                              child: Text(
                                                displayStatus.toUpperCase(), 
                                                style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.person_rounded, size: 12, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(task.assignee, style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: Text(
                                            task.title, 
                                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (task.team.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 12.0),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                                              child: Text(task.team, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500)),
                                            ),
                                          ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 6),
                                                Text(task.date, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                            if (task.jobDesc.isNotEmpty)
                                              hasUrl 
                                                ? InkWell(
                                                    onTap: () => _openLink(task.jobDesc),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.link_rounded, size: 14, color: Color(0xFF0F172A)),
                                                          const SizedBox(width: 6),
                                                          const Text("View Brief", style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w600)),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : Flexible(
                                                    child: Text(
                                                      task.jobDesc, 
                                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    ),
                                                  )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
