import 'package:flutter/material.dart';

/// Un AppBar “personalizzato” che riceve
/// una callback per aprire il filter sheet.
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onFilterTap;
  final bool? autoimplyLeading;

  const HomeAppBar({Key? key, this.autoimplyLeading, required this.onFilterTap}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: autoimplyLeading ?? true,
      title: const Text('Affinity'),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: onFilterTap,  // chiama _showFilters di HomeScreen
        ),
      ],
    );
  }
}
