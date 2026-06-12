// Location: lib/services/monetization_service.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonetizationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // 🔥 1. INITIALIZE ADMOB
  Future<void> initAds() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
  }

  // 🔥 2. LOAD REWARDED AD
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // TEST ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ad failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // 🔥 3. CHECK VAULT CAPACITY
  Future<bool> isVaultFull() async {
    if (user == null) return false;

    final filesSnapshot = await _db
        .collection('vault_files')
        .where('ownerId', isEqualTo: user!.uid)
        .count()
        .get();
    
    int currentFiles = filesSnapshot.count ?? 0;

    final prefs = await SharedPreferences.getInstance();
    int maxSlots = prefs.getInt('vault_max_slots') ?? 20;

    return currentFiles >= maxSlots;
  }

  // 🔥 4. GET CURRENT AD PROGRESS
  Future<int> getAdProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('vault_ad_progress') ?? 0;
  }

  // 🔥 5. SHOW AD & TRACK PROGRESS
  Future<void> showRewardedAd(BuildContext context, Function(int) onProgress, VoidCallback onSuccess) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ad not ready yet. Please wait a few seconds."), backgroundColor: Colors.orange)
      );
      _loadRewardedAd(); 
      return;
    }

    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
      final prefs = await SharedPreferences.getInstance();
      int currentProgress = prefs.getInt('vault_ad_progress') ?? 0;
      
      // Increment their watched count
      currentProgress++;

      if (currentProgress >= 4) {
        // 🔥 They hit 4! Give them the 10 slots and reset the counter.
        int currentSlots = prefs.getInt('vault_max_slots') ?? 20;
        await prefs.setInt('vault_max_slots', currentSlots + 10);
        await prefs.setInt('vault_ad_progress', 0); // Reset for next time
        onSuccess();
      } else {
        // Save progress and tell the UI to update
        await prefs.setInt('vault_ad_progress', currentProgress);
        onProgress(currentProgress);
      }
    });

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd(); // Immediately load the next ad so they can watch back-to-back
      },
    );
  }
}