import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';

class StoryEditorScreen extends StatefulWidget {
  final File file;
  final String type;

  const StoryEditorScreen({super.key, required this.file, required this.type});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  VideoPlayerController? _videoController;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  DateTime? _scheduledTime;
  
  // Overlays (Text/Stickers)
  final List<Map<String, dynamic>> _overlays = [];

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) => setState(() {}))
        ..setLooping(true)
        ..play();
    }
  }

  void _addOverlay(String type) {
    TextEditingController textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(type == 'text' ? "Add Text" : "Add Emoji", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(hintText: type == 'text' ? "Type here..." : "😀", hintStyle: const TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (textCtrl.text.isNotEmpty) {
                setState(() {
                  _overlays.add({
                    'text': textCtrl.text,
                    'offset': const Offset(100, 200),
                    'color': Colors.white,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  void _pickSchedule() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _scheduledTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  void _shareStory() async {
    setState(() => _isUploading = true);
    try {
      // Append overlay text to description since we can't burn it into the image yet
      String fullDescription = _captionController.text.trim();
      if (_overlays.isNotEmpty) {
        fullDescription += "\n\n[Overlays]: ${_overlays.map((o) => o['text']).join(", ")}";
      }

      String? url = await CloudinaryService().uploadFile(
        widget.file, 
        type: widget.type,
        onProgress: (count, total) {
          setState(() => _uploadProgress = count / total);
        },
      );
      if (url != null) {
        await DatabaseService().uploadStory(
          url, 
          widget.type, 
          description: fullDescription,
          scheduledTime: _scheduledTime
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Upload Failed: $e"),
        backgroundColor: Colors.redAccent,
        action: SnackBarAction(label: "Retry", textColor: Colors.white, onPressed: _shareStory),
      ));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Media Preview
          Center(
            child: widget.type == 'image'
                ? Image.file(widget.file, fit: BoxFit.contain)
                : (_videoController?.value.isInitialized ?? false
                    ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                    : const CircularProgressIndicator()),
          ),

          // 2. Draggable Overlays
          ..._overlays.asMap().entries.map((entry) {
            int idx = entry.key;
            var data = entry.value;
            return Positioned(
              left: data['offset'].dx,
              top: data['offset'].dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _overlays[idx]['offset'] += details.delta;
                  });
                },
                onLongPress: () => setState(() => _overlays.removeAt(idx)),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: Text(data['text'], style: TextStyle(color: data['color'], fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          }),

          // 3. Top Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.text_fields, color: Colors.white), onPressed: () => _addOverlay('text')),
                      IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white), onPressed: () => _addOverlay('sticker')),
                      IconButton(
                        icon: Icon(Icons.calendar_month, color: _scheduledTime != null ? Colors.greenAccent : Colors.white), 
                        onPressed: _pickSchedule
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Controls (Caption & Post)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20,
            child: Column(
              children: [
                if (_scheduledTime != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text("Scheduled for: ${_scheduledTime.toString().substring(0, 16)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                        child: TextField(
                          controller: _captionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(hintText: "Add a caption...", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isUploading ? null : _shareStory,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: _isUploading 
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _uploadProgress,
                                  color: Colors.purpleAccent,
                                  backgroundColor: Colors.black12,
                                ),
                                Text(
                                  "${(_uploadProgress * 100).toStringAsFixed(0)}%",
                                  style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : const Icon(Icons.arrow_forward, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }
}