import 'dart:io';

/// The app's real `firestore.rules`, parsed into something a Dart test can
/// evaluate a document against.
///
/// This exists because of a bug that shipped: the goal-ownership refactor
/// dropped `categoryId` from `PlannedBlock`/`TrackedBlock` in favour of
/// `goalId`, but the rules' own create/update validation kept requiring a
/// `categoryId` field — so every activity the app wrote was rejected with
/// permission-denied, and creating one looked like it simply did nothing.
/// Nothing caught it: the whole test suite runs against
/// `FakeFirebaseFirestore`, which happily accepts any write.
/// `fake_cloud_firestore` can be handed real security rules, but its rules
/// engine supports neither custom functions (`isOwner`,
/// `isReasonableString`) nor the `request.resource` object — i.e. exactly
/// the parts that were wrong — so the document-shape half of the rules has
/// to be checked here instead.
///
/// Only the parts of the rules language this file's rules actually use are
/// understood; anything unrecognised is deliberately *not* silently
/// ignored — see [FirestoreRules.unparsedConditions], which the contract
/// test asserts is empty so a newly added rule clause can't quietly fall
/// outside this check.
class FirestoreRules {
  FirestoreRules._({
    required this.collections,
    required this.maxStringLength,
    required this.unparsedConditions,
  });

  /// Parses the rules file the project actually deploys. Tests run with
  /// the package root (`app/`) as their working directory, so the default
  /// path is the same file `firebase deploy` uploads — not a copy that
  /// could drift from it.
  factory FirestoreRules.fromFile([String path = 'firestore.rules']) =>
      FirestoreRules.parse(File(path).readAsStringSync());

  factory FirestoreRules.parse(String source) {
    final rules = _stripComments(source);

    final sizeLimit = RegExp(
      r'function\s+isReasonableString\([^)]*\)\s*\{[^}]*\.size\(\)\s*<=\s*(\d+)',
    ).firstMatch(rules);

    final collections = <String, CollectionRule>{};
    final unparsed = <String>[];

    for (final block in RegExp(
      r'match\s+/users/\{\w+\}/(\w+)/\{\w+\}\s*\{([^}]*)\}',
    ).allMatches(rules)) {
      final name = block.group(1)!;
      final body = block.group(2)!;

      final methods = <String, String>{};
      for (final clause in RegExp(
        r'allow\s+([\w\s,]+?)\s*:\s*if\s+([^;]*);',
      ).allMatches(body)) {
        final condition = _collapseWhitespace(clause.group(2)!);
        for (final method in clause.group(1)!.split(',')) {
          methods[method.trim()] = condition;
        }
      }

      final write = methods['create'] ?? methods['write'] ?? '';
      final required = <String>{};
      final types = <String, String>{};
      final boundedStrings = <String>{};

      // Everything below consumes the write condition term by term, so a
      // term this parser doesn't understand can be reported rather than
      // dropped.
      for (final term in write.split('&&').map((t) => t.trim())) {
        if (term.isEmpty) continue;
        final hasAll = RegExp(
          r'request\.resource\.data\.keys\(\)\.hasAll\(\s*\[([^\]]*)\]\s*\)',
        ).firstMatch(term);
        if (hasAll != null) {
          required.addAll(
            RegExp(
              r"'([^']*)'",
            ).allMatches(hasAll.group(1)!).map((m) => m.group(1)!),
          );
          continue;
        }
        final typed = RegExp(
          r'request\.resource\.data\.(\w+)\s+is\s+(\w+)',
        ).firstMatch(term);
        if (typed != null) {
          types[typed.group(1)!] = typed.group(2)!;
          continue;
        }
        final bounded = RegExp(
          r'isReasonableString\(\s*request\.resource\.data\.(\w+)\s*\)',
        ).firstMatch(term);
        if (bounded != null) {
          boundedStrings.add(bounded.group(1)!);
          continue;
        }
        // `isOwner(uid)` and a bare `request.resource.data is map` carry no
        // per-field obligation — the first is asserted separately (see
        // [CollectionRule.ownerGated]), the second is satisfied by every
        // document this app writes.
        if (term == 'isOwner(uid)' || term == 'request.resource.data is map') {
          continue;
        }
        unparsed.add('$name: $term');
      }

      collections[name] = CollectionRule(
        collection: name,
        requiredKeys: required,
        fieldTypes: types,
        boundedStringFields: boundedStrings,
        conditionsByMethod: methods,
      );
    }

    return FirestoreRules._(
      collections: collections,
      maxStringLength: int.parse(sizeLimit!.group(1)!),
      unparsedConditions: unparsed,
    );
  }

