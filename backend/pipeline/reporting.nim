import std/[tables, sequtils, strutils, times]
import ./types
import ./records
import ./aggregations
import ./metrics

type
  ReportSection* = object
    title*: string
    lines*: seq[string]

  Report* = object
    heading*: string
    generatedAt*: DateTime
    sections*: seq[ReportSection]

proc initReport*(heading: string): Report =
  Report(heading: heading, generatedAt: now(), sections: @[])

proc addSection*(report: var Report, title: string, lines: seq[string]) =
  report.sections.add(ReportSection(title: title, lines: lines))

proc addLine*(report: var Report, title: string, line: string) =
  var updated = false
  for section in report.sections.mitems:
    if section.title == title:
      section.lines.add(line)
      updated = true
  if not updated:
    report.sections.add(ReportSection(title: title, lines: @[line]))

proc renderSection*(section: ReportSection): string =
  var output = "## " & section.title
  for line in section.lines:
    output.add("\n- " & line)
  output

proc renderReport*(report: Report): string =
  var output = "# " & report.heading & "\nGenerated: " & $report.generatedAt
  for section in report.sections:
    output.add("\n\n" & section.renderSection())
  output

proc renderTable*(headers: seq[string], rows: seq[seq[string]]): seq[string] =
  if headers.len == 0:
    return @[]
  let headerLine = "| " & headers.join(" | ") & " |"
  let separator = "| " & headers.mapIt("---").join(" | ") & " |"
  result.add(headerLine)
  result.add(separator)
  for row in rows:
    result.add("| " & row.join(" | ") & " |")

proc sectionFromAggregation*(title: string, aggregation: AggregationResult): ReportSection =
  ReportSection(title: title, lines: summarizeAggregation(aggregation))

proc sectionFromMetrics*(title: string, metrics: seq[KeyedMetric]): ReportSection =
  ReportSection(title: title, lines: summarizeMetrics(metrics))

proc sectionFromRecords*(title: string, collection: RecordCollection, limit = 10): ReportSection =
  var lines: seq[string] = @[]
  for record in collection.records[0 ..< min(limit, collection.records.len)]:
    lines.add(record.key.id & " => " & record.fieldsToMap().len.toString())
  ReportSection(title: title, lines: lines)

proc recordOverview*(collection: RecordCollection): seq[string] =
  var lines: seq[string] = @[]
  lines.add("namespace: " & collection.namespace)
  lines.add("records: " & $collection.records.len)
  lines.add(collection.summaryLine())
  lines

proc renderRecordTable*(collection: RecordCollection, fieldOrder: seq[string], limit = 10): seq[string] =
  var rows: seq[seq[string]] = @[]
  for record in collection.records[0 ..< min(limit, collection.records.len)]:
    var row: seq[string] = @[]
    for field in fieldOrder:
      if record.fields.hasKey(field):
        row.add(record.fields[field].fieldValueToString())
      else:
        row.add("")
    rows.add(row)
  renderTable(fieldOrder, rows)

proc addAggregationSection*(report: var Report, title: string, aggregation: AggregationResult) =
  report.sections.add(sectionFromAggregation(title, aggregation))

proc addMetricsSection*(report: var Report, title: string, metrics: seq[KeyedMetric]) =
  report.sections.add(sectionFromMetrics(title, metrics))

proc addRecordSection*(report: var Report, title: string, collection: RecordCollection, limit = 10) =
  report.sections.add(sectionFromRecords(title, collection, limit))

proc addTableSection*(report: var Report, title: string, headers: seq[string], rows: seq[seq[string]]) =
  report.sections.add(ReportSection(title: title, lines: renderTable(headers, rows)))

proc addOverviewSection*(report: var Report, collection: RecordCollection) =
  report.sections.add(ReportSection(title: "Overview", lines: recordOverview(collection)))

proc renderCompact*(report: Report): seq[string] =
  result.add(report.heading & " (" & $report.generatedAt & ")")
  for section in report.sections:
    result.add("[" & section.title & "]")
    result.add(section.lines.join(" | "))

proc renderStatusLine*(summary: BatchSummary): string =
  let finished = if summary.finishedAt.isSome: $summary.finishedAt.get() else: "pending"
  "batch=" & summary.batchId & " total=" & $summary.total & " processed=" & $summary.processed & " skipped=" & $summary.skipped & " failed=" & $summary.failed & " finished=" & finished

proc addStatusSection*(report: var Report, summary: BatchSummary) =
  report.addSection("Status", @[renderStatusLine(summary)])

proc renderMarkdownReport*(report: Report): seq[string] =
  report.renderReport().splitLines()
