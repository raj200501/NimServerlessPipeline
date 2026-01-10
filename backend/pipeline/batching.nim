import std/[sequtils, strutils, times, options]
import ./types
import ./records


type
  BatchPlan* = object
    batchId*: string
    batchSize*: int
    createdAt*: DateTime

  BatchResult* = object
    plan*: BatchPlan
    summaries*: seq[BatchSummary]

proc initBatchPlan*(batchId: string, batchSize: int): BatchPlan =
  BatchPlan(batchId: batchId, batchSize: batchSize, createdAt: now())

proc splitBatches*(collection: RecordCollection, plan: BatchPlan): seq[RecordCollection] =
  if plan.batchSize <= 0:
    return @[collection]
  var idx = 0
  while idx < collection.records.len:
    let endIdx = min(idx + plan.batchSize, collection.records.len)
    var batch = initCollection(collection.namespace)
    for record in collection.records[idx ..< endIdx]:
      batch.addRecord(record)
    result.add(batch)
    idx = endIdx

proc summarizeBatch*(batchId: string, batch: RecordCollection): BatchSummary =
  var summary = initBatchSummary(batchId, batch.records.len)
  for record in batch.records:
    case record.metadata.status
    of recordProcessed:
      summary.processed += 1
    of recordSkipped:
      summary.skipped += 1
    of recordFailed:
      summary.failed += 1
    else:
      discard
  summary.markBatchFinished()
  summary

proc processBatches*(collection: RecordCollection, plan: BatchPlan, handler: proc (batch: var RecordCollection) {.closure.}): BatchResult =
  var summaries: seq[BatchSummary] = @[]
  for idx, batch in splitBatches(collection, plan):
    var mutableBatch = batch
    handler(mutableBatch)
    summaries.add(summarizeBatch(plan.batchId & "-" & $idx, mutableBatch))
  BatchResult(plan: plan, summaries: summaries)

proc summarizePlan*(result: BatchResult): seq[string] =
  for summary in result.summaries:
    let finished = if summary.finishedAt.isSome: $summary.finishedAt.get() else: "pending"
    result.add(
      "batch=" & summary.batchId &
      " total=" & $summary.total &
      " processed=" & $summary.processed &
      " skipped=" & $summary.skipped &
      " failed=" & $summary.failed &
      " finished=" & finished
    )

proc mergeSummaries*(summaries: seq[BatchSummary]): BatchSummary =
  if summaries.len == 0:
    return initBatchSummary("", 0)
  var merged = initBatchSummary("merged", 0)
  for summary in summaries:
    merged.total += summary.total
    merged.processed += summary.processed
    merged.skipped += summary.skipped
    merged.failed += summary.failed
  merged.markBatchFinished()
  merged

proc tagBatch*(collection: var RecordCollection, batchId: string) =
  for record in collection.records.mitems:
    record.metadata.addTag("batch:" & batchId)

proc withBatchTags*(collection: RecordCollection, plan: BatchPlan): RecordCollection =
  result = collection
  result.addBatchTag("batch:" & plan.batchId)

proc routeByPrefix*(collection: RecordCollection, fieldName: string): seq[RecordCollection] =
  var groups = initTable[string, RecordCollection]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let raw = record.fields[fieldName].fieldValueToString()
      let prefix = if raw.len > 0: raw[0] else: '_'
      let key = $prefix
      if not groups.hasKey(key):
        groups[key] = initCollection(collection.namespace)
      groups[key].addRecord(record)
  result = groups.values.toSeq
