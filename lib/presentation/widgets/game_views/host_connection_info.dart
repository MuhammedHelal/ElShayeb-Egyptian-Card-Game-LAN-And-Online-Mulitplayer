/// Presentation Layer - Game Widgets - Host Connection Info
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../../core/localization/localization_service.dart';

// Connection info shown to host in lobby
class HostConnectionInfo extends StatelessWidget {
  final bool isLan;
  final String connectionInfo;
  final String roomCode;

  const HostConnectionInfo({
    super.key,
    required this.isLan,
    required this.connectionInfo,
    required this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            isLan ? AppStrings.gameShareAddress : AppStrings.gameShareCode,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (isLan) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectionInfo,
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.secondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              roomCode,
              style: AppTypography.displayMedium.copyWith(
                color: AppColors.secondary,
                letterSpacing: 4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _copyConnectionInfo(context),
            icon: const Icon(Icons.copy, size: 16),
            label: Text(AppStrings.lobbyCopy),
          ),
        ],
      ),
    );
  }

  void _copyConnectionInfo(BuildContext context) {
    final textToCopy = isLan ? connectionInfo : roomCode;
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.gameCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
