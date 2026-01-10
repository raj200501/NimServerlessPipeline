import std/[tables, sequtils, times, strutils]
import ./types
import ./metrics
import ./records
import ./aggregations


type
  HealthStatus* = enum
    healthOk,
    healthDegraded,
    healthFailing

  HealthCheck* = object
    name*: string
    status*: HealthStatus
    message*: string

  HealthSnapshot* = object
    checkedAt*: DateTime
    checks*: seq[HealthCheck]
    metrics*: seq[KeyedMetric]

proc initSnapshot*(): HealthSnapshot =
  HealthSnapshot(checkedAt: now(), checks: @[], metrics: @[])

proc addCheck*(snapshot: var HealthSnapshot, name: string, status: HealthStatus, message: string) =
  snapshot.checks.add(HealthCheck(name: name, status: status, message: message))

proc addMetric*(snapshot: var HealthSnapshot, metric: KeyedMetric) =
  snapshot.metrics.add(metric)

proc worstStatus*(snapshot: HealthSnapshot): HealthStatus =
  var status = healthOk
  for check in snapshot.checks:
    if check.status == healthFailing:
      return healthFailing
    if check.status == healthDegraded:
      status = healthDegraded
  status

proc checkRecordVolume*(collection: RecordCollection, minCount, maxCount: int): HealthCheck =
  let count = collection.records.len
  if count < minCount:
    HealthCheck(name: "record_volume", status: healthDegraded, message: "below expected volume")
  elif count > maxCount:
    HealthCheck(name: "record_volume", status: healthDegraded, message: "above expected volume")
  else:
    HealthCheck(name: "record_volume", status: healthOk, message: "within range")

proc checkFailureRate*(collection: RecordCollection, maxRate: float): HealthCheck =
  if collection.records.len == 0:
    return HealthCheck(name: "failure_rate", status: healthOk, message: "no records")
  let counts = collection.recordStatusCounts()
  let failed = counts.getOrDefault(recordFailed, 0)
  let rate = float(failed) / float(collection.records.len)
  if rate > maxRate:
    HealthCheck(name: "failure_rate", status: healthFailing, message: "failure rate above threshold")
  else:
    HealthCheck(name: "failure_rate", status: healthOk, message: "failure rate acceptable")

proc buildSnapshot*(collection: RecordCollection, minCount, maxCount: int, maxFailureRate: float): HealthSnapshot =
  result = initSnapshot()
  result.addCheck(checkRecordVolume(collection, minCount, maxCount))
  result.addCheck(checkFailureRate(collection, maxFailureRate))
  result.metrics = computeAggregationMetrics(numericStats(collection, "score"))

proc snapshotSummary*(snapshot: HealthSnapshot): seq[string] =
  result.add("checked_at=" & $snapshot.checkedAt)
  result.add("status=" & $snapshot.worstStatus())
  for check in snapshot.checks:
    result.add(check.name & "=" & $check.status & " " & check.message)

proc metricsSummary*(snapshot: HealthSnapshot): seq[string] =
  snapshot.metrics.summarizeMetrics()

proc statusLine*(snapshot: HealthSnapshot): string =
  "health=" & $snapshot.worstStatus() & " checks=" & $snapshot.checks.len

proc tagSnapshot*(snapshot: var HealthSnapshot, labels: Table[string, string]) =
  for metric in snapshot.metrics.mitems:
    for key, value in labels:
      metric.labels[key] = value

proc compactSnapshot*(snapshot: HealthSnapshot): string =
  snapshotSummary(snapshot).join(" | ")
