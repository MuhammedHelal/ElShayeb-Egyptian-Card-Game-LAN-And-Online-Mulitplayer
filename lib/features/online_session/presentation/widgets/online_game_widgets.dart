import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../presentation/theme/app_theme.dart';
import '../../domain/entities/online_lobby.dart';

/// Online-only connection status. The game UI itself is shared with LAN mode.
class OnlineConnectionChip extends StatelessWidget {
  final OnlineServerConnectionStatus status;
  final VoidCallback? onReconnect;

  const OnlineConnectionChip({
    super.key,
    required this.status,
    this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      OnlineServerConnectionStatus.disconnected => (
          'online_status_disconnected'.tr(),
          AppColors.textSecondary,
          Icons.cloud_off,
        ),
      OnlineServerConnectionStatus.connecting => (
          'online_status_connecting'.tr(),
          AppColors.info,
          Icons.cloud_sync,
        ),
      OnlineServerConnectionStatus.authenticating => (
          'online_status_authenticating'.tr(),
          AppColors.warning,
          Icons.verified_user_outlined,
        ),
      OnlineServerConnectionStatus.connected => (
          'online_status_connected'.tr(),
          AppColors.success,
          Icons.cloud_done,
        ),
      OnlineServerConnectionStatus.reconnecting => (
          'online_status_reconnecting'.tr(),
          AppColors.warning,
          Icons.sync,
        ),
    };

    return Semantics(
      button: onReconnect != null,
      label: label,
      hint: onReconnect == null ? null : 'online_tap_to_reconnect'.tr(),
      child: Tooltip(
        message: onReconnect == null
            ? 'online_room_connection_ok'.tr()
            : 'online_tap_to_reconnect'.tr(),
        child: InkWell(
          onTap: onReconnect,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnlineActionErrorBanner extends StatelessWidget {
  final String message;

  const OnlineActionErrorBanner({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
