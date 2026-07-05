import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/animations/tabs_transitions.dart';
import '../../../core/navbar/navbar_widget.dart';
import '../../../core/skeleton_loading/skeleton_loading.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/search_bar.dart';
import 'tabs/history_tab/history_tab.dart';
import 'tabs/maps_tab/maps_controller.dart';
import 'tabs/maps_tab/maps_tab.dart';
import 'tabs/maps_tab/search_results_dropdown.dart';
import 'tabs/profile_tab/profile_tab.dart';
import 'tabs/routes_tab/routes_tab.dart';

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

class _HomeScreenState extends State<HomeScreen> {
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
    _mapsController = MapsController();
    // Safety net: reveal the UI even if the map never reports ready (e.g. no
    // network / stuck tiles) so the app is never stuck on the skeleton.
    _readyTimeout = Timer(const Duration(seconds: 8), _handleMapReady);
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    _mapsController.dispose();
    _speech.stop();
    super.dispose();
  }


  void _handleMapReady() {
    if (_mapReady || !mounted) return;
    _readyTimeout?.cancel();
    setState(() => _mapReady = true);
  }

  // ── Mic / voice search ─────────────────────────────────────────────────
  Future<void> _onMicTap() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (err) {
          if (mounted) {
            setState(() {
              _listening = false;
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
      _transcript = '';
      _speechError = null;
    });

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        if (!mounted) return;
        setState(() => _transcript = words);
        // Feed the field live so search runs while dictating.
        _mapsController.searchText.text = words;
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    // 'done' / 'notListening' mean the engine stopped capturing.
    if (status == 'done' || status == 'notListening') {
      setState(() => _listening = false);
    }
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) {
      setState(() {
        _listening = false;
        _speechError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topOffset = screenHeight * 0.07;
    final showSearchBar = _tabIndex == 0 || _tabIndex == 1;
    final isRoutesTab = _tabIndex == 1;
    final isMapsTab = _tabIndex == 0;

    final tabs = <Widget>[
      MapsTab(onMapReady: _handleMapReady, controller: _mapsController),
      RoutesTab(mode: _routeMode),
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
                  child: AnimatedBuilder(
                    animation: _mapsController,
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LocationSearchBar(
                            controller: _mapsController.searchText,
                            focusNode: _mapsController.searchFocus,
                            onMicTap: _onMicTap,
                            micActive: _listening,
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
                          if (isMapsTab && (_listening || _speechError != null))
                            _TranscriptionCard(
                              transcript: _transcript,
                              listening: _listening,
                              error: _speechError,
                              onStop: _stopListening,
                            )
                          else if (isMapsTab && _mapsController.resultsVisible)
                            SearchResultsDropdown(
                              results: _mapsController.results,
                              loading: _mapsController.loading,
                              showingNearby: _mapsController.showingNearby,
                              error: _mapsController.error,
                              onSelect: _mapsController.selectResult,
                              collapsed: _mapsController.resultsCollapsed,
                              onToggleCollapse: () =>
                                  _mapsController.resultsCollapsed
                                      ? _mapsController.expandResults()
                                      : _mapsController.collapseResults(),
                            ),
                        ],
                      );
                    },
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
                  child: _HomeSkeleton(topOffset: topOffset),
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

/// Card shown beneath the search bar while dictating: holds the live
/// speech-to-text transcription (or an error), with a stop control.
class _TranscriptionCard extends StatelessWidget {
  const _TranscriptionCard({
    required this.transcript,
    required this.listening,
    required this.onStop,
    this.error,
  });

  final String transcript;
  final bool listening;
  final String? error;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
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
            hasError ? Icons.mic_off_rounded : Icons.mic_rounded,
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
                  hasError
                      ? 'Voice search'
                      : (listening ? 'Listening…' : 'Tap the mic to speak'),
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