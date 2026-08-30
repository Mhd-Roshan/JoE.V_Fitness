import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'support_screen.dart';
import '../theme/app_theme_controller.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  // Theme Colors
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _iconBg = Color(0xFFF0F2F5);



  Future<void> _launchUrl(String urlString) async {
    HapticFeedback.selectionClick();
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open link")),
        );
      }
    }
  }

  void _navigateToSupport() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SupportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final Color currentBg = isDark ? const Color(0xFF000000) : _bgColor;
        final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;
        final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final Color borderColor = isDark ? const Color(0xFF262626) : Colors.grey.shade200;

        return Scaffold(
          backgroundColor: currentBg,
          appBar: AppBar(
            backgroundColor: currentBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textMain, size: 20),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
            ),
            title: Text(
              'Help & Feedback',
              style: TextStyle(
                color: textMain,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact & Support',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [

                      _buildListTile(
                        icon: Icons.phone_outlined,
                        iconColor: Colors.blue,
                        title: 'Call Support',
                        subtitle: '+91 8086 088748',
                        onTap: () => _launchUrl('tel:+918086088748'),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildListTile(
                        icon: Icons.email_outlined,
                        iconColor: Colors.orange,
                        title: 'Email Us',
                        subtitle: 'joev7717@gmail.com',
                        onTap: () => _launchUrl('mailto:joev7717@gmail.com?subject=Support Enquiry'),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildListTile(
                        icon: Icons.support_agent_rounded,
                        iconColor: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                        title: 'Support Tickets',
                        subtitle: 'Submit and track your issues',
                        onTap: _navigateToSupport,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Legal & Policies',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                        title: 'Privacy Policy',
                        subtitle: 'How we manage your data',
                        onTap: () => _launchUrl('https://joevfitness.com/privacy'),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildListTile(
                        icon: Icons.description_outlined,
                        iconColor: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                        title: 'Terms & Conditions',
                        subtitle: 'Rules and guidelines',
                        onTap: () => _launchUrl('https://joevfitness.com/terms'),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildListTile(
                        icon: Icons.currency_exchange,
                        iconColor: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                        title: 'Refund & Cancellation',
                        subtitle: 'Payment and refund terms',
                        onTap: () => _launchUrl('https://joevfitness.com/refund'),
                        isDark: isDark,
                      ),
                      _buildDivider(isDark),
                      _buildListTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: isDark ? const Color(0xFF3B82F6) : _navBgColor,
                        title: 'About Us',
                        subtitle: 'Learn more about our company',
                        onTap: () => _launchUrl('https://joevfitness.com/about'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : _iconBg,
                borderRadius: BorderRadius.circular(10),
                border: isDark ? Border.all(color: const Color(0xFF262626)) : null,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF5F5F5) : _navBgColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: isDark ? const Color(0xFF262626) : Colors.grey.shade100,
    );
  }
}
