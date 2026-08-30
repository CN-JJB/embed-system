# Resource Policy

## Principle

The curriculum should combine four complementary resource classes:

1. **Official specifications and documentation** — define what is true.
2. **High-quality open-source projects** — show how real systems are implemented.
3. **Classic books** — build stable mental models and conceptual continuity.
4. **High-quality courses/labs** — provide proven teaching sequences and exercises.

No single class is sufficient by itself.

## Open-Source Project Use

Open-source projects are not decorative references. They may be used for:

- source-reading assignments;
- architecture walkthroughs;
- debugging exercises;
- patch archaeology;
- API/ABI study;
- test strategy;
- build-system study;
- contribution practice.

When studying a project, record:

- upstream repository;
- license;
- tag/commit used;
- relevant paths;
- why the code is pedagogically useful;
- whether the code is representative or unusually specialized.

Do not copy large blocks into the tutorial when a small excerpt, diagram, or direct upstream reference is enough.

## Classic Book Use

Books are used to establish durable mental models and to cross-check teaching structure.

Rules:

- do not reproduce copyrighted chapters or long passages;
- cite the book and specific chapter/section;
- explain concepts in original wording;
- verify version-sensitive engineering claims against current official sources;
- convert book concepts into original labs and observable experiments.

## Resource Selection Criteria

Prefer resources with:

- strong technical reputation;
- clear provenance;
- stable availability;
- pedagogical depth;
- direct relevance to the target skill tree;
- practical experiments or source code;
- a maintenance history when the topic is version-sensitive.

## Resource Roles

A single topic may intentionally use different resources for different jobs:

- **specification** for truth;
- **source code** for implementation;
- **book** for conceptual model;
- **course** for teaching sequence;
- **lab** for verification;
- **job descriptions** for career relevance.

## Anti-Pattern

Avoid designing a chapter as:

> one blog post + AI summary + copied code

Prefer:

> primary source + upstream code + classic explanation + original lab + measured evidence.
