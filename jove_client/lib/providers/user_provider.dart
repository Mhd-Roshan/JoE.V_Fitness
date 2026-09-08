import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  UserProvider() {
    _initAuthListener();
  }

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  void _initAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? authUser) {
      _user = authUser;
      if (_user != null) {
        _fetchUserData();
      } else {
        _userData = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userData = doc.data();
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Call this to manually refresh data (e.g. after profile update)
  Future<void> refreshUser() async {
    if (_user != null) {
      await _fetchUserData();
    }
  }
}
