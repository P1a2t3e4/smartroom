import 'package:flutter/material.dart';

class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task: Clean the common room', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text('Deadline: 2023-10-15'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Mark task as complete
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task marked as complete!')),
                );
              },
              child: Text('Mark as Complete'),
            ),
          ],
        ),
      ),
    );
  }
}