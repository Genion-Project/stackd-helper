import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/ui_utils.dart';
import '../widgets/sidebar.dart';
import '../pages/connect_page.dart';
import '../pages/info_page.dart';
import '../pages/spk_page.dart';
import '../pages/profile_page.dart';

class GitNexusHome extends StatefulWidget {
  final Map<String, dynamic>? notionData;

  const GitNexusHome({super.key, this.notionData});

  @override
  State<GitNexusHome> createState() => _GitNexusHomeState();
}

class _GitNexusHomeState extends State<GitNexusHome> with TickerProviderStateMixin {
  final TextEditingController _pathController = TextEditingController();
  int _selectedIndex = 0; // 0 = Connect, 1 = Info, 2 = SPK
  bool _isReading = false;
  bool _isConnected = false;
  
  String _branchName = '';
  List<GitChange> _changedFiles = [];
  List<GitCommit> _recentCommits = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _refreshTimer;
  String _avatarUrl = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    _pathController.text = '/home/nfl-linux/Workspace/stackd_helper';
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    final token = widget.notionData?['access_token'] ?? '';
    if (token.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('https://api.notion.com/v1/users/me'),
        headers: {'Authorization': 'Bearer $token', 'Notion-Version': '2022-06-28'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _avatarUrl = data['avatar_url'] ?? '';
            _userName = data['name'] ?? '';

            if (data['type'] == 'bot') {
               final owner = data['bot']?['owner']?['user'];
               if (owner != null) {
                  if (owner['avatar_url'] != null) _avatarUrl = owner['avatar_url'];
                  if (owner['name'] != null) _userName = owner['name'];
               }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching avatar: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browseDirectory() async {
    try {
      if (Platform.isLinux) {
        final result = await Process.run('zenity', ['--file-selection', '--directory']);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          _updatePath(result.stdout.toString().trim());
        }
      } else if (Platform.isWindows) {
        const psCommand = 'Add-Type -AssemblyName System.Windows.Forms; '
            '\$f = New-Object System.Windows.Forms.FolderBrowserDialog; '
            'if(\$f.ShowDialog() -eq "OK"){\$f.SelectedPath}';
            
        final result = await Process.run('powershell', ['-Command', psCommand]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          _updatePath(result.stdout.toString().trim());
        }
      } else {
        showCustomToast(context, 'Auto-picker not supported on this platform.', isError: true);
      }
    } catch (e) {
      showCustomToast(context, 'Failed to open picker.', isError: true);
    }
  }

  void _updatePath(String path) {
    setState(() {
      _pathController.text = path;
      if (_isConnected) _toggleConnection();
    });
  }

  Future<void> _readGitInfo({bool silent = false}) async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      if (!silent) showCustomToast(context, 'Please input a project directory', isError: true);
      return;
    }

    if (!silent) {
      setState(() {
        _isReading = true;
        _branchName = '';
        _changedFiles = [];
        _recentCommits = [];
        _isConnected = false;
      });
      _pulseController.repeat(reverse: true);
    }

    try {
      if (!silent) {
        try {
          await Process.run('git', ['--version']);
        } catch (e) {
          throw Exception('Git is not installed or not found in PATH.');
        }
      }

      if (!Directory(path).existsSync()) {
        throw Exception('Directory does not exist');
      }

      final checkGit = await Process.run('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: path);
      if (checkGit.exitCode != 0) {
        throw Exception('Not a git repository');
      }

      // 1. Branch
      final branchResult = await Process.run('git', ['rev-parse', '--abbrev-ref', 'HEAD'], workingDirectory: path);
      
      // 2. Parsed Status
      final statusResult = await Process.run('git', ['status', '-s'], workingDirectory: path);
      final rawStatus = statusResult.stdout.toString().trim();
      final List<GitChange> parsedChanges = [];
      if (rawStatus.isNotEmpty) {
        for (var line in rawStatus.split('\n')) {
          if (line.length >= 3) {
            final status = line.substring(0, 2).trim();
            final file = line.substring(2).trim();
            parsedChanges.add(GitChange(status, file));
          }
        }
      }

      // 3. Recent History
      final logResult = await Process.run(
        'git', 
        ['log', '-n', '10', '--pretty=format:%h|%an|%ar|%s'], 
        workingDirectory: path
      );
      final rawLog = logResult.stdout.toString().trim();
      final List<GitCommit> parsedCommits = [];
      if (rawLog.isNotEmpty) {
        for (var line in rawLog.split('\n')) {
          final parts = line.split('|');
          if (parts.length >= 4) {
            parsedCommits.add(GitCommit(parts[0], parts[1], parts[2], parts[3]));
          }
        }
      }
      
      if (!silent) {
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (mounted) {
        setState(() {
          _isConnected = true;
          _branchName = branchResult.stdout.toString().trim();
          _changedFiles = parsedChanges;
          _recentCommits = parsedCommits;
        });
      }
      
    } catch (e) {
      if (!silent) {
        showCustomToast(context, e.toString().replaceAll('Exception: ', ''), isError: true);
        _pulseController.stop();
        _pulseController.reset();
      } else {
        // If it fails during silent refresh, something is wrong, stop the timer
        _toggleConnection();
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _isReading = false;
        });
      }
    }
  }

  void _toggleConnection() {
    if (_isConnected) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      setState(() {
        _isConnected = false;
        _branchName = '';
        _changedFiles = [];
        _recentCommits = [];
      });
      _pulseController.stop();
      _pulseController.reset();
    } else {
      _readGitInfo().then((_) {
        if (_isConnected) {
          _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
            _readGitInfo(silent: true);
          });
        }
      });
    }
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFFF8FAFC)),
        Positioned(
          top: -150, left: -150,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [const Color(0xFF3B82F6).withOpacity(0.06), Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            avatarUrl: _avatarUrl,
            userName: _userName,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
          Expanded(
            child: Stack(
              children: [
                _buildBackground(),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedIndex == 0 
                        ? ConnectPage(
                            isConnected: _isConnected,
                            isReading: _isReading,
                            pathController: _pathController,
                            pulseAnimation: _pulseAnimation,
                            onToggleConnection: _toggleConnection,
                            onBrowseDirectory: _browseDirectory,
                          )
                        : _selectedIndex == 1 
                            ? InfoPage(
                                isConnected: _isConnected,
                                branchName: _branchName,
                                projectPath: _pathController.text,
                                changedFiles: _changedFiles,
                                recentCommits: _recentCommits,
                              )
                            : _selectedIndex == 2
                                ? SpkPage(notionData: widget.notionData)
                                : ProfilePage(notionData: widget.notionData),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
