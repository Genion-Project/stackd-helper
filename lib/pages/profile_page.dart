import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../screens/login_screen.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? notionData;

  const ProfilePage({super.key, this.notionData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Monochromatic palette
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fetchProfile();
    _loadGitIdentity();
  }

  String _gitName = '';
  String _gitEmail = '';

  Future<void> _loadGitIdentity() async {
    try {
      final nameRes = await Process.run('git', ['config', '--global', 'user.name']);
      final emailRes = await Process.run('git', ['config', '--global', 'user.email']);
      if (mounted) {
        setState(() {
          _gitName = nameRes.stdout.toString().trim();
          _gitEmail = emailRes.stdout.toString().trim();
        });
      }
    } catch (e) {
       // ignore
    }
  }

  Future<void> _configureGitIdentity(String name, String email) async {
    try {
      await Process.run('git', ['config', '--global', 'user.name', name]);
      await Process.run('git', ['config', '--global', 'user.email', email]);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Git identity updated successfully')));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update Git identity: $e')));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _token => widget.notionData?['access_token'] ?? '';

  Future<void> _fetchProfile() async {
    if (_token.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.notion.com/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Notion-Version': '2022-06-28',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _userData = jsonDecode(response.body);
          _isLoading = false;
        });
        _animController.forward();
      } else {
        debugPrint('Error fetching profile: ${response.body}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getAuthFilePath() {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    return '$home/.stackd_notion_auth.json';
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 28),
                  ),
                  const SizedBox(height: 20),
                  const Text("Log Out", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 12),
                  const Text("Are you sure you want to disconnect this workspace? You will need to re-authenticate to use Stackd again.", 
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: textSecondary, height: 1.5)
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textSecondary,
                            side: const BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _performLogout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _performLogout() async {
    try {
      final file = File(_getAuthFilePath());
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting auth file: $e');
    }
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: surfaceColor, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.08), blurRadius: 24)],
          ),
          child: const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5)),
        ),
      );
    }

    if (_userData == null) {
      return const Center(child: Text("Failed to load profile", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500)));
    }

    String name = _userData?['name'] ?? 'Unknown User';
    String avatarUrl = _userData?['avatar_url'] ?? '';
    final String workspaceName = _userData?['bot']?['workspace_name'] ?? 'Notion Workspace';
    String email = _userData?['person']?['email'] ?? ''; 

    // Override with actual owner user if it's a bot integration
    if (_userData?['type'] == 'bot') {
      final ownerUser = _userData?['bot']?['owner']?['user'];
      if (ownerUser != null) {
        if (ownerUser['name'] != null) name = ownerUser['name'];
        if (ownerUser['avatar_url'] != null) avatarUrl = ownerUser['avatar_url'];
        if (ownerUser['person']?['email'] != null) email = ownerUser['person']['email'];
      }
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor,
                  border: Border.all(color: borderColor, width: 2),
                  image: avatarUrl.isNotEmpty 
                    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                    : null,
                ),
                child: avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              
              // Basic Info
              Text(
                name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(fontSize: 14, color: textSecondary)),
              ],
              const SizedBox(height: 32),
              
              // Info Cards
              _buildInfoRow(Icons.business_rounded, "Workspace", workspaceName),
              
              const SizedBox(height: 24),
              _buildGitIdentitySection(),

              const SizedBox(height: 40),
              
              // Logout Button Placeholder
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showLogoutConfirmation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text("Disconnect Integration", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGitIdentitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, size: 18, color: textSecondary),
              const SizedBox(width: 8),
              const Text("Git Global Identity", style: const TextStyle(fontSize: 14, color: textPrimary, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: _showEditGitIdentityDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Edit", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text("Name: ${_gitName.isEmpty ? 'Not set' : _gitName}", style: const TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 4),
          Text("Email: ${_gitEmail.isEmpty ? 'Not set' : _gitEmail}", style: const TextStyle(fontSize: 13, color: textSecondary)),
        ],
      ),
    );
  }

  void _showEditGitIdentityDialog() {
    final nameCtrl = TextEditingController(text: _gitName);
    final emailCtrl = TextEditingController(text: _gitEmail);
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
            Icon(Icons.manage_accounts_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 12),
            Text('Set Git Identity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Configure your global Git username and email.", style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name (user.name)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email (user.email)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
              await _configureGitIdentity(nameCtrl.text.trim(), emailCtrl.text.trim());
              _loadGitIdentity();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          )
        ],
      )
    );
  }
}
