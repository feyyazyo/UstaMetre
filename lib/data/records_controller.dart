import 'package:material_ui/material_ui.dart';

import '../domain/records/customer.dart';
import '../domain/records/project.dart';
import '../domain/records/saved_calculation.dart';
import 'records_repository.dart';

/// Kayıtları (müşteri, proje, hesap) arayüze sunar. Veritabanı işlemleri
/// [RecordsRepository] içindedir; bu sınıf yalnızca durumu tutar ve
/// değişikliklerden sonra listeyi yeniler.
class RecordsController extends ChangeNotifier {
  RecordsController(this._repo);

  /// Veritabanı açılamadığında kullanılır; ekranlar hatayı gösterir, uygulama
  /// çökmez ve mevcut dosya silinmez.
  RecordsController.unavailable(this.error) : _repo = null;

  final RecordsRepository? _repo;
  String? error;

  RecordsSnapshot _snapshot = const RecordsSnapshot();
  bool _loaded = false;

  bool get isAvailable => _repo != null;
  bool get isLoaded => _loaded;
  List<Customer> get customers => _snapshot.customers;
  List<Project> get projects => _snapshot.projects;
  List<SavedCalculation> get calculations => _snapshot.calculations;
  List<CorruptRecord> get corrupt => _snapshot.corrupt;

  RecordsRepository get _r {
    final repo = _repo;
    if (repo == null) throw StateError(error ?? 'Kayıt deposu kullanılamıyor.');
    return repo;
  }

  Future<void> load() async {
    if (_repo == null) return;
    _snapshot = await _repo.loadAll();
    _loaded = true;
    notifyListeners();
  }

  Future<T> _mutate<T>(Future<T> Function(RecordsRepository r) action) async {
    final result = await action(_r);
    await load();
    return result;
  }

  // ---- sorgular

  Customer? customerById(String? id) =>
      id == null ? null : customers.where((c) => c.id == id).firstOrNull;

  Project? projectById(String? id) =>
      id == null ? null : projects.where((p) => p.id == id).firstOrNull;

  SavedCalculation? calculationById(String id) =>
      calculations.where((c) => c.id == id).firstOrNull;

  List<Project> projectsOf(String customerId) =>
      projects.where((p) => p.customerId == customerId).toList();

  List<SavedCalculation> calculationsOfProject(String projectId) =>
      calculations.where((c) => c.projectId == projectId).toList();

  /// Müşteriye doğrudan bağlı veya müşterinin projelerindeki hesaplar.
  List<SavedCalculation> calculationsOfCustomer(String customerId) {
    final projectIds = projectsOf(customerId).map((p) => p.id).toSet();
    return calculations
        .where(
          (c) => c.customerId == customerId || projectIds.contains(c.projectId),
        )
        .toList();
  }

  Future<List<CalcRevision>> revisions(String id) => _r.revisions(id);

  // ---- müşteriler

  Future<Customer> saveCustomer({
    String? id,
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String note = '',
  }) => _mutate(
    (r) => r.saveCustomer(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      note: note,
    ),
  );

  Future<void> deleteCustomer(String id) =>
      _mutate((r) => r.deleteCustomer(id));

  // ---- projeler

  Future<Project> saveProject({
    String? id,
    required String name,
    String? customerId,
    String location = '',
    String note = '',
    ProjectStatus status = ProjectStatus.preparing,
  }) => _mutate(
    (r) => r.saveProject(
      id: id,
      name: name,
      customerId: customerId,
      location: location,
      note: note,
      status: status,
    ),
  );

  Future<void> deleteProject(String id) => _mutate((r) => r.deleteProject(id));

  // ---- hesaplar

  Future<SavedCalculation> createCalculation({
    required String name,
    required CalcRevision revision,
    String? customerId,
    String? projectId,
  }) => _mutate(
    (r) => r.createCalculation(
      name: name,
      revision: revision,
      customerId: customerId,
      projectId: projectId,
    ),
  );

  Future<SavedCalculation> updateCalculation(
    String id, {
    String? name,
    CalcRevision? revision,
    String? customerId,
    String? projectId,
    bool clearCustomer = false,
    bool clearProject = false,
  }) => _mutate(
    (r) => r.updateCalculation(
      id,
      name: name,
      revision: revision,
      customerId: customerId,
      projectId: projectId,
      clearCustomer: clearCustomer,
      clearProject: clearProject,
    ),
  );

  Future<SavedCalculation> duplicateCalculation(String id) =>
      _mutate((r) => r.duplicateCalculation(id));

  Future<void> deleteCalculation(String id) =>
      _mutate((r) => r.deleteCalculation(id));
}

/// [RecordsController]'ı widget ağacına sağlar.
class RecordsScope extends InheritedNotifier<RecordsController> {
  const RecordsScope({
    super.key,
    required RecordsController controller,
    required super.child,
  }) : super(notifier: controller);

  static RecordsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RecordsScope>();
    assert(scope != null, 'RecordsScope bulunamadı');
    return scope!.notifier!;
  }
}
