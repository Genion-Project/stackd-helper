import 'package:flutter/material.dart';

class ConnectPage extends StatelessWidget {
  final bool isConnected;
  final bool isReading;
  final TextEditingController pathController;
  final Animation<double> pulseAnimation;
  final VoidCallback onToggleConnection;
  final VoidCallback onBrowseDirectory;

  const ConnectPage({
    super.key,
    required this.isConnected,
    required this.isReading,
    required this.pathController,
    required this.pulseAnimation,
    required this.onToggleConnection,
    required this.onBrowseDirectory,
  });

  @override
  Widget build(BuildContext context) {
    String projectName = pathController.text.isNotEmpty ? pathController.text.split('/').last : "No Project Selected";

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isConnected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? "SYSTEM SECURED" : "OFFLINE", 
                    style: TextStyle(
                      color: isConnected ? Colors.white : const Color(0xFF475569), 
                      fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.folder_rounded, size: 20, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 16),
                Text(projectName, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              ],
            ),
            const SizedBox(height: 12),
            Text(isConnected ? "Active workspace is fully protected" : "Tap the core to activate Git tracker", style: const TextStyle(color: Color(0xFF64748B), fontSize: 15)),
            const SizedBox(height: 64),
            _buildPowerButton(),
            const SizedBox(height: 72),
            _buildInputBox(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerButton() {
    return GestureDetector(
      onTap: isReading ? null : onToggleConnection,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isConnected || isReading)
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 140 + (pulseAnimation.value * 40),
                  height: 140 + (pulseAnimation.value * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    border: Border.all(color: const Color(0xFF0F172A).withOpacity(0.1 * (1 - pulseAnimation.value)), width: 1),
                  ),
                );
              },
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF0F172A) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: isConnected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1), width: 1),
              boxShadow: [
                if (isConnected)
                  BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))
              ],
            ),
            child: Center(
              child: isReading 
                  ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(Icons.power_settings_new_rounded, size: 48, color: isConnected ? Colors.white : const Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBox(BuildContext context) {
    return Container(
      width: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TARGET REPOSITORY", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), 
                    borderRadius: BorderRadius.circular(4), 
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: pathController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                      border: InputBorder.none, 
                      hintText: '/Users/admin/projects/...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Browse Directory',
                child: InkWell(
                  onTap: onBrowseDirectory,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 42, width: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.folder_open_rounded, color: Color(0xFF475569), size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
