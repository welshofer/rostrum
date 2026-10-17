# Calibri review pack: user-reported PowerPoint acceptance

The user reviewed the delivered Calibri review decks and reported:

> “Decks look great in PowerPoint. Proceed.”

This records acceptance of the delivered pack. It is not a separate verdict for
each profile or an automated native comparison. The user had previously identified
their application as Microsoft PowerPoint for Mac; no application version or new
PDF/image exports accompanied this confirmation. Export acceptance, native Lectern
thumbnail review and paired Mac performance measurements remain separate work.

The files were generated from `837e2bc6fcc2496177a5ada97981f23a0a1919f8`, merged
to main in PR #78. The delivered ZIP contained these four files:

| File | Slides | SHA-256 |
| --- | ---: | --- |
| Calibri-Review-4x3-external.pptx | 9 | `77d7e596eafc28b022d9a41907b89c31748b4709b56b165a486e58b627313c0e` |
| Calibri-Review-4x3-embedded.pptx | 9 | `9e6df92dfe5dba8cc67738112f925ccb0ff4febfa79d49937896b15e747efe5a` |
| Calibri-Review-16x9-external.pptx | 7 | `c8c76ed1409d23a7fa674ab5a0ede70a39a941eac0e31c42b4372f75e1c5f151` |
| Calibri-Review-16x9-embedded.pptx | 7 | `13ced94f23236a8ef39444c26a1f0de05028111046c99556b99fc1e455eae7d2` |

The caller-supplied Calibri faces used to generate this pack have these hashes:

| Face | SHA-256 |
| --- | --- |
| Regular | `89027a8e0dbec88455152e2ec84e03c7eb58f01627a1f7564147596366777fbc` |
| Bold | `84374a631545c8a4963a782e3b5862c84a55f046ed7f2e3487f219c8215305f9` |
| Italic | `a4a54216026cc70a71ab6d18204474e66a7069b6c2cc37c58fff7adcf2fecd37` |
| Bold italic | `d59b243dbbee4ae2e57eb0a0ca06e404ff5d4331427204ccb8b4d4fa078c31e9` |

Fonts and generated decks remain outside Git. These are fixture identities, not
a library font policy. The report does not establish which installed files
PowerPoint resolved for an external-font profile.

The pack covers mixed-face text, template inheritance, tabs/bullets, ordinary
continued tables and connected vertical/rectangular body merges. Each profile
repeated identically across two fresh generation processes and passed portable
saved-grid and independent python-pptx read-back checks. Those checks are separate
from the user's visual verdict.

This acceptance does not extend to later changes, multi-row repeated headers,
chart-cache repair or the opt-in WebKit shared-font transport. The normal app
continues to use inline fonts until the paired native transport comparison passes.

See [the native pack workflow](../Tools/native-fidelity/README.md),
[PR #78 measurements](PREVIEW-PREPARATION-20261016.md) and [PLAN.md](../PLAN.md).
