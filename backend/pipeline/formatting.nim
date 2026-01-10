import std/[sequtils, strutils, tables, options]
import ./records
import ./types

proc formatKey*(key: RecordKey): string =
  key.namespace & ":" & key.id

proc formatRecordLine*(record: Record, fields: seq[string]): string =
  var parts: seq[string] = @[]
  parts.add(formatKey(record.key))
  for field in fields:
    if record.fields.hasKey(field):
      parts.add(record.fields[field].fieldValueToString())
    else:
      parts.add("")
  parts.join(" | ")

proc formatRecords*(collection: RecordCollection, fields: seq[string], limit = 20): seq[string] =
  let sample = collection.records[0 ..< min(limit, collection.records.len)]
  for record in sample:
    result.add(formatRecordLine(record, fields))

proc formatFieldSummary*(record: Record): seq[string] =
  for key in record.fieldNames():
    result.add(key & "=" & record.fields[key].fieldValueToString())

proc formatMetadata*(metadata: RecordMetadata): string =
  let tags = if metadata.tags.len > 0: metadata.tags.join(",") else: "-"
  let notes = if metadata.notes.len > 0: metadata.notes.join(";") else: "-"
  "status=" & $metadata.status & " tags=" & tags & " notes=" & notes

proc formatRecordDetailed*(record: Record): seq[string] =
  result.add("key=" & formatKey(record.key))
  result.add("metadata=" & formatMetadata(record.metadata))
  for fieldLine in record.formatFieldSummary():
    result.add("field " & fieldLine)

proc formatRecordTable*(collection: RecordCollection, fields: seq[string], limit = 20): seq[seq[string]] =
  for record in collection.records[0 ..< min(limit, collection.records.len)]:
    var row: seq[string] = @[]
    row.add(formatKey(record.key))
    for field in fields:
      if record.fields.hasKey(field):
        row.add(record.fields[field].fieldValueToString())
      else:
        row.add("")
    result.add(row)

proc formatMetricLine*(metric: KeyedMetric): string =
  var labels: seq[string] = @[]
  for key, value in metric.labels:
    labels.add(key & "=" & value)
  let suffix = if labels.len > 0: "{" & labels.join(",") & "}" else: ""
  metric.name & suffix & "=" & $metric.value

proc formatMetricLines*(metrics: seq[KeyedMetric]): seq[string] =
  for metric in metrics:
    result.add(formatMetricLine(metric))

proc formatBatchSummary*(summary: BatchSummary): string =
  let finished = if summary.finishedAt.isSome: $summary.finishedAt.get() else: "pending"
  "batch=" & summary.batchId & " total=" & $summary.total & " processed=" & $summary.processed & " skipped=" & $summary.skipped & " failed=" & $summary.failed & " finished=" & finished

proc formatTagSummary*(tags: seq[string]): string =
  if tags.len == 0:
    "(none)"
  else:
    tags.join(",")
