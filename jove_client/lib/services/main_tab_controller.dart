import 'package:flutter/material.dart';

class MainTabController {
  MainTabController._();

  static PageController pageController = PageController();
  static final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  static void switchTab(int index) {
    if (selectedIndex.value == index) return;
    selectedIndex.value = index;
    if (pageController.hasClients) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }
}
