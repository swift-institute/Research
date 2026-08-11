# Lint-pass aggregate — 2026-05-11

**Engine**: swift-linter @ `17a9777` (branch `lint-pass-audit-2026-05-11`, `--all` flag bypasses Lint/ dispatch)
**Targets**: 11 public primitives packages
**Scope**: each target's `Sources/` directory only
**Rules**: all 73 rules from 13 packs enabled

## Per-target totals

| Target | Findings |
|--------|----------|
| swift-carrier-primitives | 18 |
| swift-comparison-primitives | 45 |
| swift-either-primitives | 6 |
| swift-equation-primitives | 55 |
| swift-hash-primitives | 46 |
| swift-ownership-primitives | 56 |
| swift-pair-primitives | 0 |
| swift-product-primitives | 13 |
| swift-property-primitives | 15 |
| swift-standard-library-extensions | 620 |
| swift-tagged-primitives | 22 |
| **Total** | **896** |

## Per-rule fired counts (23 of 72 rules)

Total: 896 findings across 23 rules. The 49 rules with zero findings are listed in the §Silent Rules section.

| Rule ID | Count | Sample paths (≤3) |
|---------|-------|-------------------|
| compound_identifier | 363 | swift-carrier-primitives/Carrier Primitives.docc/Resources/step-07-generic.swift:56 swift-carrier-primitives/Carrier Primitives.docc/Resources/step-07-generic.swift:57 swift-comparison-primitives/Comparison.Protocol+Swift.Optional.swift:21  |
| minimal_type_body | 252 | swift-carrier-primitives/Carrier.swift:23 swift-ownership-primitives/Ownership.Borrow.swift:117 swift-ownership-primitives/Ownership.Indirect.swift:73  |
| extension_noncopyable_constraint | 108 | swift-carrier-primitives/Carrier Primitives.docc/Resources/step-03-struct.swift:8 swift-carrier-primitives/Carrier Primitives.docc/Resources/step-04-conformance.swift:8 swift-carrier-primitives/Carrier Primitives.docc/Resources/step-05-requirements.swift:8  |
| int_parameter_public | 54 | swift-standard-library-extensions/Array.swift:21 swift-standard-library-extensions/Array.swift:41 swift-standard-library-extensions/Bool.Builder.swift:195  |
| bool_parameter_public | 27 | swift-standard-library-extensions/Bool.Builder.swift:22 swift-standard-library-extensions/Bool.Builder.swift:30 swift-standard-library-extensions/Bool.Builder.swift:46  |
| closure_typed_throws_annotation | 20 | swift-standard-library-extensions/Array.swift:117 swift-standard-library-extensions/Array.swift:141 swift-standard-library-extensions/Collection.swift:124  |
| do_throws_e_for_typed_catch | 12 | swift-standard-library-extensions/Result.swift:142 swift-standard-library-extensions/Span.swift:23 swift-standard-library-extensions/Span.swift:48  |
| tagged_rawvalue_extension_public_init | 11 | swift-tagged-primitives/Tagged+Literals.swift:51 swift-tagged-primitives/Tagged+Literals.swift:61 swift-tagged-primitives/Tagged+Literals.swift:71  |
| swift_protocol_qualification | 9 | swift-tagged-primitives/Tagged+Collection.swift:13 swift-tagged-primitives/Tagged+Collection.swift:14 swift-tagged-primitives/Tagged+Sequence.swift:17  |
| typealiased_namespace_bridge | 7 | swift-ownership-primitives/Tagged+Ownership.Borrow.Protocol.swift:31 swift-tagged-primitives/Tagged+Collection.swift:16 swift-tagged-primitives/Tagged+Collection.swift:18  |
| namespace_adoption_typealias | 7 | swift-ownership-primitives/Tagged+Ownership.Borrow.Protocol.swift:31 swift-property-primitives/Property Primitives.docc/Resources/step-02-tags-and-typealias.swift:12 swift-property-primitives/Property Primitives.docc/Resources/step-03-push-accessor.swift:12  |
| unification_bridge_typealias | 5 | swift-carrier-primitives/Unicode.Scalar+Carrier.swift:5 swift-carrier-primitives/Carrying.swift:12 swift-equation-primitives/Equation.Protocol.swift:18  |
| unnecessary_unchecked_sendable_noncopyable | 3 | swift-ownership-primitives/Ownership.Transfer.Erased.Incoming.swift:45 swift-ownership-primitives/Ownership.Transfer.Retained.Incoming.swift:56 swift-ownership-primitives/Ownership.Transfer.Retained.Outgoing.swift:55  |
| single_type_per_file | 3 | swift-carrier-primitives/Carrier Primitives.docc/Resources/step-05-requirements.swift:27 swift-carrier-primitives/Carrier Primitives.docc/Resources/step-06-sibling.swift:27 swift-carrier-primitives/Carrier Primitives.docc/Resources/step-07-generic.swift:27  |
| borrowing_self_short_circuit | 3 | swift-equation-primitives/Equation.Protocol+Swift.KeyValuePairs.swift:20 swift-equation-primitives/Equation.Protocol+Swift.Range.swift:21 swift-equation-primitives/Equation.Protocol+Swift.Range.swift:41  |
| unchecked_call_site | 2 | swift-ownership-primitives/Ownership.Slot.Move.swift:51 swift-ownership-primitives/Ownership.Slot.Move.swift:59  |
| mock_factory_zero_collision | 2 | swift-tagged-primitives/Tagged+Literals.swift:165 swift-tagged-primitives/Tagged+Literals.swift:184  |
| inlinable_internal_access | 2 | swift-ownership-primitives/Ownership.Borrow.swift:103 swift-ownership-primitives/_Ownership_Borrow_OwnedBuffer.swift:32  |
| existential_throws | 2 | swift-product-primitives/Product+Decodable.swift:12 swift-product-primitives/Product+Encodable.swift:12  |
| unsafe_assignment_granularity | 1 | swift-property-primitives/Property.Inout.swift:116  |
| unchecked_sendable_categorized | 1 | swift-property-primitives/Property.Consume.State.swift:52  |
| iteration_intent_counter_loop | 1 | swift-standard-library-extensions/Set.swift:71  |
| ad_hoc_box_class | 1 | swift-ownership-primitives/Ownership.Indirect.swift:73  |

