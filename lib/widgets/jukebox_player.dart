import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class JukeboxPlayer extends StatefulWidget {
  final String? currentVideoId;
  final String? currentTitle;
  final List<Map<String, dynamic>> queue;
  final bool isHost;
  final Function(String id, String title) onAddSong;
  final VoidCallback onSongEnded;

  const JukeboxPlayer({
    Key? key,
    required this.currentVideoId,
    this.currentTitle,
    required this.queue,
    required this.isHost,
    required this.onAddSong,
    required this.onSongEnded,
  }) : super(key: key);

  @override
  _JukeboxPlayerState createState() => _JukeboxPlayerState();
}

class _JukeboxPlayerState extends State<JukeboxPlayer> {
  YoutubePlayerController? _controller;
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentVideoId != null) {
      _initController(widget.currentVideoId!);
    }
  }

  @override
  void didUpdateWidget(JukeboxPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentVideoId != oldWidget.currentVideoId) {
      if (widget.currentVideoId != null) {
        // Song changed or started
        if (_controller == null) {
          _initController(widget.currentVideoId!);
        } else {
          _controller!.load(widget.currentVideoId!);
        }
        Future.delayed(const Duration(milliseconds: 300), _forcePlay);
      } else {
        // Song removed/stopped
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  void _initController(String id) {
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true, // Hides YouTube's buttons for a mini look
        enableCaption: false,
        isLive: false,
        forceHD: false,
        loop: false,
      ),
    )..addListener(_listener);
    setState(() {});
  }

  void _listener() {
    if (_controller == null || !mounted) return;

    // Update local playing state for the UI button
    if (_controller!.value.isPlaying != _isPlaying) {
      setState(() => _isPlaying = _controller!.value.isPlaying);
    }

    // HOST LOGIC: Detect end
    if (widget.isHost && _controller!.value.playerState == PlayerState.ended) {
       widget.onSongEnded();
    }
  }

  void _forcePlay() {
    if (_controller == null) return;
    _controller!.play();
    if (!_controller!.value.isPlaying) {
      _controller!.mute();
      _controller!.play();
      Future.delayed(const Duration(seconds: 1), () => _controller!.unMute());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener);
    _controller?.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show controls if we have a song ID AND the controller is ready
    bool hasSong = widget.currentVideoId != null && _controller != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
        boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))]
      ),
      child: Row(
        children: [
          // 1. ALBUM ART ICON
          GestureDetector(
            onTap: _showJukeboxPanel,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5))
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
                    widget.currentVideoId != null ? "${widget.queue.length} up next" : "Tap to add songs",
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

          // 3. CONTROLS & VIDEO (Grouped together to prevent crash)
          if (hasSong) ...[
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
              color: Colors.white,
              iconSize: 32,
              onPressed: () {
                if (_isPlaying) {
                  _controller?.pause();
                } else {
                  _forcePlay();
                }
              },
            ),
            
            // The Mini Player
            Container(
              width: 120, // Slightly smaller width for mini look
              height: 68,
              margin: const EdgeInsets.only(left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),

                  child: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: false,
                    onReady: () {
                    // Slight delay ensures the view is attached before playing
                    Future.delayed(const Duration(milliseconds: 500), _forcePlay);
                  },
                  ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- EXISTING METHODS (No changes needed below here) ---
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10))
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search song title...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) _performSearch(val);
                  },
                ),
              ),
              Expanded(
                child: widget.queue.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.playlist_add, size: 48, color: Colors.white24),
                          SizedBox(height: 10),
                          Text("Queue is empty.", style: TextStyle(color: Colors.white38)),
                          Text("Search to add a song!", style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: widget.queue.length,
                      itemBuilder: (context, index) {
                        final song = widget.queue[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Text("${index + 1}", style: const TextStyle(color: Colors.white70)),
                          ),
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

  Future<void> _performSearch(String query) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
    );
    
    try {
      var results = await _yt.search.search(query);
      Navigator.pop(context); 

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No results found.")));
        return;
      }

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
              itemCount: results.take(10).length,
              itemBuilder: (context, index) {
                var video = results.elementAt(index);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(video.thumbnails.lowResUrl, width: 50, fit: BoxFit.cover),
                  ),
                  title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(video.author, style: const TextStyle(color: Colors.white54)),
                  onTap: () {
                    widget.onAddSong(video.id.value, video.title);
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added '${video.title}' to Queue!")));
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      print("Search Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error searching. Try again.")));
    }
  }
}