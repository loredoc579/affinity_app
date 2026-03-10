import 'package:flutter/material.dart';

class PreferencesWrap extends StatelessWidget {
  final String? relGoal;
  final String? relType;

  const PreferencesWrap({
    Key? key, 
    this.relGoal, 
    this.relType,
  }) : super(key: key);

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (relGoal == null && relType == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          if (relGoal != null && relGoal!.isNotEmpty) 
            _buildInfoChip(Icons.track_changes, relGoal!),
          
          if (relType != null && relType!.isNotEmpty) 
            _buildInfoChip(Icons.people_alt_outlined, relType!),
        ],
      ),
    );
  }
}