/// Presentation Layer - Game Screen
///
/// Main in-game screen with table, cards, and player interactions.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/cubits.dart';
import '../widgets/widgets.dart';

/// Main game screen for the LAN game controller.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameUiState>(
      builder: (context, state) {
        context.locale;
        final cubit = context.read<GameCubit>();
        return GameScreenView(
          state: state,
          connectionInfo: cubit.connectionInfo,
          content: GameContent(state: state),
          onLeave: cubit.leaveGame,
          onShuffle: cubit.shuffleHand,
          onCardTap: cubit.selectCard,
        );
      },
    );
  }
}
