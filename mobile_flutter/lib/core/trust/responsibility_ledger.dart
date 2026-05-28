import 'package:flutter/foundation.dart';

/// Session-local adjustments on top of Home/dashboard baseline.
///
/// **Demo intent:** mock baseline (e.g. 75) is **display-only**. The backend stores the real score
/// (new users at 100); the home/study UI does not show it. Only [mockOnly] + session **listing** deltas
/// apply here. Per-session caps, no hard reserve
/// block for normal demo range.
///
/// **Server sync (future):** see `BuddyListingScoreIntegrationNotes.java`.
class ResponsibilityLedger extends ChangeNotifier {
  ResponsibilityLedger._();
  static final ResponsibilityLedger instance = ResponsibilityLedger._();

  int _mockFallback = 75;
  int _listingDelta = 0;
  int _listingsThisSession = 0;
  int _reservationsThisSession = 0;

  /// Tracks which user the current session counters belong to.
  /// When a different user logs in, counters are reset.
  String? _activeUserId;

  static const int scoreCostPerBuddyListing = 1;

  /// Only for buddy posts — don’t let listing cost pull mock user into a weird band in one tap.
  static const int minScoreAfterListing = 45;

  /// App hero / buddy UI uses [mockOnly] only (e.g. 75 from home mock data); `GET /dashboard/home`
  /// `responsibilityScore` (real DB, e.g. 100) is not applied to this ledger.
  void setHomeContext({required int mockOnly}) {
    _mockFallback = mockOnly;
    notifyListeners();
  }

  void syncWithScore(int score) {
    _mockFallback = score;
    _listingDelta = 0;
    _listingsThisSession += 1;
    notifyListeners();
  }

  /// Called on every successful login. If [userId] differs from the previously
  /// active user, all per-session counters are reset so that one user's usage
  /// does not bleed into another user's session on the same device.
  void resetForUser(String userId) {
    if (_activeUserId == userId) return; // same user, keep existing session state
    _activeUserId = userId;
    _reservationsThisSession = 0;
    _listingsThisSession = 0;
    _listingDelta = 0;
    notifyListeners();
  }

  int get _base => _mockFallback;

  int get effectiveScore => (_base + _listingDelta).clamp(0, 100);

  int get listingsPosted => _listingsThisSession;
  int get reservationsThisSession => _reservationsThisSession;

  static const int maxDemoActionsPerSession = 2;

  /// Buddy listings per app session (demo: **2 max**, “kısıtlı” hak).
  int get maxBuddyListingsPerSession {
    final s = effectiveScore;
    if (s < 50) return 0;
    return maxDemoActionsPerSession;
  }

  int get listingsRemaining => (maxBuddyListingsPerSession - _listingsThisSession).clamp(0, maxBuddyListingsPerSession);

  /// Confirmed reservations per app session — **2** (independent of score; not blocked in demo).
  int maxReservationsThisSessionForScore() => maxDemoActionsPerSession;

  String reserveDemoBannerLine() {
    final s = effectiveScore;
    final limit = s < 75 ? 2 : 3;
    return 'Score $s — up to $limit reservations per day (enforced by server).';
  }

  String buddyDemoLine() {
    final s = effectiveScore;
    if (s < 50) {
      return 'Score $s — buddy listings need 50+ in this demo.';
    }
    return 'Score $s — up to $maxDemoActionsPerSession listings this session (−$scoreCostPerBuddyListing pt each, demo).';
  }

  bool get canPostAnotherBuddyListing =>
      maxBuddyListingsPerSession > 0 &&
      _listingsThisSession < maxBuddyListingsPerSession &&
      (_base + _listingDelta) >= scoreCostPerBuddyListing;

  /// **No score-based hard block locally** for reserving.
  /// Enforced dynamically per user on the backend.
  String? canAttemptReservation() {
    return null;
  }

  void recordReservationConfirmed() {
    _reservationsThisSession += 1;
    notifyListeners();
  }

  String? tryConsumeBuddyListing() {
    if (maxBuddyListingsPerSession == 0) {
      return 'Buddy listings need a score of 50+ in this demo.';
    }
    if (_listingsThisSession >= maxBuddyListingsPerSession) {
      return 'Buddy listing limit reached this session ($listingsPosted/$maxBuddyListingsPerSession).';
    }
    final after = _base + _listingDelta - scoreCostPerBuddyListing;
    if (after < minScoreAfterListing) {
      return 'Another listing would push your score very low. Check in to earn points first.';
    }
    _listingsThisSession += 1;
    _listingDelta -= scoreCostPerBuddyListing;
    notifyListeners();
    return null;
  }
}
