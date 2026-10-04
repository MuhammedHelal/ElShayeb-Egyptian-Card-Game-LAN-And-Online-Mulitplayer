import 'package:flutter/widgets.dart';

class AppResumeListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onInitial;
  final VoidCallback onResume;

  const AppResumeListener({
    super.key,
    required this.child,
    required this.onInitial,
    required this.onResume,
  });

  @override
  State<AppResumeListener> createState() => _AppResumeListenerState();
}

class _AppResumeListenerState extends State<AppResumeListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInitial();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
