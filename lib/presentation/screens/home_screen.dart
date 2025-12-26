/// Presentation Layer - Home Screen
///
/// Main menu with mode selection and navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/cubits.dart';
import '../theme/app_theme.dart';
import 'lobby_screen.dart';
import 'settings_screen.dart';

/// Home screen with game mode selection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.tableGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: TablePatternPainter(),
                ),
              ),

              // Main content
              Column(
                children: [
                  // App bar with settings
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => _openSettings(context),
                          icon: const Icon(Icons.settings),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Logo and title
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'الشايب',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  '♠ ♥ ♣ ♦',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'El-Shayeb',
                          style: AppTypography.displayLarge.copyWith(
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Egyptian Card Game',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Game mode buttons
                  SlideTransition(
                    position: _slideUp,
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            // LAN Mode
                            _GameModeButton(
                              icon: Icons.wifi,
                              title: 'Local Wi-Fi',
                              subtitle: 'Play with friends on the same network',
                              onTap: () => _startGame(context, GameMode.lan),
                            ),

                            const SizedBox(height: 16),

                            // Online Mode
                            _GameModeButton(
                              icon: Icons.public,
                              title: 'Online',
                              subtitle: 'Play with anyone, anywhere',
                              onTap: () => _startGame(context, GameMode.online),
                              isSecondary: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Version info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'v1.0.0',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    context.read<GameCubit>().setGameMode(mode);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LobbyScreen(),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}

/// Game mode selection button
class _GameModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSecondary;

  const _GameModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isSecondary
                ? null
                : const LinearGradient(
                    colors: [
                      AppColors.secondary,
                      AppColors.secondaryDark,
                    ],
                  ),
            color: isSecondary ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(16),
            border: isSecondary
                ? Border.all(color: AppColors.secondary, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: (isSecondary ? AppColors.surface : AppColors.secondary)
                    .withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSecondary
                      ? AppColors.secondary.withOpacity(0.2)
                      : Colors.white.withOpacity(0.2),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isSecondary ? AppColors.secondary : AppColors.textDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(
                        color: isSecondary
                            ? AppColors.textPrimary
                            : AppColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSecondary
                            ? AppColors.textSecondary
                            : AppColors.textDark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isSecondary ? AppColors.secondary : AppColors.textDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for table background pattern
class TablePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // Diamond pattern
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final path = Path()
          ..moveTo(x + spacing / 2, y)
          ..lineTo(x + spacing, y + spacing / 2)
          ..lineTo(x + spacing / 2, y + spacing)
          ..lineTo(x, y + spacing / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
