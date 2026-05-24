import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'home_screen.dart';
import '../utils/ui_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _showManualInput = false;
  final TextEditingController _tokenController = TextEditingController();
  late AnimationController _bgController;
  Timer? _pollTimer;
  
  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _checkSavedAuth();
  }

  String _getAuthFilePath() {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    return '$home/.stackd_notion_auth.json';
  }

  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    try {
      final file = File(_getAuthFilePath());
      final payload = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      };
      await file.writeAsString(jsonEncode(payload));
    } catch (e) {
      debugPrint('Error saving auth data: $e');
    }
  }

  Future<void> _checkSavedAuth() async {
    try {
      final file = File(_getAuthFilePath());
      if (await file.exists()) {
        final content = await file.readAsString();
        final payload = jsonDecode(content);
        final timestamp = payload['timestamp'] ?? 0;
        final data = payload['data'];
        
        final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        if (now.difference(savedTime).inDays < 30) {
          if (mounted) {
            _navigateToHome(data);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading auth data: $e');
    }
  }


  @override
  void dispose() {
    _tokenController.dispose();
    _pollTimer?.cancel();
    _bgController.dispose();
    super.dispose();
  }

  void _submitManualToken() {
    final token = _tokenController.text.trim();
    if (token.isNotEmpty) {
      showCustomToast(context, 'Successfully authenticated manually!');
      final data = {'access_token': token};
      _saveAuthData(data);
      _navigateToHome(data);
    } else {
      showCustomToast(context, 'Please enter a valid token.', isError: true);
    }
  }

  Future<void> _handleNotionLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clientId = dotenv.isInitialized ? (dotenv.env['NOTION_CLIENT_ID'] ?? '') : '';
      
      if (clientId.isEmpty) {
        throw 'Notion Client ID is missing.';
      }

      final redirectUri = dotenv.isInitialized ? (dotenv.env['NOTION_REDIRECT_URI'] ?? 'https://stackd.smknurisjkt.org/oauth/callback') : 'https://stackd.smknurisjkt.org/oauth/callback';
      final encodedRedirectUri = Uri.encodeComponent(redirectUri);
      
      final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      final authUrl = 'https://api.notion.com/v1/oauth/authorize?client_id=$clientId&response_type=code&owner=user&redirect_uri=$encodedRedirectUri&state=$sessionId';
      
      final Uri url = Uri.parse(authUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        _pollStatus(sessionId);
      } else {
        throw 'Could not launch Notion OAuth URL.';
      }
    } catch (e) {
      showCustomToast(context, e.toString(), isError: true);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _pollStatus(String sessionId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final uri = Uri.parse('https://stackd.smknurisjkt.org/oauth/status?session_id=$sessionId');
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            timer.cancel();
            final accessToken = data['data']['access_token'];
            _saveAuthData(data['data']);
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _showProfilePopup(data['data']);
            }
          } else if (data['status'] == 'error') {
            timer.cancel();
            if (mounted) {
              showCustomToast(context, 'OAuth Error: ${data['message']}', isError: true);
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
      } catch (e) {
        // Ignore network errors during polling
      }
    });
  }

  void _showProfilePopup(Map<String, dynamic> tokenData) {
    if (!mounted) return;
    
    final workspaceName = tokenData['workspace_name'] ?? 'Notion Workspace';
    final workspaceIcon = tokenData['workspace_icon'];
    final ownerName = tokenData['owner']?['user']?['name'] ?? 'Notion User';
    final avatarUrl = tokenData['owner']?['user']?['avatar_url'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (BuildContext context) {
        return Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Connected Successfully',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF38BDF8),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: Center(
                                  child: Text(
                                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'N',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFF1F5F9),
                              child: Center(
                                child: Text(
                                  ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'N',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ownerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (workspaceIcon != null && workspaceIcon.toString().startsWith('http'))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            workspaceIcon,
                            width: 16,
                            height: 16,
                            errorBuilder: (c, e, s) => const Icon(Icons.business_rounded, color: Colors.grey, size: 14),
                          ),
                        )
                      else if (workspaceIcon != null && workspaceIcon.toString().isNotEmpty)
                        Text(workspaceIcon.toString(), style: const TextStyle(fontSize: 14))
                      else
                        const Icon(Icons.business_rounded, color: Colors.grey, size: 14),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          workspaceName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _navigateToHome(tokenData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Let's Go",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToHome([Map<String, dynamic>? notionData]) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GitNexusHome(notionData: notionData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: const Color(0xFFF8FAFC)),
            Positioned(
              top: -200 + (_bgController.value * 50),
              left: -100 - (_bgController.value * 50),
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -300 - (_bgController.value * 50),
              right: -100 + (_bgController.value * 50),
              child: Container(
                width: 800,
                height: 800,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Notion Icon Box
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/4/45/Notion_app_logo.png',
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.note_alt_rounded,
                          size: 46,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Welcome to Stackd',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect your workspace to synchronize your timeline and manage tasks seamlessly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_showManualInput) ...[
                    TextField(
                      controller: _tokenController,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Paste access_token here...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showManualInput = false;
                              });
                            },
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitManualToken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_isLoading) ...[
                    Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Waiting for authentication...',
                          style: TextStyle(color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            _pollTimer?.cancel();
                            setState(() {
                              _isLoading = false;
                            });
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _pollTimer?.cancel();
                            setState(() {
                              _isLoading = false;
                              _showManualInput = true;
                            });
                          },
                          child: const Text('Paste Token Manually', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    )
                  ] else ...[
                    MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _handleNotionLogin,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded, color: Colors.white, size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'Continue with Notion',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 12),
                  if (!_isLoading && !_showManualInput)
                    const Text(
                      'Authentication is required to use the application.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
