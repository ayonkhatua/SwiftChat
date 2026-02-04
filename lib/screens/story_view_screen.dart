import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/database_service.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewScreen({super.key, required this.stories, required this.initialIndex});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late PageController _pageController;
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _replyController = TextEditingController();
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initMedia();
  }

  void _initMedia() {
    _timer?.cancel();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;
    
    var story = widget.stories[_currentIndex];
    if (story['type'] == 'video') {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(story['url']))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController!.play();
            _videoController!.addListener(_videoListener);
          }
        });
    } else {
      _timer = Timer(const Duration(seconds: 5), _nextPage);
    }
  }

  void _videoListener() {
    if (_videoController != null && 
        _videoController!.value.position >= _videoController!.value.duration) {
      _videoController!.removeListener(_videoListener);
      _nextPage();
    }
  }

  void _nextPage() {
    if (!mounted) return;
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _replyController.dispose();
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _initMedia();
  }

  void _sendReply() async {
    String text = _replyController.text.trim();
    if (text.isEmpty) return;

    var story = widget.stories[_currentIndex];
    await _dbService.replyToStory(
      story['uid'], 
      text, 
      story['url'], 
      story['id'] ?? "", 
      story['expiresAt']
    );

    _replyController.clear();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reply sent!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Story Content
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.stories.length,
            itemBuilder: (context, index) {
              var story = widget.stories[index];
              return Center(
                child: story['type'] == 'image'
                    ? CachedNetworkImage(
                        imageUrl: story['url'],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const CircularProgressIndicator(color: Colors.purpleAccent),
                      )
                    : (_videoController != null && _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(color: Colors.purpleAccent)),
              );
            },
          ),

          // 2. Top Progress Bars & Info
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: List.generate(widget.stories.length, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            color: index <= _currentIndex ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: widget.stories[_currentIndex]['profile_pic'] != null 
                            ? CachedNetworkImageProvider(widget.stories[_currentIndex]['profile_pic']) 
                            : null,
                        child: widget.stories[_currentIndex]['profile_pic'] == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.stories[_currentIndex]['username'] ?? "User",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Reply Bar
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Send message...",
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}