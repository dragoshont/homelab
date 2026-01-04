# Security Checklist: Immich Zero Trust Access

**Purpose**: Unit tests for the *requirements* quality around Zero Trust access, DNS split-horizon, secret handling, and NAS-backed storage for Immich.
**Created**: 2026-01-04
**Feature**: [specs/001-immich-zero-trust/spec.md](../spec.md)

**Note**: This checklist validates the clarity/completeness/consistency of the written requirements. It does not validate implementation behavior.

## Requirement Completeness

- [x] CHK001 Are both entrypoints (external via Cloudflare + internal via LAN/VPN) explicitly specified as separate requirement statements? [Completeness, Spec §Entrypoints]
- [x] CHK002 Are the operator documentation deliverables explicitly enumerated (tunnel setup, public DNS, UniFi DNS) and tied to acceptance criteria? [Completeness, Spec §FR-005, Spec §SC-004]
- [x] CHK003 Are “no plaintext secrets” requirements fully stated, including which values are considered sensitive (tunnel token, Access app IDs, personal hostname)? [Completeness, Spec §FR-009a]
- [x] CHK004 Are the requirements explicit about which requests must include Cloudflare Access identity headers (external path only vs all paths)? [Completeness, Spec §FR-004b]
- [x] CHK005 Are the requirements explicit about how internal (LAN/VPN) access is authorized (Immich native auth) and whether Cloudflare Access is intentionally excluded? [Completeness, Spec §FR-008a, Spec §FR-008b]
- [x] CHK006 Are storage requirements complete enough to implement without guesswork (which NAS-backed path holds “library” and which holds “iPhone backups”)? [Completeness, Spec §Storage Paths, Quickstart §Placeholders]
- [x] CHK007 Are backup-related requirements complete about retention and lifecycle (deletion, duplicates, backups after device reset), or are these intentionally out of scope? [Completeness, Spec §FR-007a]

## Requirement Clarity

- [x] CHK008 Is “private subdomain” defined in a way that is unambiguous while still avoiding committing the real domain value (placeholder conventions, where configured)? [Clarity, Spec §Glossary, Spec §FR-002, Spec §FR-009]
- [x] CHK009 Is “approved Cloudflare path” defined precisely (tunnel → reverse proxy → Immich) so reviewers can detect misrouting risk? [Clarity, Spec §Glossary, Spec §Entrypoints]
- [x] CHK010 Is the header requirement unambiguous (exact header name, external-only scope, and what constitutes “missing/invalid”)? [Clarity, Spec §FR-004, Spec §FR-004b]
- [x] CHK011 Is the “>100MB” rule unambiguous (what size is measured, what is blocked externally, and what is supported over LAN/VPN)? [Clarity, Spec §FR-004c, Spec §FR-008]
- [x] CHK012 Is the “deny-by-default” requirement expressed as concrete policy expectations (identity provider, allow-listing method, device posture signals if any)? [Clarity, Spec §FR-003a]

## Requirement Consistency

- [x] CHK013 Do the spec and quickstart consistently describe that external access is Cloudflare Access-gated and internal access bypasses Cloudflare via split-horizon DNS? [Consistency, Spec §Entrypoints, Quickstart §0, Quickstart §6]
- [x] CHK014 Do the spec and plan agree on where `cloudflared` runs (in-cluster, Flux-managed), and do they avoid implying host-managed tunnel setup? [Consistency, Spec §FR-005a, Spec §Clarifications, Plan §Summary]
- [x] CHK015 Are the “origin must require header” requirements consistent with the “internal access bypasses Cloudflare” requirement (i.e., not accidentally forbidding LAN/VPN access)? [Consistency, Spec §Glossary, Spec §FR-004b]
- [x] CHK016 Are success criteria consistent with requirements (e.g., SC-002 “direct/origin access attempts fail” aligns with FR-004/FR-004a) and defined the same way throughout? [Consistency, Spec §SC-002, Spec §FR-004a]

## Acceptance Criteria Quality

