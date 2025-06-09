import 'package:flutter/material.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final String? message;

  const CustomLoadingIndicator({
    Key? key,
    this.size = 40.0,
    this.color,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? const Color.fromARGB(255, 85, 21, 1),
              ),
              strokeWidth: 3.0,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: color ?? const Color.fromARGB(255, 85, 21, 1),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 