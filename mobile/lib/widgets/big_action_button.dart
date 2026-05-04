import 'package:flutter/material.dart';

class BigActionButton extends StatelessWidget {
  final String label;
  final String? urduLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const BigActionButton({
    super.key,
    required this.label,
    this.urduLabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.9),
                      ),
                    ),
                    if (urduLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        urduLabel!,
                        style: TextStyle(
                          fontSize: 14,
                          color: color.withOpacity(0.6),
                          fontFamily: 'NotoNastaliqUrdu',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.4), size: 20),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
