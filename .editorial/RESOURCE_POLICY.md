# Resource Policy

## Principle

`embed-system` is now **resource-first**.

The default curriculum artifact is a high-quality learning map, not an AI-authored replacement textbook. For each topic, identify the smallest set of strong resources that together provide:

1. **truth** — specification, vendor TRM/datasheet, official upstream documentation;
2. **implementation reality** — current upstream source code;
3. **teaching sequence** — a maintained expert course/lab or a durable classic book;
4. **practice direction** — a learner-built experiment/project that exposes the mechanism.

No single class is sufficient for every topic, but do not force all four when two are enough.

## Resource selection order

Prefer, in order:

1. official architecture/vendor/project documentation;
2. exact upstream source code for version-sensitive behavior;
3. maintained training material from recognized engineering organizations/projects;
4. classic books with durable mental models;
5. reputable secondary material;
6. AI explanation.

AI summaries are navigation aids. They are not the authority when a primary source is available.

## Resource selection criteria

Prefer resources with:

- clear technical authority;
- stable or maintained availability;
- direct relevance to the target capability;
- source code, labs or observable examples where useful;
- good scope boundaries;
- explicit versioning for version-sensitive topics;
- a strong maintenance/contribution history;
- licensing that permits linking and reasonable educational use.

Avoid resource lists that are long merely to look comprehensive. A small ranked list is better than twenty undifferentiated links.

## Required annotation

A recommended resource should ideally state:

- **role**: primary truth / implementation / teaching / reference / optional depth;
- **use it for**: exact topics or chapters;
- **do not use it for**: where it is stale, too broad, or not authoritative;
- **priority**: MUST / SHOULD / LATER;
- **version sensitivity**: stable concept vs current implementation detail.

## Upstream source reading

Open-source projects are not decorative references. When source reading is valuable, point the learner to exact paths/functions/data structures rather than saying “read the kernel”.

Record when practical:

- upstream repository;
- relevant tag/release if a frozen teaching baseline matters;
- relevant paths/functions;
- why those paths are pedagogically useful;
- whether the observation is architecture/API stable or implementation-specific.

Do not copy large source blocks into the curriculum when a direct upstream link plus a small explanation is enough.

## Books

Books are for durable mental models, not current-version truth.

Rules:

- never assign a large book cover-to-cover unless there is a strong reason;
- map topics to selected chapters/sections;
- verify version-sensitive kernel/toolchain/build-system claims against current upstream sources;
- do not reproduce copyrighted chapters, figures or long passages;
- use books to explain *why*, primary sources to confirm *what is true now*.

## Courses and labs

Prefer courses that are:

- maintained;
- openly inspectable where possible;
- taught by recognized upstream contributors/engineering organizations;
- rich in practical labs;
- explicit about target platform and assumptions.

Current high-value families include Bootlin training, Linux Kernel Labs, OSTEP, vendor training and official project manuals.

## Experiments

The curriculum should usually **suggest** experiments rather than provide a fully solved bespoke framework.

A good experiment description contains:

```text
question
→ setup
→ what to observe
→ what evidence would discriminate hypotheses
→ what the observation does not prove
```

The learner should implement and debug the experiment unless a small reference implementation is explicitly useful.

## Existing verified artifacts

Earlier Phase 1–3 authoring contains substantial labs, scripts and validation infrastructure. Preserve verified, technically useful work as optional exemplars.

Do not clone that level of scaffolding into future phases by default.

Unverified material may remain when clearly labelled and still pedagogically useful, but it must not be represented as runtime or hardware proof.

## Anti-patterns

Avoid:

> one blog post + AI summary + copied code

Also avoid:

> specification + upstream source + 20 custom scripts + hidden Gate + mutation oracle + synthetic framework for every small topic

Prefer:

> authoritative source + clear learning objective + exact reading target + one good course/book + learner-built experiment

## Maintenance

For current software ecosystems, periodically re-check:

- Linux kernel documentation;
- Bootlin course revisions;
- Buildroot stable/LTS releases;
- Yocto Project documentation;
- U-Boot documentation;
- FreeRTOS documentation/kernel releases;
- vendor reference manuals/errata.

Do not churn stable conceptual resources simply because a newer edition exists; update when the engineering meaning changes.
