import 'package:flutter/material.dart';
import '../presentation/home/my_membership_page/membership_form_page_screen.dart';

class MembershipRequiredDialog extends StatelessWidget {
  final BuildContext context;
  final String message;

  const MembershipRequiredDialog({
    Key? key,
    required this.context,
    this.message = 'A membership is required to access this feature.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Color.fromARGB(255, 85, 21, 1),
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Membership Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MembershipFormPageScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 85, 21, 1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Get Membership',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
} 