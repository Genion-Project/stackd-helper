import 'package:flutter/material.dart';

class GitChange {
  final String status;
  final String filePath;
  GitChange(this.status, this.filePath);

  Color get color {
    switch (status) {
      case 'M': return const Color(0xFFFACC15); // Yellow
      case 'A': return const Color(0xFF4ADE80); // Green
      case 'D': return const Color(0xFFF87171); // Red
      case '??': return const Color(0xFF38BDF8); // Blue (Untracked)
      default: return Colors.white54;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'M': return 'Modified(Diubah)';
      case 'A': return 'Added(Baru Dibuat)';
      case 'D': return 'Deleted(Dihapus)';
      case '??': return 'Untracked(Belum di add)';
      default: return 'Changed(Tidak Terbaca)';
    }
  }
}

class GitCommit {
  final String hash;
  final String author;
  final String date;
  final String message;
  GitCommit(this.hash, this.author, this.date, this.message);
}

class NotionTask {
  final String title;
  final String status;
  final String date;
  final String assignee;
  final String team;
  final String jobDesc;
  final String statusQc;
  
  NotionTask({
    required this.title, 
    required this.status, 
    required this.date, 
    required this.assignee,
    required this.team,
    required this.jobDesc,
    required this.statusQc,
  });

  factory NotionTask.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] ?? {};
    
    // Safety extracts
    String title = "Unknown Task";
    if (properties['Nama proyek']?['title'] != null && (properties['Nama proyek']['title'] as List).isNotEmpty) {
      title = properties['Nama proyek']['title'][0]['plain_text'];
    }

    String status = "To Do";
    if (properties['Status awal']?['status'] != null) {
      status = properties['Status awal']['status']['name'];
    }

    String date = "No Date";
    if (properties['Tanggal akhir']?['date'] != null) {
      date = properties['Tanggal akhir']['date']['start'];
    }

    String assignee = "Unassigned";
    if (properties['PIC']?['people'] != null && (properties['PIC']['people'] as List).isNotEmpty) {
      assignee = properties['PIC']['people'][0]['name'];
    }

    String team = "";
    if (properties['Tim']?['multi_select'] != null && (properties['Tim']['multi_select'] as List).isNotEmpty) {
      team = properties['Tim']['multi_select'][0]['name'];
    }

    String jobDesc = "";
    if (properties['Job Description']?['url'] != null) {
      jobDesc = properties['Job Description']['url'];
    } else if (properties['Job Description']?['rich_text'] != null && (properties['Job Description']['rich_text'] as List).isNotEmpty) {
      jobDesc = properties['Job Description']['rich_text'][0]['plain_text'];
    }

    String statusQc = "";
    if (properties['Status QC']?['status'] != null) {
      statusQc = properties['Status QC']['status']['name'];
    }

    return NotionTask(
      title: title, 
      status: status, 
      date: date, 
      assignee: assignee,
      team: team,
      jobDesc: jobDesc,
      statusQc: statusQc,
    );
  }
}
