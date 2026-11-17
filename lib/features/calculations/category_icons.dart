import 'package:material_ui/material_ui.dart';

/// Kategori kimliği → ikon eşlemesi (arayüz katmanına aittir).
IconData categoryIcon(String categoryId) => switch (categoryId) {
  'marble_granite' => Icons.layers_outlined,
  'ceramic_tile' => Icons.grid_view_outlined,
  'furniture_carpentry' => Icons.chair_outlined,
  'glass_aluminium' => Icons.window_outlined,
  'pvc_joinery' => Icons.sensor_door_outlined,
  'iron_joinery' => Icons.fence_outlined,
  'paint' => Icons.format_paint_outlined,
  'construction_renovation' => Icons.construction_outlined,
  'electrical' => Icons.electrical_services_outlined,
  'plumbing' => Icons.plumbing_outlined,
  'drywall_decoration' => Icons.view_quilt_outlined,
  'roof_insulation' => Icons.roofing_outlined,
  'custom_manual' => Icons.straighten_outlined,
  _ => Icons.calculate_outlined,
};
