import 'package:flutter/material.dart';

import '../widgets/summary_records_view.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return SummaryRecordsView(
      favoritesOnly: false,
      onChanged: onChanged,
    );
  }
}