- [x] CHK017 Are the acceptance scenarios measurable without relying on unstated infrastructure (e.g., what constitutes “origin directly” in a single-node cluster)? [Measurability, Spec §Glossary, Spec §SC-002]
- [x] CHK018 Is SC-004 (“complete setup in under 60 minutes”) defined with a clear start/end boundary and prerequisites, so it is objectively measurable? [Acceptance Criteria, Spec §SC-004, Quickstart §1]
- [x] CHK019 Is SC-005 (no private identifiers/secrets in repo) defined with an explicit search strategy and what counts as a violation (placeholders allowed, exact forbidden strings)? [Clarity, Spec §SC-005, Quickstart §8]

## Scenario Coverage

- [x] CHK020 Are requirements defined for the “external view-only” scenario vs “external upload” scenario (since uploads are constrained >100MB)? [Coverage, Spec §FR-004c, Spec §FR-008]
- [x] CHK021 Are requirements defined for “LAN without VPN” and “VPN from outside” and do they both map to the same internal DNS behavior? [Coverage, Spec §Entrypoints, Quickstart §0]
- [x] CHK022 Are requirements defined for initial bootstrap (first admin user creation, initial library path readiness), or is that explicitly out of scope? [Completeness, Spec §FR-008c, Quickstart §5b]

## Edge Case Coverage

- [x] CHK023 Are Cloudflare outage / tunnel down behaviors specified (what should users do; is LAN/VPN fallback sufficient)? [Coverage, Spec §Edge Cases]
- [x] CHK024 Are split-horizon DNS failure modes specified (clients resolving public record while on LAN; how to diagnose/mitigate)? [Coverage, Quickstart §6]
- [x] CHK025 Are storage disruption behaviors specified beyond “fail safely” (what signals/operators should look for; whether writes are prevented)? [Completeness, Spec §FR-011, Spec §Edge Cases]
- [x] CHK026 Are certificate/TLS termination expectations specified for external vs internal access (Cloudflare edge vs LAN NodePort), to avoid ambiguous “http/https” requirements? [Completeness, Spec §FR-010, Quickstart §4a]

## Non-Functional Requirements

- [x] CHK027 Are audit/logging expectations specified for access control decisions (Cloudflare Access logs vs in-cluster proxy logs)? [Completeness, Spec §FR-012, Quickstart §9]
- [x] CHK028 Are privacy requirements specified for metadata exposure (e.g., whether access denial should avoid disclosing product/service details)? [Completeness, Spec §Edge Cases]
- [x] CHK029 Are availability expectations defined (single-node acceptable; backup/restore expectations for NAS-backed data)? [Completeness, Spec §Assumptions]

## Dependencies & Assumptions

- [x] CHK030 Are all external dependencies listed with explicit prerequisites (Cloudflare plan/features, Zero Trust enabled, ability to create Access app + tunnel)? [Completeness, Quickstart §1]
- [x] CHK031 Are host prerequisites for storage paths explicitly documented (stable mount points, permissions for the Kubernetes runtime to read/write)? [Completeness, Quickstart §1, Spec §Dependencies]
- [x] CHK032 Are assumptions about “no client-embedded secrets” explicitly tied to Cloudflare Access configuration and documented as a constraint? [Completeness, Spec §Assumptions]

## Ambiguities & Conflicts

- [x] CHK033 Is the term “origin” used consistently (reverse proxy origin vs Immich service origin), and is the boundary defined to prevent misinterpretation? [Clarity, Spec §Glossary]
- [x] CHK034 Is it explicit whether the same hostname is required for both internal and external use (split-horizon) vs allowing two hostnames? [Clarity, Spec §Entrypoints, Quickstart §0]

## Notes

- Each `/speckit.checklist` run creates a new file.
- Use `[Gap]` items as prompts to tighten the spec before implementation.

## Status (2026-01-04)

- Items checked off were addressed by updates to `spec.md` and `quickstart.md` after the initial checklist was generated.
- Remaining gaps are now concentrated in: internal auth wording (CHK005), initial bootstrap scope (CHK022), storage failure signals (CHK025), auditing/logging (CHK027), availability/restore expectations (CHK029), host storage permissions (CHK031), and “no client-embedded secrets” specificity (CHK032).
