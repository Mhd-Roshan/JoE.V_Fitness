import os
import re

directory = 'lib/screens'
files_to_fix = [
    'app_language_screen.dart',
    'change_trainer_screen.dart',
    'health_profile_screen.dart',
    'my_goals_screen.dart',
    'notification_settings_screen.dart',
    'personal_details_screen.dart'
]

import_statement = "import '../services/main_tab_controller.dart';\n"

navigate_pattern = re.compile(r'void _navigate\(Widget screen\) \{.*?(?=Widget _buildBottomNavBar)', re.DOTALL)

new_navigate = '''void _navigate(Widget screen) {
    HapticFeedback.selectionClick();
    int index = 4; // default to profile
    if (screen is HomeDashboardScreen) index = 0;
    else if (screen is ProgressScreen) index = 2;
    else if (screen is ChatScreen) index = 3;
    else if (screen is ProfileScreen) index = 4;
    
    Navigator.popUntil(context, (route) => route.isFirst);
    MainTabController.switchTab(index);
  }

  Future<void> _navigateToBooking() async {
    HapticFeedback.selectionClick();
    Navigator.popUntil(context, (route) => route.isFirst);
    MainTabController.switchTab(1);
  }

  '''

for filename in files_to_fix:
    path = os.path.join(directory, filename)
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add import if missing
        if "main_tab_controller.dart" not in content:
            # Find the last import and add it after
            import_match = re.finditer(r'^import .*;$', content, re.MULTILINE)
            last_import = list(import_match)[-1]
            content = content[:last_import.end()] + '\n' + import_statement + content[last_import.end():]
            
        # Replace _navigate and _navigateToBooking
        content = navigate_pattern.sub(new_navigate, content)
        
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed {filename}")

