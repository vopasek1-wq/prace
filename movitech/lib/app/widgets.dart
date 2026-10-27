import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../features/auth/domain/app_user.dart';

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        S.demoBanner,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

const _avatarColors = [
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFEF6C00),
  Color(0xFF8E24AA),
  Color(0xFF3949AB),
  Color(0xFF00897B),
];

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 16});

  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final color = _avatarColors[(u?.uid.hashCode ?? 0).abs() % _avatarColors.length];
    final photo = u?.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: photo == null ? null : NetworkImage(photo),
      onForegroundImageError: photo == null ? null : (_, _) {},
      child: Text(
        u?.initial ?? '?',
        style: TextStyle(color: Colors.white, fontSize: radius * 0.9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text(S.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
