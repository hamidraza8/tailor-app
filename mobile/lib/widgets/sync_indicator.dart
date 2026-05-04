import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final isOnline = provider.isOnline;
        final pending = provider.pendingSyncCount;
        final isSyncing = provider.isSyncing;

        Color bgColor;
        String text;
        IconData icon;

        if (!isOnline) {
          bgColor = AppColors.warning;
          text = 'Offline - changes saved locally';
          icon = Icons.cloud_off;
        } else if (isSyncing) {
          bgColor = AppColors.blue;
          text = 'Syncing...';
          icon = Icons.sync;
        } else if (pending > 0) {
          bgColor = AppColors.orange;
          text = '$pending item${pending > 1 ? 's' : ''} pending sync';
          icon = Icons.cloud_upload;
        } else {
          bgColor = AppColors.success;
          text = 'All synced';
          icon = Icons.cloud_done;
        }

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/sync-status'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.1),
              border: Border(top: BorderSide(color: bgColor.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: bgColor,
                    ),
                  )
                else
                  Icon(icon, size: 16, color: bgColor),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: bgColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
