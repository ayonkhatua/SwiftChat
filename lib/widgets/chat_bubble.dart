import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String type; // 'text' or 'image'
  final Gradient? gradient; // 🟢 Premium Gradient Support

  const ChatBubble({
    super.key, 
    required this.text, 
    required this.isMe,
    this.type = 'text',
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        // Margin thoda kam kiya taaki messages paas-paas dikhein (Instagram style)
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: type == 'image' 
            ? const EdgeInsets.all(4) 
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        
        decoration: BoxDecoration(
          gradient: (isMe && gradient != null && type == 'text') ? gradient : null,
          color: (isMe && gradient != null) ? null : ((type == 'image' || type == 'video') ? Colors.transparent : (isMe ? Colors.purpleAccent.withOpacity(0.2) : Colors.grey[900])),
          border: (type == 'image' || type == 'video') ? null : Border.all(
            color: isMe ? Colors.purpleAccent : Colors.grey[800]!,
            width: 1,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            // Jo side message hai wahan curve thoda kam (Chat Flow look)
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: isMe
              ? [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 6)]
              : [],
        ),
        
        child: type == 'image'
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: text,
                  width: 200,
                  height: 250,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 200, height: 250,
                    child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                  ),
                  errorWidget: (context, url, error) => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54),
                      SizedBox(height: 4),
                      Text("Image Error", style: TextStyle(color: Colors.white24, fontSize: 10))
                    ],
                  ),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 16,
                  fontWeight: FontWeight.w400
                ),
              ),
      ),
    );
  }
}