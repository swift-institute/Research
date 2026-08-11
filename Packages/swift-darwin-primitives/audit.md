# Audit: swift-darwin-primitives

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-primitives.md (2026-04-03)

**Pre-publication dependency-tree audit — P0/P1/P2 checks**

#### P2: Methods in Type Body [API-IMPL-008]

**File**: `Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.Event.swift` (7 items in body)

The `Kqueue` enum itself was a false positive (declared inside an `extension Kernel { }` block with methods in further nested extensions), but `Darwin.Kernel.Kqueue.Event.swift` is a legitimate finding.

**Assessment**: Platform packages consistently define methods inside struct/enum bodies rather than using extensions. This appears to be a systematic pattern in the platform layer, possibly because these are thin syscall wrappers where the extension pattern adds overhead without benefit.

**Recommendation**: Consider as a batch cleanup across all platform packages, but lower priority since these are platform-specific code.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-darwin-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=3, MEDIUM=2, LOW=2, INFO=0
Finding IDs: DAR-001, DAR-002, DAR-003, DAR-004, DAR-005, DAR-006, DAR-007, DAR-008, DAR-009, DAR-010, DAR-011, DAR-012, DAR-013, DAR-014, DAR-015 (+3 more)

| Severity | Count |
|----------|-------|
| HIGH     | 2     |
| MEDIUM   | 6     |
| LOW      | 7     |
| OK       | —     |
| **Total**| **15**|
