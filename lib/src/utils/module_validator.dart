import '../contracts/module_contract.dart';

/// Validates [MicroModule] instances before registration.
///
/// Checks for:
/// - Non-empty [moduleId]
/// - Non-empty [moduleName]
/// - Valid [moduleId] format (URL-safe identifiers)
/// - No conflicting reserved IDs
class ModuleValidator {
  static final _idPattern = RegExp(r'^[a-z][a-z0-9_-]*$');
  static const _reservedIds = {
    'system', 'core', 'root', 'global', 'app', 'main',
  };

  /// Validate a module. Throws [ModuleValidationException] on failure.
  void validate(MicroModule module) {
    _checkNotEmpty(module.moduleId, 'moduleId');
    _checkNotEmpty(module.moduleName, 'moduleName');
    _checkIdFormat(module.moduleId);
    _checkNotReserved(module.moduleId);
    _checkNoDuplicateDeps(module);
    _checkSelfDependency(module);
  }

  void _checkNotEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      throw ModuleValidationException(
          'Module $field cannot be empty.');
    }
  }

  void _checkIdFormat(String id) {
    if (!_idPattern.hasMatch(id)) {
      throw ModuleValidationException(
          'Module ID "$id" is invalid. '
          'Must be lowercase, start with a letter, '
          'and contain only letters, digits, hyphens, or underscores. '
          'Example: "user-profile", "shop_feature".');
    }
  }

  void _checkNotReserved(String id) {
    if (_reservedIds.contains(id)) {
      throw ModuleValidationException(
          'Module ID "$id" is reserved by the framework. '
          'Choose a different ID.');
    }
  }

  void _checkNoDuplicateDeps(MicroModule module) {
    final seen = <String>{};
    for (final dep in module.dependencies) {
      if (!seen.add(dep)) {
        throw ModuleValidationException(
            'Module "${module.moduleId}" has duplicate dependency "$dep".');
      }
    }
  }

  void _checkSelfDependency(MicroModule module) {
    if (module.dependencies.contains(module.moduleId)) {
      throw ModuleValidationException(
          'Module "${module.moduleId}" depends on itself. '
          'Self-dependencies are not allowed.');
    }
  }
}
