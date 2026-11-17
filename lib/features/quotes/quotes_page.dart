import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../shared/widgets/empty_state.dart';

class QuotesPage extends StatelessWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.quotesTitle)),
      body: const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'Henüz teklif yok',
        message: 'Fiyat teklifi hazırlama sonraki sprintlerde eklenecek.',
      ),
    );
  }
}
