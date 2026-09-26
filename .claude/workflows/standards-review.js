export const meta = {
  name: 'standards-review',
  description: 'Review a diff against every governing CLAUDE.md rule with fresh finders, semantic dedup, and adversarial verification',
  whenToUse: 'Audit a change for compliance with the CLAUDE.md standards that govern it. args: optional target string (PR number, branch, ref range, or path); defaults to the current branch plus uncommitted changes.',
  phases: [
    { title: 'Scope', detail: 'resolve the diff and extract the governing rules' },
    { title: 'Find', detail: 'one fresh finder per rule group and file batch; rounds repeat until one adds no new issue' },
    { title: 'Merge', detail: 'collapse duplicate findings against every issue already known' },
    { title: 'Verify', detail: 'three skeptics with distinct lenses per batch of issues; two must agree' },
  ],
}

if (args !== undefined && typeof args !== 'string') {
  throw new Error('standards-review takes an optional string target: a PR number, branch, ref range, or path')
}

const target = args?.trim() || 'the current branch: commits ahead of its upstream, or of the default branch when it has no upstream, plus staged, unstaged, and untracked changes'
const FILES_PER_FINDER = 10
const ISSUES_PER_VERIFIER = 5
const MAX_FIND_ROUNDS = 3
const VOTES_TO_DECIDE = 2

const SCOPE_SCHEMA = {
  type: 'object',
  required: ['diffCommand', 'files', 'excluded', 'dimensions'],
  properties: {
    diffCommand: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    excluded: { type: 'array', items: { type: 'string' } },
    dimensions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'rank', 'rules'],
        properties: {
          title: { type: 'string' },
          rank: { type: 'integer', minimum: 1 },
          rules: { type: 'array', minItems: 1, items: { type: 'string' } },
        },
      },
    },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'rule', 'violation', 'evidence', 'fix'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer', minimum: 1 },
          rule: { type: 'string' },
          violation: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const MERGE_SCHEMA = {
  type: 'object',
  required: ['issues', 'duplicatesOfKnown'],
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        required: ['sources', 'file', 'line', 'violation', 'evidence', 'fix'],
        properties: {
          sources: { type: 'array', minItems: 1, items: { type: 'integer', minimum: 0 } },
          file: { type: 'string' },
          line: { type: 'integer', minimum: 1 },
          violation: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
    duplicatesOfKnown: { type: 'array', items: { type: 'integer', minimum: 0 } },
  },
}

const VERDICTS_SCHEMA = {
  type: 'object',
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'refuted', 'reason'],
        properties: {
          id: { type: 'integer' },
          refuted: { type: 'boolean' },
          reason: { type: 'string' },
        },
      },
    },
  },
}

const LENSES = [
  'Reproduce: read the code at each location and its context. Refute if the code does not do what the claim says, or the line is outside the change and the rule does not extend to existing code.',
  'Applicability: refute if the rules do not govern this code, an exemption stated in the governing CLAUDE.md covers it, or the claim rests on speculation rather than the code.',
  'Priority: refute if the current code is the better choice under the priority order the governing CLAUDE.md files state, or the proposed fix would break a higher-priority rule.',
]

const gaps = []
function reportGap(message) {
  gaps.push(message)
  log(message)
}

phase('Scope')
const scope = await agent(
  `Prepare a standards review of ${target}.

1. Find one shell command that prints the complete change under review, including the full contents of untracked files, and run it to confirm it works from the current directory. Use gh for a pull request. For a path, use its uncommitted changes, or its whole contents if it has none.
2. List every changed file as a path the other reviewers can open from the current directory. Put generated files, lockfiles, vendored code, and binaries in excluded instead.
3. Collect every rule from the CLAUDE.md files that govern the changed files: the user and project instructions you were given, plus any CLAUDE.md in a directory that contains a changed file or in its ancestors up to the repository root. Quote each rule verbatim. Keep every rule a change could violate, including rules about tests, dependencies, quality gates, comments, and documentation files; drop only rules about conversational behavior.
4. Group the rules into 4 to 8 dimensions of closely related rules. Rank them from 1, highest priority first, by the priority order the CLAUDE.md files state.`,
  { label: 'scope', schema: SCOPE_SCHEMA },
)
if (!scope) throw new Error('The scope agent failed, so nothing was reviewed')
if (scope.excluded.length) log(`Excluded from review: ${scope.excluded.join(', ')}`)
if (!scope.files.length) return { target, diffCommand: scope.diffCommand, confirmed: [], message: 'No reviewable changes' }
if (!scope.dimensions.length) return { target, diffCommand: scope.diffCommand, confirmed: [], message: 'No governing CLAUDE.md rules found' }

const fileBatches = []
for (let i = 0; i < scope.files.length; i += FILES_PER_FINDER) fileBatches.push(scope.files.slice(i, i + FILES_PER_FINDER))
const work = scope.dimensions.flatMap(dimension =>
  fileBatches.map((files, b) => ({
    dimension,
    files,
    label: fileBatches.length > 1 ? `${dimension.title} ${b + 1}/${fileBatches.length}` : dimension.title,
  })),
)

