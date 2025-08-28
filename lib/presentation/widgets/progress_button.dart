import 'package:flutter/material.dart';

/// Progress Button Widget that fills from left to right based on progress
class ProgressButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final double progress; // 0.0 to 1.0
  final bool isEnabled;
  final Color color;
  final Size minimumSize;
  final EdgeInsets padding;

  const ProgressButton({
    super.key,
    required this.text,
    required this.icon,
    this.onPressed,
    this.progress = 0.0,
    this.isEnabled = true,
    this.color = Colors.blue,
    this.minimumSize = const Size(90, 36),
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidth = minimumSize.width;
    final buttonHeight = minimumSize.height;
    
    return Container(
      width: buttonWidth,
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: color.withOpacity(0.1),
            ),
          ),
          // Progress fill (from left to right)
          if (!isEnabled && progress > 0 && progress < 1.0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: (buttonWidth - 2) * progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: color.withOpacity(0.6),
                ),
              ),
            ),
          // Full color when ready/enabled
          if (isEnabled)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: color,
              ),
            ),
          // Button content
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(3),
              onTap: isEnabled ? onPressed : null,
              child: Container(
                padding: padding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: _getContentColor(),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getContentColor(),
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getContentColor() {
    if (isEnabled) {
      return Colors.white;
    } else if (progress > 0) {
      return Colors.white.withOpacity(0.9);
    } else {
      return Colors.white.withOpacity(0.7);
    }
  }
}