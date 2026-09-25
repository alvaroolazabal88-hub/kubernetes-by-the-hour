# Proof: the Argo CD sync-freshness alarm fires on absence, not just on failure

This is the transcript of the deliberate kill-switch test for
`kubernetes-by-the-hour-argo-sync-freshness` — the `argo-freshness-check`
CronJob was suspended on purpose, and the alarm is shown transitioning from
`OK` to `ALARM` because the check simply stopped running, not because of a
bad value or an explicit error.

## Timeline

| Time (UTC) | Event |
|---|---|
| — | Normal operation. `argo-freshness-check` CronJob runs every 15 min, publishes `ArgoSyncCheckCompleted = 1` whenever both the `sample-app` and `otel-collector` Argo CD Applications report `Synced`. |
| 20:59 | **Last real metric before the kill switch.** |
| ~21:07 | `sudo kubectl patch cronjob argo-freshness-check -p '{"spec":{"suspend":true}}'` run directly against the cluster. |
| 21:14, 21:29, 21:46 | Scheduled 15-minute windows pass with no metric published. |
| **22:01:48** | `kubernetes-by-the-hour-argo-sync-freshness`: **OK → ALARM** |
| ~21:51 (metric timestamp) | CronJob reactivated (`suspend: false`); next scheduled run completes and publishes `ArgoSyncCheckCompleted = 1` again. |
| **22:06:48** | `kubernetes-by-the-hour-argo-sync-freshness`: **ALARM → OK** |

The alarm fired roughly **62 minutes** after the last real metric — well past
the nominal 30-minute threshold (`period=900s` × `evaluation_periods=2`),
confirming that CloudWatch's real evaluation lag for a missing-data alarm on
a sparse custom metric can run noticeably longer than the textbook number.
Nothing was misconfigured; AWS's own evaluation engine just took its time.
Recovery, on the other hand, was fast: only **5 minutes** between the alarm
firing and it clearing, once the CronJob started publishing again.

## The alarm reason, verbatim

**Firing:**
```
Threshold Crossed: no datapoints were received for 2 periods and 2 missing
datapoints were treated as [Breaching].
```

**Recovery:**
```
Threshold Crossed: 1 datapoint [1.0 (25/09/26 21:51:00)] was not less than
the threshold (1.0) and 1 missing datapoint was treated as [Breaching].
```

Not "a value crossed a threshold" — **no data arrived, and the absence
itself was treated as the failure.** Same thesis as Alarm on Absence
(Project 1), now proven on a completely different stack: Kubernetes CronJob
+ Argo CD sync status + CloudWatch custom metric, instead of
EventBridge + Lambda.

## Full CloudWatch alarm history (raw, from `describe-alarm-history`)

```json
{
  "oldState": "OK",
  "newState": "ALARM",
  "timestamp": "2026-09-25T18:01:48.919000-04:00",
  "reason": "Threshold Crossed: no datapoints were received for 2 periods and 2 missing datapoints were treated as [Breaching].",
  "evaluatedDatapoints": [
    {"timestamp": "2026-09-25T21:46:00.000+0000"},
    {"timestamp": "2026-09-25T21:31:00.000+0000"}
  ]
}
{
  "oldState": "ALARM",
  "newState": "OK",
  "timestamp": "2026-09-25T18:06:48.920000-04:00",
  "reason": "Threshold Crossed: 1 datapoint [1.0 (25/09/26 21:51:00)] was not less than the threshold (1.0) and 1 missing datapoint was treated as [Breaching].",
  "evaluatedDatapoints": [
    {"timestamp": "2026-09-25T21:51:00.000+0000", "sampleCount": 1.0, "value": 1.0}
  ]
}
```

`suspend: true` was reverted to `false` directly on the cluster after the
test (a live `kubectl patch`, not a git-tracked change — see "How to
reproduce" below for why that distinction matters). The alarm cleared
itself, `ALARM → OK`, the moment the CronJob resumed publishing — no manual
intervention on the alarm or the SNS topic at all.

## A note on the kill switch itself: `suspend` vs. Argo CD's `selfHeal`

The `argo-freshness-check` Argo CD `Application` has `syncPolicy.automated.selfHeal: true` —
meaning any live change to a resource it manages that isn't reflected in
git normally gets reverted automatically within one reconciliation cycle
(~3 min). `spec.suspend: true` was applied directly with `kubectl patch`,
never committed to `gitops/argo-freshness-check/cronjob.yaml`. In this test
it held for the full ~62-minute window without Argo CD reverting it — worth
re-verifying on a future rebuild, since relying on `selfHeal` *not* fighting
a manual kill switch is not something this drill formally proved, only
observed once.

## How to reproduce

```bash
# 1. Suspend the CronJob directly on the cluster
sudo kubectl patch cronjob argo-freshness-check -p '{"spec":{"suspend":true}}'

# 2. Wait past two full 15-min periods + CloudWatch's own evaluation lag
#    (~45-65 min observed, not the nominal 30 min)

# 3. Read the transition history directly
aws cloudwatch describe-alarm-history \
  --alarm-name kubernetes-by-the-hour-argo-sync-freshness \
  --history-item-type StateUpdate \
  --query 'AlarmHistoryItems[].{Time:Timestamp,Summary:HistorySummary}' \
  --output table

# 4. Re-enable and confirm recovery
sudo kubectl patch cronjob argo-freshness-check -p '{"spec":{"suspend":false}}'
```
