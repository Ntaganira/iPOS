/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.data.models
 * - File      : app_user.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Authenticated operator projection with resolved role
 *               permissions. The PIN digest never leaves the repository layer.
 * </pre>
 */

import 'package:flutter/foundation.dart';

import '../../core/security/permissions.dart';

/// Local operator session identity.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.roleId,
    required this.roleName,
    required this.permissions,
    required this.mustChangePin,
    this.isActive = true,
    this.lastLoginAt,
  });

  final String id;
  final String displayName;
  final String roleId;
  final String roleName;
  final Set<AppPermission> permissions;
  final bool mustChangePin;
  final bool isActive;
  final DateTime? lastLoginAt;

  bool can(AppPermission permission) => permissions.contains(permission);
}

/// Role choice for user administration.
@immutable
class RoleOption {
  const RoleOption({
    required this.id,
    required this.name,
    required this.permissions,
    required this.isSystem,
  });

  final String id;
  final String name;
  final Set<AppPermission> permissions;
  final bool isSystem;
}
