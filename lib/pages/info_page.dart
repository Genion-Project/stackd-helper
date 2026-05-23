import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/models.dart';

class InfoPage extends StatefulWidget {
  final bool isConnected;
  final String branchName;
  final String projectPath;
  final List<GitChange> changedFiles;
  final List<GitCommit> recentCommits;

  const InfoPage({
    super.key,
    required this.isConnected,
    required this.branchName,
    required this.projectPath,
    required this.changedFiles,
    required this.recentCommits,
  });


  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final List<String> _consoleOutput = ['Welcome to Git Console. Ready.'];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  Process? _gitProcess;
  bool _isConsoleVisible = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _gitProcess?.kill();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendInput() {
    final text = _inputController.text;
    if (text.isNotEmpty && _gitProcess != null) {
      _gitProcess!.stdin.writeln(text);
      setState(() {
        _consoleOutput.add('> $text');
      });
      _inputController.clear();
      _scrollToBottom();
    }
  }

  Widget _buildConsoleSection() {
    return _buildSection("Terminal", Icons.terminal_rounded, 
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _consoleOutput.length,
                itemBuilder: (context, index) {
                  return Text(
                    _consoleOutput[index],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11),
                  );
                },
              ),
            ),
          ),
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text('>', style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _sendInput(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 14),
                  onPressed: () {
                    setState(() {
                      _isConsoleVisible = false;
                    });
                  },
                )
              ],
            ),
          ),
        ],
      )
    );
  }
  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 64, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 24),
            const Text("No Active Repository", style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text("Connect a repository first to view its details.", style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoPageHeader(context),
          const SizedBox(height: 16),
          _buildGitActions(context),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildSection("Working Changes", Icons.edit_document, _buildChangesList())),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2, 
                  child: Column(
                    children: [
                      Expanded(child: _buildSection("Recent Activity", Icons.history_rounded, _buildHistoryList())),
                      if (_isConsoleVisible) ...[
                        const SizedBox(height: 16),
                        Expanded(child: _buildConsoleSection()),
                      ]
                    ],
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGitActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: () => _gitAdd(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _showCommitDialog(context),
          icon: const Icon(Icons.commit, size: 18),
          label: const Text('Commit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1F5F9),
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _gitPush(context),
          icon: const Icon(Icons.cloud_upload, size: 18),
          label: const Text('Push'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Future<void> _runGitCommand(List<String> args) async {
    setState(() {
      _isConsoleVisible = true;
      _consoleOutput.add('\$ git ${args.join(' ')}');
    });
    _scrollToBottom();

    try {
      // Use environment variable to prevent Git from using terminal /dev/tty for prompts which would bypass our console
      _gitProcess = await Process.start('git', args, workingDirectory: widget.projectPath, environment: {'GIT_TERMINAL_PROMPT': '0'});

      _gitProcess!.stdout.transform(utf8.decoder).listen((data) {
        if (mounted) {
          setState(() {
            _consoleOutput.addAll(data.split('\n').where((e) => e.isNotEmpty));
          });
          _scrollToBottom();
        }
      });

      _gitProcess!.stderr.transform(utf8.decoder).listen((data) {
        if (mounted) {
          setState(() {
            _consoleOutput.addAll(data.split('\n').where((e) => e.isNotEmpty));
          });
          _scrollToBottom();
        }
      });

      final exitCode = await _gitProcess!.exitCode;
      if (mounted) {
        setState(() {
          if (exitCode != 0) {
            _consoleOutput.add('Process exited with code $exitCode');
            if (args.contains('push')) {
              bool hasAuthError = _consoleOutput.any((l) => l.contains('terminal prompts disabled') || l.contains('could not read Username') || l.contains('Authentication failed'));
              if (hasAuthError) {
                _consoleOutput.add('Note: Authentication failed. Launching auth dialog...');
                Future.microtask(() => _showAuthenticationDialog());
              } else {
                _consoleOutput.add('Note: If this is an authentication error, please configure Git credential helper or use SSH keys.');
              }
            }
            if (args.contains('commit')) {
               bool hasIdentityError = _consoleOutput.any((l) => l.contains('Please tell me who you are') || l.contains('Author identity unknown') || l.contains('empty ident name'));
               if (hasIdentityError) {
                  // We delay slightly to allow state to settle before showing dialog
                  Future.microtask(() => _showIdentityErrorDialog(context));
               }
            }
          }
        });
        _scrollToBottom();
      }
    } catch(e) { 
      if (mounted) {
        setState(() {
          _consoleOutput.add('Error: $e');
        });
        _scrollToBottom();
      }
    } finally {
      _gitProcess = null;
    }
  }

  void _showIdentityErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: const [
            Icon(Icons.person_off_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 12),
            Text('Identity Required', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text(
          'Git cannot commit because your name and email are not configured.\n\nPlease go to the Profile page to set up your Git identity.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      )
    );
  }

  void _showAuthenticationDialog() {
    final usernameCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: const [
            Icon(Icons.lock_person_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 12),
            Text('GitHub Authentication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Authentication failed. Please provide your GitHub Username and Personal Access Token (PAT) to continue.",
                style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'GitHub Username',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Personal Access Token',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(child: Text("Your token will be securely stored natively in ~/.git-credentials.", style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (usernameCtrl.text.isNotEmpty && tokenCtrl.text.isNotEmpty) {
                await _configureGitCredentials(usernameCtrl.text.trim(), tokenCtrl.text.trim());
                _gitPush(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Save & Retry Push', style: TextStyle(fontWeight: FontWeight.w600)),
          )
        ],
      )
    );
  }

  Future<void> _configureGitCredentials(String username, String token) async {
    try {
      final res = await Process.run('git', ['remote', 'get-url', 'origin'], workingDirectory: widget.projectPath);
      String url = res.stdout.toString().trim();
      String domain = 'github.com';
      if (url.startsWith('https://')) {
        final uri = Uri.parse(url);
        domain = uri.host;
      }

      await Process.run('git', ['config', '--global', 'credential.helper', 'store']);

      final env = Platform.environment;
      final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
      if (home.isEmpty) throw Exception('Home directory not found');
      
      final credFile = File('$home/.git-credentials');
      final encodedUser = Uri.encodeComponent(username);
      final encodedToken = Uri.encodeComponent(token);
      String credentialLine = 'https://$encodedUser:$encodedToken@$domain';
      
      List<String> lines = [];
      if (await credFile.exists()) {
        lines = await credFile.readAsLines();
        lines.removeWhere((line) => line.contains('@$domain'));
      }
      lines.add(credentialLine);
      
      await credFile.writeAsString(lines.join('\n') + '\n');
      
      _showToast(context, 'Credentials configured successfully!');
    } catch(e) {
      _showToast(context, 'Failed to configure credentials: $e');
    }
  }

  Future<void> _gitAdd(BuildContext context) async {
    await _runGitCommand(['add', '.']);
  }

  Future<void> _gitPush(BuildContext context) async {
    await _runGitCommand(['push']);
  }

  void _showCommitDialog(BuildContext context) {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: const [
            Icon(Icons.edit_document, color: Color(0xFF0F172A)),
            SizedBox(width: 12),
            Text('Commit Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enter a descriptive message for your commit.", style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
              const SizedBox(height: 16),
              TextField(
                controller: tc,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g., Update UI components',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (tc.text.isNotEmpty) {
                await _runGitCommand(['commit', '-m', tc.text]);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Commit', style: TextStyle(fontWeight: FontWeight.w600)),
          )
        ],
      )
    );
  }

  void _showToast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _showBranchDialog(BuildContext context) async {
    List<String> branches = [];
    try {
      final res = await Process.run('git', ['branch', '-a', '--format=%(refname:short)'], workingDirectory: widget.projectPath);
      if (res.exitCode == 0) {
        final rawBranches = res.stdout.toString().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final Set<String> uniqueBranches = {};
        for (var b in rawBranches) {
          if (b == 'origin/HEAD') continue;
          if (b.startsWith('origin/')) {
            uniqueBranches.add(b.substring(7));
          } else {
            uniqueBranches.add(b);
          }
        }
        branches = uniqueBranches.toList()..sort();
      }
    } catch(e) {
      _showToast(context, 'Failed to load branches: $e');
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          title: Row(
            children: const [
              Icon(Icons.call_split_rounded, color: Color(0xFF0F172A)),
              SizedBox(width: 12),
              Text('Select Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text("Choose a branch to checkout.", style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: branches.length,
                    separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                    itemBuilder: (context, index) {
                      final b = branches[index];
                      final isCurrent = b == widget.branchName;
                      return InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          if (!isCurrent) {
                            await _runGitCommand(['checkout', b]);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.alt_route_rounded, size: 16, color: isCurrent ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(b, style: TextStyle(fontSize: 14, color: isCurrent ? const Color(0xFF0F172A) : const Color(0xFF475569), fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500)),
                              ),
                              if (isCurrent) Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: const Text("Current", style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700)),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showCreateBranchDialog(context);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Branch', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        );
      }
    );
  }

  void _showCreateBranchDialog(BuildContext context) {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: const [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 12),
            Text('Create Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enter a name for your new branch.", style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
              const SizedBox(height: 16),
              TextField(
                controller: tc,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Branch Name',
                  hintText: 'e.g., feature/login-ui',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (tc.text.isNotEmpty) {
                await _runGitCommand(['checkout', '-b', tc.text]);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w600)),
          )
        ],
      )
    );
  }

  Widget _buildInfoPageHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _showBranchDialog(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), 
                borderRadius: BorderRadius.circular(4), 
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_split_rounded, size: 18, color: Colors.white), 
                  const SizedBox(width: 8), 
                  Text(widget.branchName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.projectPath, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text("${widget.changedFiles.length} files changed", style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(6), 
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ), 
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangesList() {
    if (widget.changedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: const Color(0xFF10B981).withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text("Workspace is clean", style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text("Nothing to commit", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.changedFiles.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
      itemBuilder: (context, index) {
        final item = widget.changedFiles[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 28, height: 28, 
            decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), 
            child: Center(
              child: Text(item.status, style: TextStyle(color: item.color, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ),
          title: Text(item.filePath, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
          subtitle: Text(item.statusLabel, style: TextStyle(color: item.color.withOpacity(0.8), fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            color: const Color(0xFF94A3B8),
            onPressed: () {},
            tooltip: 'View Diff',
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    if (widget.recentCommits.isEmpty) {
      return const Center(child: Text("No history available", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.recentCommits.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
      itemBuilder: (context, index) {
        final commit = widget.recentCommits[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(commit.message, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                  child: Text(commit.hash, style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(commit.date, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }
}
