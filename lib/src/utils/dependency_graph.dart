import '../contracts/module_contract.dart';

/// Builds and analyzes the dependency graph of [MicroModule]s.
///
/// Uses Kahn's algorithm for topological sorting and DFS for cycle detection.
class DependencyGraph {
  final Map<String, Set<String>> _adjacency = {};
  final Map<String, MicroModule> _moduleMap = {};

  // ─── Build ─────────────────────────────────────────────────────────────────

  /// Build the graph from a list of modules.
  void build(List<MicroModule> modules) {
    _adjacency.clear();
    _moduleMap.clear();
    for (final m in modules) {
      _moduleMap[m.moduleId] = m;
      _adjacency[m.moduleId] = Set.from(m.dependencies);
    }
  }

  // ─── Cycle Detection ───────────────────────────────────────────────────────

  /// Throws [CircularDependencyException] if any cycle is found.
  void checkForCircularDependencies() {
    final visited = <String>{};
    final stack = <String>{};

    for (final id in _adjacency.keys) {
      if (!visited.contains(id)) {
        _dfs(id, visited, stack);
      }
    }
  }

  void _dfs(String id, Set<String> visited, Set<String> stack) {
    visited.add(id);
    stack.add(id);

    for (final dep in _adjacency[id] ?? const <String>{}) {
      if (!visited.contains(dep)) {
        _dfs(dep, visited, stack);
      } else if (stack.contains(dep)) {
        final cycle = _findCycle(id, dep);
        throw CircularDependencyException(
          'Circular dependency detected: $cycle',
        );
      }
    }

    stack.remove(id);
  }

  String _findCycle(String from, String to) {
    final path = [from];
    final visited = <String>{from};
    if (_buildPath(from, to, path, visited)) {
      return path.join(' → ');
    }
    return '$from → ... → $to';
  }

  bool _buildPath(
    String current,
    String target,
    List<String> path,
    Set<String> visited,
  ) {
    for (final dep in _adjacency[current] ?? const <String>{}) {
      if (dep == target) {
        path.add(dep);
        return true;
      }
      if (!visited.contains(dep)) {
        visited.add(dep);
        path.add(dep);
        if (_buildPath(dep, target, path, visited)) return true;
        path.removeLast();
      }
    }
    return false;
  }

  // ─── Topological Sort (Kahn's Algorithm) ──────────────────────────────────

  /// Returns modules sorted so that all dependencies come before dependents.
  ///
  /// Within the same topological level, modules are sorted by
  /// [MicroModule.loadPriority] (descending — higher first).
  List<MicroModule> getTopologicalOrder(List<MicroModule> modules) {
    final result = <MicroModule>[];

    // Count in-degree (number of modules that depend on this one)
    final inDegree = <String, int>{};
    for (final m in modules) {
      inDegree[m.moduleId] ??= 0;
    }
    for (final m in modules) {
      for (final dep in m.dependencies) {
        inDegree[dep] = (inDegree[dep] ?? 0) + 1;
      }
    }

    // Start with zero in-degree modules (no one depends on them first)
    final queue = modules
        .where((m) => (inDegree[m.moduleId] ?? 0) == 0)
        .toList()
      ..sort((a, b) => b.loadPriority.compareTo(a.loadPriority));

    while (queue.isNotEmpty) {
      // Take highest-priority module
      queue.sort((a, b) => b.loadPriority.compareTo(a.loadPriority));
      final current = queue.removeAt(0);
      result.add(current);

      // Decrement in-degree for modules that depend on current
      for (final other in modules) {
        if (other.dependencies.contains(current.moduleId)) {
          inDegree[other.moduleId] =
              (inDegree[other.moduleId] ?? 1) - 1;
          if (inDegree[other.moduleId] == 0) {
            queue.add(other);
          }
        }
      }
    }

    return result;
  }

  // ─── Analysis Utilities ────────────────────────────────────────────────────

  /// Returns all modules that (directly or transitively) depend on [moduleId].
  Set<String> getDependents(String moduleId) {
    final dependents = <String>{};
    for (final entry in _adjacency.entries) {
      if (entry.value.contains(moduleId)) {
        dependents.add(entry.key);
        dependents.addAll(getDependents(entry.key));
      }
    }
    return dependents;
  }

  /// Returns all (direct + transitive) dependencies of [moduleId].
  Set<String> getAllDependencies(String moduleId) {
    final deps = <String>{};
    void collect(String id) {
      for (final dep in _adjacency[id] ?? const <String>{}) {
        if (deps.add(dep)) collect(dep);
      }
    }
    collect(moduleId);
    return deps;
  }

  /// Generates a human-readable dependency tree string.
  String toDotGraph() {
    final sb = StringBuffer('digraph Dependencies {\n');
    for (final entry in _adjacency.entries) {
      for (final dep in entry.value) {
        sb.writeln('  "${entry.key}" -> "$dep";');
      }
    }
    sb.writeln('}');
    return sb.toString();
  }
}

// ─── Exceptions ──────────────────────────────────────────────────────────────

class CircularDependencyException implements Exception {
  final String message;
  const CircularDependencyException(this.message);
  @override
  String toString() => 'CircularDependencyException: $message';
}