  /// Keyed by collection name, for every `users/{uid}/<name>/{doc}` match
  /// block in the rules.
  final Map<String, CollectionRule> collections;

  /// The cap `isReasonableString` enforces, read from the rules' own
  /// function definition rather than hardcoded here.
  final int maxStringLength;

  /// Write-condition terms this parser didn't recognise. Non-empty means
  /// the rules grew a clause these checks silently ignore.
  final List<String> unparsedConditions;

  /// Why Firestore would reject writing [data] to `users/{uid}/[collection]
  /// /{docId}` — empty when the rules would accept it. A collection with no
  /// rule at all is itself a violation: an unmatched path denies every
  /// request, which is how the live-activity `state/` doc silently failed
  /// once.
  List<String> violations(String collection, Map<String, dynamic> data) {
    final rule = collections[collection];
    if (rule == null) {
      return [
        'no rule matches users/{uid}/$collection/{docId} — an unmatched '
            'path denies every read and write',
      ];
    }
    return rule.violations(data, maxStringLength: maxStringLength);
  }
}

class CollectionRule {
  const CollectionRule({
    required this.collection,
    required this.requiredKeys,
    required this.fieldTypes,
    required this.boundedStringFields,
    required this.conditionsByMethod,
  });

  final String collection;

  /// Fields `keys().hasAll([...])` demands on every create/update.
  final Set<String> requiredKeys;

  /// Field name -> the rules-language type it's asserted to be.
  final Map<String, String> fieldTypes;

  /// Fields passed through `isReasonableString` — a string, length-capped.
  final Set<String> boundedStringFields;

  /// The raw `if` condition per allow method (`read`, `create`, ...).
  final Map<String, String> conditionsByMethod;

  /// True when every method this collection allows is gated on the owner
  /// check — nothing here should ever be readable or writable by another
  /// account.
  bool get ownerGated =>
      conditionsByMethod.isNotEmpty &&
      conditionsByMethod.values.every((c) => c.contains('isOwner(uid)'));

  List<String> violations(
    Map<String, dynamic> data, {
    required int maxStringLength,
  }) {
    final problems = <String>[];
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        problems.add("$collection: required field '$key' is missing");
      }
    }
    fieldTypes.forEach((field, type) {
      if (!data.containsKey(field)) return; // Already reported, if required.
      if (!_matchesRulesType(data[field], type)) {
        problems.add(
          "$collection: field '$field' is ${data[field].runtimeType}, "
          'which the rules require to be $type',
        );
      }
    });
    for (final field in boundedStringFields) {
      final value = data[field];
      if (!data.containsKey(field)) continue;
      if (value is! String) {
        problems.add(
          "$collection: field '$field' is ${value.runtimeType}, which "
          'isReasonableString requires to be string',
        );
      } else if (value.length > maxStringLength) {
        problems.add(
          "$collection: field '$field' is ${value.length} characters, over "
          "isReasonableString's $maxStringLength cap",
        );
      }
    }
    return problems;
  }
}

bool _matchesRulesType(Object? value, String type) => switch (type) {
  'string' => value is String,
  'int' => value is int,
  'float' => value is double,
  'number' => value is num,
  'bool' => value is bool,
  'map' => value is Map,
  'list' => value is List,
  // Nothing in these rules asserts any other type; an unrecognised one
  // must fail loudly rather than pass by default.
  _ => false,
};

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'//[^\n]*'), '');

String _collapseWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();
