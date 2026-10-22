/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.features.auth
 * - File      : auth_controller.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : In-memory operator session and user-administration state. The
 *               PIN is verified by the repository and discarded; only the
 *               resolved user, role, and permissions remain in memory. All
 *               privileged UI checks read this session, while audit providers
 *               derive the current actor from it.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import '../../core/security/permissions.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/auth_repository.dart';

/// Owns authentication state for the process.
class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  List<AppUser> _users = const <AppUser>[];
  List<RoleOption> _roles = const <RoleOption>[];
  AppUser? _currentUser;
  bool _loading = true;
  String? _error;
  bool _firstRun = false;

  List<AppUser> get activeUsers =>
      List<AppUser>.unmodifiable(_users.where((user) => user.isActive));
  List<AppUser> get allUsers => List<AppUser>.unmodifiable(_users);
  List<RoleOption> get roles => List<RoleOption>.unmodifiable(_roles);
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get loading => _loading;
  bool get firstRun => _firstRun;
  String? get error => _error;

  AuditActor? get auditActor {
    final user = _currentUser;
    return user == null
        ? null
        : AuditActor(userId: user.id, name: user.displayName);
  }

  bool can(AppPermission permission) => _currentUser?.can(permission) ?? false;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final bootstrap = await _repository.ensureBootstrap();
      _firstRun = bootstrap.createdAdministrator;
      _roles = await _repository.listRoles();
      await _reloadUsers();
    } catch (error, stackTrace) {
      _error = 'Accounts could not be loaded from the encrypted store.';
      debugPrint('Auth bootstrap failed: $error\n$stackTrace');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String userId, required String pin}) async {
    _error = null;
    final user = await _repository.authenticate(userId: userId, pin: pin);
    if (user == null) {
      _error = 'invalid';
      notifyListeners();
      return false;
    }
    _currentUser = user;
    _firstRun = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    final user = _currentUser;
    if (user != null) {
      await _repository.recordLogout(user);
    }
    _currentUser = null;
    notifyListeners();
  }

  /// Called after the forced first-login PIN change or a voluntary change.
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return false;
    }
    try {
      await _repository.changePin(
        userId: user.id,
        currentPin: currentPin,
        newPin: newPin,
      );
      _currentUser = AppUser(
        id: user.id,
        displayName: user.displayName,
        roleId: user.roleId,
        roleName: user.roleName,
        permissions: user.permissions,
        mustChangePin: false,
        isActive: user.isActive,
        lastLoginAt: user.lastLoginAt,
      );
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUsers() async {
    await _reloadUsers();
    notifyListeners();
  }

  Future<bool> createUser({
    required String displayName,
    required String roleId,
    required String pin,
  }) async {
    try {
      await _repository.createUser(
        displayName: displayName,
        roleId: roleId,
        pin: pin,
      );
      await _reloadUsers();
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser({
    required String userId,
    required String displayName,
    required String roleId,
    required bool isActive,
  }) async {
    try {
      await _repository.updateUser(
        userId: userId,
        displayName: displayName,
        roleId: roleId,
        isActive: isActive,
      );
      await _reloadUsers();
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPin({
    required String userId,
    required String newPin,
  }) async {
    try {
      await _repository.resetPin(userId: userId, newPin: newPin);
      await _reloadUsers();
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _reloadUsers() async {
    _users = await _repository.listAllUsers();
    final current = _currentUser;
    if (current != null) {
      for (final user in _users) {
        if (user.id == current.id) {
          _currentUser = user;
          break;
        }
      }
    }
  }
}
