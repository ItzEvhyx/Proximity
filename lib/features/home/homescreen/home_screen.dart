import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/animations/tabs_transitions.dart';
import '../../../core/global_services/wake_service.dart';
import '../../../core/navbar/navbar_widget.dart';
import '../../../core/overlay/overlay_service.dart';
import '../../../core/skeleton_loading/skeleton_loading.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/search_bar.dart';
import '../alarm_dismissal_screen.dart';
import 'tabs/history_tab/history_tab.dart';
import 'tabs/maps_tab/maps_controller.dart';
import 'tabs/maps_tab/maps_tab.dart';
import 'tabs/maps_tab/place_result.dart';
import 'tabs/maps_tab/search_results_dropdown.dart';
import 'tabs/settings_tab/profile_tab.dart';
import 'tabs/routes_tab/routes_tab.dart';
import 'tabs/routes_tab/way_finder/search_guide.dart';
import 'tabs/routes_tab/way_finder/way_finder_tab.dart';

/// Home shell: hosts the four tabs behind the floating navbar, with a sliding
/// tab transition.
///
/// Loading order on first entry: the map initializes and centers on the user's
/// location while a skeleton covers everything. Once the map is ready the
/// skeleton fades out and the search bar and navbar fade in together.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Duration _revealDuration = Duration(milliseconds: 300);

  int _tabIndex = 0;
  bool _mapReady = false;
  bool _skeletonVisible = true;
  Timer? _readyTimeout;

  late final MapsController _mapsController;

  // Routes tab's Matrix/Finder toggle. Owned here (rather than inside
  // RoutesTab) so it can render directly below the floating search bar.
  RouteMode _routeMode = RouteMode.matrix;

  // ── Voice search (speech-to-text) ──────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  String _transcript = '';
  String? _speechError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapsController = MapsController();
    _mapsController.onAlarmTriggered = _onProximityAlarm;
    // Safety net: reveal the UI even if the map never reports ready (e.g. no
    // network / stuck tiles) so the app is never stuck on the skeleton.
    _readyTimeout = Timer(const Duration(seconds: 8), _handleMapReady);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readyTimeout?.cancel();
    _autoSelectTimer?.cancel();
    _mapsController.dispose();
    _speech.stop();
    // Ensure overlay is hidden if screen is disposed while tracking.
    OverlayService.instance.hide();
    super.dispose();
  }

  // ── App lifecycle (show/hide overlay when backgrounded) ────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — hide the overlay since the in-app
      // UI is visible and the overlay would be redundant/distracting.
      OverlayService.instance.hide();
    } else if (state == AppLifecycleState.inactive) {
      // App is about to go to background — re-show overlay if tracking.
      // We use 'inactive' (not 'paused') because the engine is still active
      // here and can reliably execute the showOverlay call.
      if (_mapsController.tracking) {
        OverlayService.instance.show();
      }
    }
  }

  void _handleMapReady() {
    if (_mapReady || !mounted) return;
    _readyTimeout?.cancel();
    setState(() => _mapReady = true);
  }

  // ── Proximity alarm ────────────────────────────────────────────────────

  void _onProximityAlarm() {
    if (!mounted) return;
    // Wake the screen and show over lock screen (like the default Clock app).
    WakeService.instance.wakeUpScreen();
    // Bring the app to the foreground if it's in the background.
    FlutterForegroundTask.launchApp('/');
    // Navigate to the fullscreen alarm dismissal screen.
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlarmDismissalScreen(
          distance: _mapsController.distanceLabel,
          eta: _mapsController.etaToDestination ?? '—',
          onDismissed: () {
            _mapsController.stopTracking();
            // Clear wake flags so the app doesn't permanently show over lock.
            WakeService.instance.clearWakeFlags();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // ── Mic / voice search ─────────────────────────────────────────────────

  /// True from the moment we start listening until we receive the final
  /// speech result. Prevents `_onSpeechStatus('done')` from dismissing UI
  /// prematurely (it can fire before `onResult(finalResult=true)`).
  bool _awaitingFinalResult = false;

  Future<void> _onMicTap() async {
    if (_listening || _pendingAutoSelect) {
      await _speech.stop();
      _autoSelectTimer?.cancel();
      if (mounted) {
        setState(() {
          _listening = false;
          _pendingAutoSelect = false;
          _awaitingFinalResult = false;
        });
      }
      return;
    }

    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (err) {
          // Only show error and stop if it's a fatal error, not a transient
          // "no match" which just means the user was silent briefly.
          final errorType = err.errorMsg;
          final isFatal = errorType == 'error_audio' ||
              errorType == 'error_permission' ||
              errorType == 'error_network';
          if (mounted && isFatal) {
            setState(() {
              _listening = false;
              _pendingAutoSelect = false;
              _awaitingFinalResult = false;
              _speechError = 'Voice input error. Try again.';
            });
          }
        },
      );
    }
    if (!_speechAvailable) {
      if (mounted) {
        setState(() => _speechError =
            'Microphone unavailable. Check app permissions.');
      }
      return;
    }

    // Focus the field so results appear as speech is transcribed.
    _mapsController.searchFocus.requestFocus();
    setState(() {
      _listening = true;
      _awaitingFinalResult = true;
      _pendingAutoSelect = false;
      _transcript = '';
      _speechError = null;
    });

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        if (!mounted) return;
        setState(() => _transcript = words);

        if (result.finalResult) {
          // Mark that the final result is received so _onSpeechStatus
          // doesn't interfere from this point on.
          _awaitingFinalResult = false;

          if (words.isNotEmpty) {
            // Explicitly set text in the search field and keep focus so the
            // controller triggers a search (via its internal _onQueryChanged).
            _mapsController.searchText.text = words;
            _mapsController.searchFocus.requestFocus();

            setState(() {
              _listening = false;
              _pendingAutoSelect = true;
            });

            _scheduleAutoSelect(words);
          } else {
            setState(() => _listening = false);
          }
        } else {
          // Partial result: feed the field live so search runs while speaking.
          _mapsController.searchText.text = words;
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  /// True while we're waiting for search results to arrive after speech
  /// finished, before auto-selecting. Keeps the transcription card visible.
  bool _pendingAutoSelect = false;

  Timer? _autoSelectTimer;

  void _scheduleAutoSelect(String transcript) {
    _autoSelectTimer?.cancel();
    var attempts = 0;
    // Poll every 200ms for faster responsiveness. The search debounce is
    // 350ms so results typically arrive by attempt 2–3.
    _autoSelectTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      attempts++;
      if (!mounted) {
        timer.cancel();
        return;
      }

      final results = _mapsController.results;

      // If results arrived and search is not loading, try matching.
      if (results.isNotEmpty && !_mapsController.loading) {
        timer.cancel();
        _tryFuzzyAutoSelect(transcript, results);
        return;
      }

      // Give up after 4s (20 attempts × 200ms). Dismiss processing state.
      if (attempts >= 20) {
        timer.cancel();
        if (mounted) {
          setState(() => _pendingAutoSelect = false);
        }
      }
    });
  }

  /// Fuzzy-matches the speech [transcript] against [results] and auto-selects
  /// the best match. Scoring includes exact match, containment, word overlap,
  /// and acronym matching (e.g. "NU" → "National University").
  void _tryFuzzyAutoSelect(String transcript, List<PlaceResult> results) {
    final query = _normalize(transcript);
    if (query.isEmpty) {
      if (mounted) setState(() => _pendingAutoSelect = false);
      return;
    }

    final queryWords = query.split(RegExp(r'\s+')).toSet();
    PlaceResult? bestMatch;
    double bestScore = 0;

    for (var i = 0; i < results.length; i++) {
      final name = _normalize(results[i].name);
      if (name.isEmpty) continue;

      double score = _computeMatchScore(query, queryWords, name);

      // Boost first results (Mapbox relevance/popularity ranking).
      if (i == 0) {
        score += 0.15;
      } else if (i == 1) {
        score += 0.05;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = results[i];
      }
    }

    // Clear the processing state.
    if (mounted) setState(() => _pendingAutoSelect = false);

    // Threshold: 0.3 — lenient since Mapbox results are already contextually
    // relevant to the query. The first-result boost means even a weak word
    // match on the top result will clear this bar.
    if (bestMatch != null && bestScore >= 0.3) {
      _mapsController.selectResult(bestMatch);
    }
  }

  /// Computes a match score between a [query] and a place [name].
  /// Handles exact match, containment, word overlap, and acronym matching.
  double _computeMatchScore(String query, Set<String> queryWords, String name) {
    // Exact match
    if (name == query) return 1.0;

    // Query contains the place name or vice versa
    if (name.contains(query) || query.contains(name)) return 0.85;

    final nameWords = name.split(RegExp(r'\s+')).toList();
    final nameWordsSet = nameWords.toSet();

    // Acronym match: check if the query is an acronym of the name words.
    // e.g. "nu" matches "national university", "ust" matches "university
    // of santo tomas" (skipping common words like "of", "the", "de").
    final acronymScore = _acronymScore(query, queryWords, nameWords);
    if (acronymScore > 0) return acronymScore;

    // Word overlap
    final overlap = queryWords.intersection(nameWordsSet).length;
    final maxWords =
        queryWords.length > nameWordsSet.length ? queryWords.length : nameWordsSet.length;
    if (maxWords > 0 && overlap > 0) {
      return overlap / maxWords * 0.75;
    }

    // Partial word match: check if any query word starts with or is the
    // start of any name word (handles partial speech like "intramur" for
    // "intramuros").
    for (final qw in queryWords) {
      for (final nw in nameWordsSet) {
        if (nw.startsWith(qw) || qw.startsWith(nw)) {
          return 0.6;
        }
      }
    }

    return 0;
  }

  /// Checks if the [query] could be an acronym for the [nameWords].
  /// Returns a score (0.9 for a match) or 0.
  /// Skips common filler words ("of", "the", "de", "ng", "sa").
  double _acronymScore(String query, Set<String> queryWords, List<String> nameWords) {
    // Only try acronym matching for short queries (1–6 chars, single word).
    if (queryWords.length != 1 || query.length > 6) return 0;

    const fillers = {'of', 'the', 'de', 'ng', 'sa', 'and', 'in', 'at', 'del'};

    // Build acronym from name words (skipping fillers).
    final significantWords = nameWords.where((w) => !fillers.contains(w)).toList();
    if (significantWords.length < 2) return 0;

    final acronym = significantWords.map((w) => w[0]).join();
    if (acronym == query) return 0.9;

    // Also try with ALL words (including fillers) for cases like DLSU.
    final fullAcronym = nameWords.map((w) => w[0]).join();
    if (fullAcronym == query) return 0.9;

    // Check if the query starts with the acronym or vice versa (partial).
    if (acronym.startsWith(query) || query.startsWith(acronym)) return 0.7;

    return 0;
  }

  /// Normalizes text for fuzzy comparison: lowercase, strip punctuation,
  /// collapse whitespace.
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    // 'done' / 'notListening' mean the engine stopped capturing.
    // Suppress if we're still waiting for the final result callback or
    // if we're in the auto-select processing phase.
    if (status == 'done' || status == 'notListening') {
      if (!_awaitingFinalResult && !_pendingAutoSelect) {
        setState(() => _listening = false);
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    _autoSelectTimer?.cancel();
    if (mounted) {
      setState(() {
        _listening = false;
        _pendingAutoSelect = false;
        _awaitingFinalResult = false;
        _speechError = null;
      });
    }
  }

  void _openFinderSearchGuide() async {
    final result = await showSearchGuide(context);
    if (result == null || !mounted) return;

    // Always fetch route steps for display.
    _wayFinderKey.currentState?.handleSearchResult(result);
  }

  final _wayFinderKey = GlobalKey<WayFinderTabState>();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topOffset = screenHeight * 0.07;
    final showSearchBar = _tabIndex == 0 || _tabIndex == 1;
    final isRoutesTab = _tabIndex == 1;
    final isMapsTab = _tabIndex == 0;

    final tabs = <Widget>[
      MapsTab(onMapReady: _handleMapReady, controller: _mapsController),
      RoutesTab(mode: _routeMode, active: isRoutesTab, wayFinderKey: _wayFinderKey),
      const HistoryTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      // Keep the map, info card and navbar fixed when the keyboard opens; the
      // keyboard overlays them instead of pushing the whole layout up.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: TabsTransition(index: _tabIndex, children: tabs),
          ),

          // Tap-away scrim: closes the search dropdown when tapping the map.
          // Search results / nearby places are exclusive to the Maps tab.
          if (isMapsTab)
            AnimatedBuilder(
              animation: _mapsController,
              builder: (context, _) {
                if (!_mapsController.resultsVisible) {
                  return const SizedBox.shrink();
                }
                return Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _mapsController.dismissResults,
                  ),
                );
              },
            ),

          // Search bar + mode toggle (Routes only) + results dropdown
          // (Maps/Routes only), revealed once the map is ready.
          if (showSearchBar)
            Positioned(
              top: topOffset,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !_mapReady,
                child: AnimatedOpacity(
                  opacity: _mapReady ? 1 : 0,
                  duration: _revealDuration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        // On Finder tab, intercept tap to open search guide.
                        onTap: (isRoutesTab && _routeMode == RouteMode.finder)
                            ? _openFinderSearchGuide
                            : null,
                        child: AbsorbPointer(
                          absorbing: isRoutesTab && _routeMode == RouteMode.finder,
                          child: LocationSearchBar(
                            controller: _mapsController.searchText,
                            focusNode: _mapsController.searchFocus,
                            onMicTap: _onMicTap,
                            micActive: _listening,
                            disabled: isRoutesTab && _routeMode == RouteMode.matrix,
                            showMic: !(isRoutesTab && _routeMode == RouteMode.finder),
                          ),
                        ),
                      ),
                      // Matrix/Finder toggle sits directly below the
                      // search bar, Routes tab only.
                      if (isRoutesTab) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: ModeToggle(
                            mode: _routeMode,
                            onChanged: (mode) =>
                                setState(() => _routeMode = mode),
                          ),
                        ),
                      ],
                      // Voice transcription + search results / nearby
                      // places are exclusive to the Maps tab.
                      if (isMapsTab && (_listening || _pendingAutoSelect || _speechError != null))
                        _TranscriptionCard(
                          transcript: _transcript,
                          listening: _listening,
                          processing: _pendingAutoSelect,
                          error: _speechError,
                          onStop: _stopListening,
                        )
                      else if (isMapsTab)
                        AnimatedBuilder(
                          animation: _mapsController,
                          builder: (context, _) {
                            if (_mapsController.tracking) {
                              return _TrackingCards(
                                eta: _mapsController.etaToDestination ?? '—',
                                distance: _mapsController.distanceLabel,
                              );
                            }
                            if (!_mapsController.resultsVisible) {
                              return const SizedBox.shrink();
                            }
                            return SearchResultsDropdown(
                              results: _mapsController.results,
                              loading: _mapsController.loading,
                              showingNearby: _mapsController.showingNearby,
                              error: _mapsController.error,
                              onSelect: _mapsController.selectResult,
                              onHide: _mapsController.dismissResults,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Navbar, revealed together with the search bar.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: IgnorePointer(
                  ignoring: !_mapReady,
                  child: AnimatedOpacity(
                    opacity: _mapReady ? 1 : 0,
                    duration: _revealDuration,
                    child: NavBar(
                      currentIndex: _tabIndex,
                      onTap: (index) => setState(() => _tabIndex = index),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Skeleton overlay while the map initializes + locates the user.
          // Fades out on ready, then unmounts (disposing its shimmer tickers).
          if (_skeletonVisible)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _mapReady,
                child: AnimatedOpacity(
                  opacity: _mapReady ? 0 : 1,
                  duration: _revealDuration,
                  onEnd: () {
                    if (_mapReady && mounted) {
                      setState(() => _skeletonVisible = false);
                    }
                  },
                  child: ShimmerProvider(
                    child: _HomeSkeleton(topOffset: topOffset),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Skeleton layout shown while the home shell loads: a full-screen map
/// placeholder with search-bar and navbar placeholders in their real spots.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.topOffset});

  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: SkeletonBox(borderRadius: 0)),
        Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: const SkeletonBox(
            width: double.infinity,
            height: 52,
            borderRadius: 26,
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: const SkeletonBox(
                width: double.infinity,
                height: 60,
                borderRadius: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ETA + Distance cards shown below the search bar when tracking a confirmed
/// destination. Compact green pills matching the app's design language.
class _TrackingCards extends StatelessWidget {
  const _TrackingCards({required this.eta, required this.distance});

  final String eta;
  final String distance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: _TrackingPill(label: 'ETA', value: eta)),
          const SizedBox(width: 10),
          Expanded(child: _TrackingPill(label: 'Distance', value: distance)),
        ],
      ),
    );
  }
}

class _TrackingPill extends StatelessWidget {
  const _TrackingPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.0,
              color: AppColors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Card shown beneath the search bar while dictating: holds the live
/// speech-to-text transcription (or an error), with a stop control.
class _TranscriptionCard extends StatelessWidget {
  const _TranscriptionCard({
    required this.transcript,
    required this.listening,
    required this.onStop,
    this.processing = false,
    this.error,
  });

  final String transcript;
  final bool listening;
  final bool processing;
  final String? error;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;

    final String statusText;
    if (hasError) {
      statusText = 'Voice search';
    } else if (listening) {
      statusText = 'Listening…';
    } else if (processing) {
      statusText = 'Searching…';
    } else {
      statusText = 'Tap the mic to speak';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasError ? Icons.mic_off_rounded : (processing ? Icons.search_rounded : Icons.mic_rounded),
            color: hasError ? AppColors.error : AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: hasError ? AppColors.error : AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasError
                      ? error!
                      : (transcript.isEmpty
                          ? 'Say a place or address…'
                          : transcript),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: transcript.isEmpty && !hasError
                        ? AppColors.hintGrey
                        : AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onStop,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.close_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}