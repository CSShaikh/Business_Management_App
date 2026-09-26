import 'package:flutter/material.dart';

/// Prevents an accidental app exit when Android Back is pressed on a root
/// screen while still allowing normal child-route navigation.
///
/// The guard deliberately does not replace the platform back stack. If the
/// current Navigator can pop, the route is allowed to pop normally. If it is
/// already at its root, the back action is consumed and a small message is
/// shown instead of closing the application.
class AppBackGuard extends StatelessWidget {
  const AppBackGuard({
    super.key,
    required this.child,
    this.message = 'You are already on the first screen.',
  });

  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    final NavigatorState? navigator = Navigator.maybeOf(context);
    final bool canPop = navigator?.canPop() ?? false;

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || canPop || !context.mounted) {
          return;
        }

        final ScaffoldMessengerState? messenger =
            ScaffoldMessenger.maybeOf(context);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1200),
            ),
          );
      },
      child: child,
    );
  }
}
