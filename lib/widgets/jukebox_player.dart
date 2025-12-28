import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;

class JukeboxPlayer extends StatefulWidget {
  final String? currentVideoId;
  final String? currentTitle;
  final List<Map<String, dynamic>> queue;
  final bool isHost;
  final Function(String id, String title) onAddSong;
  final VoidCallback onSongEnded;

  const JukeboxPlayer({
    super.key,
    required this.currentVideoId,
    this.currentTitle,
    required this.queue,
    required this.isHost,
    required this.onAddSong,
    required this.onSongEnded,
  });

  @override
  _JukeboxPlayerState createState() => _JukeboxPlayerState();
}

class _JukeboxPlayerState extends State<JukeboxPlayer> {
  late YoutubePlayerController _controller;
  final String _apiKey = "AIzaSyD-_PwgOoSKpp7u89tbLJdHQkIbqun9ANI"; 
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Initialize the IFrame Controller
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false, // Hide default controls for that "Jukebox" feel
        showFullscreenButton: false,
        strictRelatedVideos: true,
        pointerEvents: PointerEvents.none, // Disables touch on video to prevent stealing gestures
      ),
    );

    // If a song exists on load, cue it
    if (widget.currentVideoId != null) {
      _controller.loadVideoById(videoId: widget.currentVideoId!);
    }

    // Listen to state changes
    _controller.listen((event) {
      if (!mounted) return;
      
      // Update Play/Pause icon
      if (event.playerState == PlayerState.playing && !_isPlaying) {
        setState(() => _isPlaying = true);
      } else if (event.playerState != PlayerState.playing && _isPlaying) {
        setState(() => _isPlaying = false);
      }

      // HOST LOGIC: Detect end of song
      if (widget.isHost && event.playerState == PlayerState.ended) {
        widget.onSongEnded();
      }
    });
  }

  @override
  void didUpdateWidget(JukeboxPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle Song Changes
    if (widget.currentVideoId != oldWidget.currentVideoId) {
      if (widget.currentVideoId != null) {
        _controller.loadVideoById(videoId: widget.currentVideoId!);
      } else {
        _controller.stopVideo();
      }
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasSong = widget.currentVideoId != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
        boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          // 1. ALBUM ART ICON (Opens Search)
          GestureDetector(
            onTap: _showJukeboxPanel,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
              ),
              child: const Icon(Icons.queue_music, color: Colors.purpleAccent, size: 20),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 2. SONG INFO
          Expanded(
            child: GestureDetector(
              onTap: _showJukeboxPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.currentTitle ?? "Jukebox Idle",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hasSong ? "${widget.queue.length} up next" : "Tap to add songs",
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

          // 3. CONTROLS & MINI PLAYER
          if (hasSong) ...[
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
              color: Colors.white,
              iconSize: 32,
              onPressed: () async {
                final state = await _controller.playerState;
                if (state == PlayerState.playing) {
                  _controller.pauseVideo();
                } else {
                  _controller.playVideo();
                }
              },
            ),
            
            // The Mini Player (Hidden visuals but functional)
            Container(
              width: 80, 
              height: 45,
              margin: const EdgeInsets.only(left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // YoutubePlayer from 'youtube_player_iframe' package
                child: YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- SEARCH UI & LOGIC ---

  void _showJukeboxPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.music_note, color: Colors.purpleAccent),
                    SizedBox(width: 8),
                    Text("Shared Jukebox", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search YouTube (API)...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) _performSearchWithApi(val);
                  },
                ),
              ),
              // Queue List
              Expanded(
                child: widget.queue.isEmpty 
                  ? Center(
                      child: Text("Queue is empty.\nSearch to add music!", 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: widget.queue.length,
                      itemBuilder: (context, index) {
                        final song = widget.queue[index];
                        return ListTile(
                          leading: Text("${index + 1}", style: const TextStyle(color: Colors.white70)),
                          title: Text(song['title'] ?? "Unknown", style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.music_note, color: Colors.white24),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- NEW: OFFICIAL API SEARCH ---
  Future<void> _performSearchWithApi(String query) async {
    // 1. Loading UI
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
    );

    try {
      // 2. Call YouTube Data API
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=10&q=$query&type=video&key=$_apiKey'
      );
      
      final response = await http.get(url);
      
      // Close Loader
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        if (items.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No results found.")));
          return;
        }

        // 3. Show Results
        _showSearchResults(items);

      } else {
        print("API Error: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("API Error: ${response.statusCode}")));
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      print("Network Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error searching. Check internet.")));
    }
  }

  void _showSearchResults(List items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Song", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final video = items[index];
              final snippet = video['snippet'];
              final videoId = video['id']['videoId'];
              final title = snippet['title'];
              final thumb = snippet['thumbnails']['default']['url'];
              final channel = snippet['channelTitle'];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(thumb, width: 50, fit: BoxFit.cover),
                ),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                subtitle: Text(channel, style: const TextStyle(color: Colors.white54)),
                onTap: () {
                  widget.onAddSong(videoId, title);
                  Navigator.pop(context); // Close List
                  Navigator.pop(context); // Close Jukebox Panel
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added '$title' to Queue!")));
                },
              );
            },
          ),
        ),
      ),
    );
  }
}