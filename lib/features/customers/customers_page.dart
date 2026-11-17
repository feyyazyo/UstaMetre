import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../shared/widgets/empty_state.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.customersTitle)),
      body: const EmptyState(
        icon: Icons.people_outline,
        title: 'Henüz müşteri yok',
        message: 'Müşteri kaydı sonraki sprintlerde eklenecek.',
      ),
    );
  }
}
