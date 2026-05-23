import 'package:flutter/material.dart';
import '../utils/ui_utils.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String avatarUrl;
  final String userName;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.avatarUrl = '',
    this.userName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 56, height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset('assets/genion_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(height: 48),
          _buildSidebarIcon(context, Icons.radar_rounded, "Tracker", 0),
          const SizedBox(height: 16),
          _buildSidebarIcon(context, Icons.insert_chart_rounded, "Details", 1),
          const SizedBox(height: 16),
          _buildSidebarIcon(context, Icons.task_alt_rounded, "SPK", 2),
          const Spacer(),
          _buildProfileIcon(context, "Profile", 3),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSidebarIcon(BuildContext context, IconData icon, String label, int index) {
    final isActive = selectedIndex == index;
    final themeColor = isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B);
    final bgColor = isActive ? const Color(0xFF0F172A).withOpacity(0.04) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () {
          onItemSelected(index);
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Icon(icon, color: themeColor, size: 26),
              const SizedBox(height: 6),
              Text(
                label, 
                style: TextStyle(
                  color: themeColor, 
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIcon(BuildContext context, String label, int index) {
    final isActive = selectedIndex == index;
    final themeColor = isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B);
    final bgColor = isActive ? const Color(0xFF0F172A).withOpacity(0.04) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => onItemSelected(index),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 1.5),
                  image: avatarUrl.isNotEmpty 
                    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                    : null,
                ),
                child: avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                label, 
                style: TextStyle(
                  color: themeColor, 
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