## Silent rules (zero findings across all 11 targets — 49 of 72)

Removal candidates per HANDOFF.md removal criterion 1, IFF (i) zero findings AND (ii) no skill citation backing it AND (iii) no documented bug class. The skill-citation check is per-pack, deferred to disposition waves.

```
benchmark_timed_required
bitpattern_rawvalue_chain
bounded_index_static_capacity
c_type_in_public_api
callback_result_over_throws_thunk
cardinal_count_minus_one
cardinal_zero_one_constructor
chained_rawvalue_access
closure_param_position
compound_test_suite_name
compound_type_name
configuration_parameter_placement
convention_c_representability
dead_case_per_platform_enum
do_throws_e_for_typed_catch_throw
enumerated_subscript_collection
error_noncopyable_check
generic_throws_missing_never_specialization
hoisted_error_in_public_throws
hoisted_protocol_self_conformance
intermediate_binding_then_return
lifecycle_typealias_review
multi_closure_lifecycle_order
multi_closure_unlabeled
namespace_root_compound_platform
nonisolated_unsafe_safe
option_named_flags
optionset_shell_pattern
performance_suite_serialized
platform_canimport_conditional
platform_system_subdomain
pointer_advanced_by
private_unsafe_storage
raw_value_access
redundant_prefix
result_builder_for_loop
result_wrapper_for_rethrows_shim
single_type_namespace
struct_sendable_class_member
tag_suffix
test_function_naming
throwing_wrapper_init_no_validation
try_optional
type_transform_placement
typed_throws_cannot_use_self_error
untyped_throws
usable_from_inline_internal_import
var_named_impl
wrapper_backing_exposed
```

## Per-target raw findings

- [`swift-carrier-primitives`](./lint-pass-2026-05-11-swift-carrier-primitives.md)
- [`swift-comparison-primitives`](./lint-pass-2026-05-11-swift-comparison-primitives.md)
- [`swift-either-primitives`](./lint-pass-2026-05-11-swift-either-primitives.md)
- [`swift-equation-primitives`](./lint-pass-2026-05-11-swift-equation-primitives.md)
- [`swift-hash-primitives`](./lint-pass-2026-05-11-swift-hash-primitives.md)
- [`swift-ownership-primitives`](./lint-pass-2026-05-11-swift-ownership-primitives.md)
- [`swift-pair-primitives`](./lint-pass-2026-05-11-swift-pair-primitives.md)
- [`swift-product-primitives`](./lint-pass-2026-05-11-swift-product-primitives.md)
- [`swift-property-primitives`](./lint-pass-2026-05-11-swift-property-primitives.md)
- [`swift-standard-library-extensions`](./lint-pass-2026-05-11-swift-standard-library-extensions.md)
- [`swift-tagged-primitives`](./lint-pass-2026-05-11-swift-tagged-primitives.md)
