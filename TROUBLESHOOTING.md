Troubleshooting log

Every real problem hit while building this, and how it got resolved. Same
philosophy as the other project: the fixes are worth more than the code
itself.

GitHub doesn't support IPv6 — and this project is IPv6-only

Symptom

The k3s installer (curl -sfL https://get.k3s.io | sh -) failed with a
connection timeout to update.k3s.io. Later, installing Argo CD via
kubectl apply -f https://raw.githubusercontent.com/... hit the same wall.

Cause

This node has no public IPv4 by design — it's IPv6-only, egress-only
Internet Gateway, no NAT, matching the project's networking decision.
GitHub, in 2026, still does not support IPv6 for any of its core traffic
(github.com, raw.githubusercontent.com, and even git clone over SSH/HTTPS
to github.com itself — confirmed directly with dig: github.com returns
no AAAA record at all, while gitlab.com does). Any download from GitHub
was structurally unreachable from this node.

Options considered

1. NAT64 + DNS64 — AWS's own documented pattern for letting an
   IPv6-only subnet reach IPv4-only destinations. Real infrastructure
   (public subnet, IGW, EIP, NAT Gateway with DNS64), real ongoing cost
   ($0.045/hour, ~$32/month if left running).
2. Host the gitops repo on GitLab instead of GitHub — gitlab.com has a
   real AAAA record, reachable directly over IPv6, zero NAT cost. Clean
   technically, but splits the project across two platforms.
3. Self-hosted git server inside the VPC — zero external dependency,
   most "pure" IPv6-only design, but more infrastructure to run and
   maintain, and loses the easy public-link-to-share property.

Decision

Went with NAT64/DNS64 (option 1), built in bootstrap-ipv4-temp.tf,
disabled (renamed to .tf.disabled) between uses to avoid paying for it
when not needed. It successfully unblocked both the k3s install and the
Argo CD manifest download on the first real attempt once the recipe was
right (public subnet + regular IGW + NAT Gateway + the 64:ff9b::/96
route + enable_dns64 on the workload subnet).

Since Argo CD needs to reach its Git remote continuously (not a one-time
download like k3s), and the whole project is scoped to live about one
month before a full destroy, the decision was to leave NAT64 running
for that month instead of switching hosting platforms or building a
self-hosted git server — reusing the code that's already proven to work
is worth more here than the ~$32/month it costs for a project with a
fixed, short lifespan. Total project budget ceiling agreed: $70,
covering both the permanent piece and the eks-drill weekends combined.

Lesson

"IPv6-first" is the right default for this project's design, but it's
not free when the thing you need to reach (GitHub) hasn't caught up.
The fix isn't to abandon the principle — it's to solve the specific gap
with the right tool (NAT64/DNS64, AWS's own documented answer for this
exact situation) and be honest about what it costs, instead of quietly
breaking the design or hiding the tradeoff.

The security group's default is deny — even for one direction

Symptom

Associating an Elastic IP to the node and adding a route to a real
Internet Gateway still didn't let outbound IPv4 traffic through. The
first curl attempt after adding public IPv4 access still timed out
exactly the same way.

Cause

The security group's egress rule only had ipv6_cidr_blocks = ["::/0"].
AWS security groups don't have an implicit "allow all" per protocol
family — without cidr_blocks (IPv4) explicitly listed, all outbound
IPv4 traffic was blocked regardless of routing being correct.

Lesson

Routing and security groups are two independent layers. A correct route
to the internet means nothing if the security group blocks the traffic
before it ever reaches that route. Check both, every time.

Budgets watch the whole AWS account by default, not just one project

Symptom

Both this project's budget alarm and the unrelated Alarm on Absence
budget alarm fired together, at the same 75% threshold, on the same day
— despite tracking supposedly separate projects.

Cause

Neither aws_budgets_budget resource had a cost_filter. Without one, a
budget watches the entire AWS account's spend, not the spend of any one
project. The real driver was this project's own always-on t3.small node
(~$15/month, not free-tier eligible) plus the NAT Gateway running at the
time — but because neither budget was scoped, the alert looked like it
was about "everything," which made the real cause hard to find at first.

Fix

Added cost_filter { name = "TagKeyValue", values =
["user:Project$kubernetes-by-the-hour"] } to budget.tf, reusing the
Project tag already set in default_tags. Requires activating Project as
a cost allocation tag in Billing Console first (manual step, not
Terraform) or the filter silently matches nothing. Also raised the
budget limit from $10 to $25 to reflect the real cost floor of an
always-on EC2 node — a number that assumed zero idle cost (like the
serverless design in Alarm on Absence) was never going to fit this
project's actual shape.

Lesson

A budget with no cost_filter isn't really "this project's budget" — it's
the whole account's budget wearing this project's name. Scope it on
purpose, or don't be surprised when it fires for reasons that have
nothing to do with the code in this repo.

An unpinned AMI turns an unrelated `terraform apply` into a node rebuild

Symptom

Ran `terraform apply` only to raise the monthly budget limit from $10 to
$25 — a change scoped entirely to budget.tf. The plan also showed
`aws_instance.node must be replaced` (`-/+ destroy and then create
replacement`), triggered by `ami` changing from `ami-0d8e124066f7ed4f7`
to `ami-09179a962fadf762b`. Approved the apply without registering the
implication, and Terraform destroyed the running node — the one with
k3s, Tailscale, and Argo CD already configured and healthy — then built
a brand new instance from scratch.

Cause

node.tf resolves the AMI through `data "aws_ami" "al2023"`, filtering
for "the most recent Amazon Linux 2023 image" rather than pinning a
specific AMI ID. In the days between builds, AWS published a newer
matching AMI, so the data source resolved to a different ID on this
plan. Terraform correctly treats a changed `ami` as forcing replacement
(it's an immutable EC2 launch attribute) — the tool did exactly what
it's supposed to do. The real bug was upstream: nothing pinned the AMI
to a value under our control, so any future `plan`/`apply` — even one
touching a completely unrelated resource like the budget — could
silently trigger this same replacement again.

On top of that, the fresh instance's first boot couldn't rebuild
itself cleanly: cloud-init's k3s install step failed with
`curl: (28) Failed to connect to update.k3s.io:443 after 134201 ms:
Could not connect to server` — a connectivity gap distinct from the
GitHub/NAT64 issue above, still under investigation as of writing this
entry (next step: confirm whether the existing NAT64/DNS64 setup covers
this domain, or whether something about it dropped after the instance
replacement).

Lesson

A `data "aws_ami"` block with no pinned `ami` value doesn't mean "always
get the latest patched image for free" — it means "any `terraform
apply`, for any reason, can silently destroy and rebuild this instance
without ever asking about it directly." For a node carrying live,
non-trivially-reproducible state (a running k3s cluster, Tailscale's
device identity, Argo CD's installed state), pin the exact AMI ID and
treat bumping it as its own deliberate, reviewed change — not a side
effect of touching something unrelated.
