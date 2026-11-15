import 'package:flutter/material.dart';
import '../../../data/models/mascot_model.dart';
import 'mascot_painter.dart';

class MascotView extends StatefulWidget {
  final MascotModel mascot;
  final double size;
  final bool showSpeechBubble;
  final VoidCallback? onTap;

  const MascotView({
    super.key,
    required this.mascot,
    this.size = 140,
    this.showSpeechBubble = false,
    this.onTap,
  });

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Zıplama efekti
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showSpeechBubble) ...[
            _buildSpeechBubble(context),
            const SizedBox(height: 6),
          ],
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: MascotPainter(
                  mood: widget.mascot.mood,
                  hatId: widget.mascot.equippedHatId,
                  costumeId: widget.mascot.equippedCostumeId,
                  toolId: widget.mascot.equippedToolId,
                  animationValue: _controller.value,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: widget.mascot.mood == MascotMood.dirtyMicrobes
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.blueAccent.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.mascot.mood == MascotMood.dirtyMicrobes ? '🦠 ' : '✨ ',
            style: const TextStyle(fontSize: 14),
          ),
          Flexible(
            child: Text(
              widget.mascot.moodMessage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
