import 'package:flutter/material.dart';

import '../widgets/summary_records_view.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return SummaryRecordsView(
      favoritesOnly: true,
      onChanged: onChanged,
    );
  }
}
