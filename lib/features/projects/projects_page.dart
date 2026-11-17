import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../shared/widgets/empty_state.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navProjects)),
      body: const EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Henüz proje yok',
        message:
            'Proje oluşturma ve cihazda saklama sonraki sprintte '
            'eklenecek.',
      ),
    );
  }
}
