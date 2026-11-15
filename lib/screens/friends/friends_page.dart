import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_theme.dart';

/// Do'stlar sahifasi: guruhlar ro'yxati → guruh tafsilotlari → a'zo tafsilotlari.
/// API hali ulanmagan — placeholder UI (Mini App strukturasiga mos).
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  String _view = 'list'; // list | group | member

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: switch (_view) {
        'group' => _GroupDetailView(
            onBack: () => setState(() => _view = 'list'),
            onMember: () => setState(() => _view = 'member'),
          ),
        'member' => _MemberDetailView(
            onBack: () => setState(() => _view = 'group'),
          ),
        _ => _GroupsListView(
            onGroup: () => setState(() => _view = 'group'),
          ),
      },
    );
  }
}

class _GroupsListView extends StatelessWidget {
  const _GroupsListView({required this.onGroup});
  final VoidCallback onGroup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          "Do'stlar 👥",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          "Jamoa bo'lib intizom yig'ing",
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),

        // Placeholder: empty groups
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Text('👥', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(
                "Hozircha guruhlar yo'q",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Guruh yarating va do'stlaringizni taklif qiling",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),

        // Create group button
        GestureDetector(
          onTap: () => _showCreateGroup(context),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, AppPalette.accent]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Yangi guruh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateGroup(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Yangi guruh', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Guruh nomi',
                hintText: 'Masalan: Oila / Ish jamoasi',
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Tavsif (ixtiyoriy)',
                hintText: "Guruh haqida bir necha so'z",
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Bekor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Yaratish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailView extends StatelessWidget {
  const _GroupDetailView({required this.onBack, required this.onMember});
  final VoidCallback onBack;
  final VoidCallback onMember;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                'Guruh',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.ellipsisVertical),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.link, size: 16),
                label: const Text("Do'st taklif qilish"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.shield, size: 16),
                label: const Text('Ruxsatlar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          "A'zolar yo'q",
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MemberDetailView extends StatelessWidget {
  const _MemberDetailView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                "A'zo",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "A'zo ma'lumotlari bu yerda ko'rsatiladi",
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