function verifyBatch(batch) {
  const claims = batch
    .map(issue => `#${issue.id} ${issue.file}:${issue.line}\nRules: ${issue.rules.join(' | ')}\nClaim: ${issue.violation}\nQuoted code: ${issue.evidence}\nProposed fix: ${issue.fix}`)
    .join('\n\n')
  return parallel(LENSES.map((lens, i) => () => agent(
    `Each issue below claims that the change printed by ${scope.diffCommand} violates a CLAUDE.md rule. Try to refute each claim on its own merits, and answer refuted=true when uncertain. Return one verdict per issue id, each reason in at most two sentences.

Your lens. ${lens}

${claims}`,
    { label: `verify #${batch.map(issue => issue.id).join(',')} lens ${i + 1}`, phase: 'Verify', schema: VERDICTS_SCHEMA },
  ))).then(results => batch.map(issue => {
    const votes = results.filter(Boolean).flatMap(r => r.verdicts.filter(v => v.id === issue.id).slice(0, 1))
    const upheld = votes.filter(v => !v.refuted).length
    const refuted = votes.length - upheld
    return {
      ...issue,
      status: upheld >= VOTES_TO_DECIDE ? 'confirmed' : refuted >= VOTES_TO_DECIDE ? 'refuted' : 'unverified',
      votes: `${upheld}/${votes.length} upheld`,
      reasons: votes.map(v => `${v.refuted ? 'refuted' : 'upheld'}: ${v.reason}`),
    }
  }))
}

const issues = []
const verifications = []
for (let round = 1; round <= MAX_FIND_ROUNDS; round++) {
  const knownList = issues.map(issue => `#${issue.id} ${issue.file}:${issue.line} ${issue.violation}`).join('\n')
  const known = knownList ? `\n\nKnown issues, already reported; do not report them again:\n${knownList}` : ''
  const raw = (await parallel(work.map(item => () => agent(
    `Review the change printed by: ${scope.diffCommand}
Restrict the review to these files: ${item.files.join(', ')}

Find every violation of these rules:
${item.dimension.rules.map(rule => `- ${rule}`).join('\n')}

Other reviewers cover every other rule. Read surrounding code, callers, and existing helpers as needed to judge. Report violations the change introduces, and violations in code the change touches when a rule explicitly extends to existing code. Report each violation once, under the rule above that it most directly breaks, and only when you can point to the code; an empty list is the right answer when there are none. For each violation give the file, its line in the new version, the rule verbatim, the violation in one sentence, the offending code quoted, and the minimal fix.${known}`,
    { label: `${item.label} r${round}`, phase: 'Find', schema: FINDINGS_SCHEMA },
  ).then(result => {
    if (!result) reportGap(`${item.label}: finder round ${round} failed, so coverage of ${item.files.join(', ')} is incomplete`)
    return (result?.findings ?? []).map(finding => ({ ...finding, rank: item.dimension.rank }))
  })))).filter(Boolean).flat()
  if (!raw.length) break

  const merged = await agent(
    `Reviewers each checked the change printed by ${scope.diffCommand} against a different group of CLAUDE.md rules, so several may have reported the same underlying problem.

Known issues, already recorded:
${knownList || 'none'}

New raw findings, numbered:
${raw.map((f, i) => `[${i}] ${f.file}:${f.line} (${f.rule}) ${f.violation}\n    code: ${f.evidence}\n    fix: ${f.fix}`).join('\n')}

Put the index of every raw finding that restates a known issue in duplicatesOfKnown. Group the remaining raw findings into distinct issues, one per underlying problem that a single fix resolves, listing all of its raw indices in sources, with the clearest location, violation, quoted code, and fix. Keep problems that need separate fixes as separate issues, even on the same line. Every raw index must appear exactly once.`,
    { label: `merge r${round}`, phase: 'Merge', schema: MERGE_SCHEMA },
  )
  if (!merged) reportGap(`merge round ${round} failed, so its raw findings are verified without deduplication`)
  const isRawIndex = i => i < raw.length
  const groups = (merged?.issues ?? []).map(issue => ({ ...issue, sources: issue.sources.filter(isRawIndex) })).filter(issue => issue.sources.length)
  const covered = new Set([...groups.flatMap(issue => issue.sources), ...(merged?.duplicatesOfKnown ?? [])])
  const uncovered = raw.flatMap((f, i) => (covered.has(i) ? [] : [{ ...f, sources: [i] }]))
  if (merged && uncovered.length) reportGap(`merge round ${round} left ${uncovered.length} raw findings ungrouped; they are verified individually`)

  const fresh = [...groups, ...uncovered].map((group, n) => ({
    id: issues.length + n + 1,
    file: group.file,
    line: group.line,
    rules: [...new Set(group.sources.map(i => raw[i].rule))],
    rank: Math.min(...group.sources.map(i => raw[i].rank)),
    violation: group.violation,
    evidence: group.evidence,
    fix: group.fix,
  }))
  if (!fresh.length) break
  issues.push(...fresh)

  const byFile = {}
  for (const issue of fresh) (byFile[issue.file] ??= []).push(issue)
  for (const fileIssues of Object.values(byFile)) {
    for (let i = 0; i < fileIssues.length; i += ISSUES_PER_VERIFIER) verifications.push(verifyBatch(fileIssues.slice(i, i + ISSUES_PER_VERIFIER)))
  }
  if (round === MAX_FIND_ROUNDS) reportGap(`round ${round} still found new issues; stopped at the round cap`)
}

const reviewed = (await Promise.all(verifications)).flat()
const byPriority = (a, b) => a.rank - b.rank || a.file.localeCompare(b.file) || a.line - b.line
const withStatus = status => reviewed.filter(issue => issue.status === status).sort(byPriority)

return {
  target,
  diffCommand: scope.diffCommand,
  reviewedFiles: scope.files,
  excluded: scope.excluded,
  dimensions: scope.dimensions.map(d => `${d.rank}. ${d.title} (${d.rules.length} rules)`),
  confirmed: withStatus('confirmed'),
  unverified: withStatus('unverified'),
  refuted: withStatus('refuted').map(issue => `${issue.file}:${issue.line} ${issue.violation}`),
  gaps,
}
