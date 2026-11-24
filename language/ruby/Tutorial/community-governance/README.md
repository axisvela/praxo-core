# Ruby community governance (OG-04)

A bounded first slice of [OG-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a maintainer bot. It classifies fixed synthetic issues and drafts a review-only
reviewer request. No automatic issue closure, maintainer impersonation or live
GitHub access.

## Why this language and runtime?

- **Selection basis:** An existing Ruby-based community bot could add a review step
  without a new service. No maintainer consumer is verified here.
- **Demonstrated fit:** Core callbacks return fixed issue classifications and a
  reviewer request. No issue text is parsed and no GitHub API is called.
- **Choose when:** Learning the Core seam for an existing Ruby automation.
- **Do not choose when:** Expecting moderation, classification quality or GitHub
  integration. Compare direct GitHub automation and explicit moderation rules.
- **Evidence limit:** Core integration fixture only; no issue crawl, moderation
  decision, maintainer identity, closure or impersonation protection claim.

Run from the repository root:

```bash
ruby -I language/ruby/lib language/ruby/Tutorial/community-governance/app.rb --test
ruby -I language/ruby/lib language/ruby/Tutorial/community-governance/app.rb
ruby -I language/ruby/lib language/ruby/Tutorial/community-governance/app.rb --repo repo-200
ruby -I language/ruby/lib language/ruby/Tutorial/community-governance/app.rb --simulate-failure
```

Expected test output: `Ruby OG-04 community-governance tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_issues` returns 4 fixed issues (`bug=2`, `docs=1`, `question=1`) with one
unlabeled for `repo-100`; `draft_guidance` returns one reviewer request with
`status=draft_only`, `review_required=true`, `closures=0` and `impersonations=0`.
Policy limits the repository and final `draft_reviewer_request` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-repository denial, and one read/zero drafts for the simulated issue-index
outage. Real classification, moderation and maintainer action belong to the
community.
