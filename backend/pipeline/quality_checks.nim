import std/[tables, sequtils, strutils, times]
import ./types
import ./records


type
  QualityDimension* = enum
    qualityCompleteness,
    qualityValidity,
    qualityUniqueness,
    qualityConsistency,
    qualityTimeliness

  QualityIssue* = object
    dimension*: QualityDimension
    fieldName*: string
    message*: string
    recordId*: string

  QualityReport* = object
    issues*: seq[QualityIssue]
    scores*: Table[QualityDimension, float]

proc initQualityReport*(): QualityReport =
  QualityReport(issues: @[], scores: initTable[QualityDimension, float]())

proc addIssue*(report: var QualityReport, dimension: QualityDimension, fieldName, message, recordId: string) =
  report.issues.add(QualityIssue(dimension: dimension, fieldName: fieldName, message: message, recordId: recordId))

proc completenessScore*(collection: RecordCollection, requiredFields: seq[string]): float =
  if collection.records.len == 0:
    return 0.0
  var present = 0
  let total = collection.records.len * requiredFields.len
  for record in collection.records:
    for field in requiredFields:
      if record.fields.hasKey(field) and record.fields[field].fieldValueToString().strip().len > 0:
        present += 1
  float(present) / float(total)

proc uniquenessScore*(collection: RecordCollection, fieldName: string): float =
  if collection.records.len == 0:
    return 0.0
  let distinctCount = collection.distinctValues(fieldName).len
  float(distinctCount) / float(collection.records.len)

proc validityScore*(collection: RecordCollection, rules: seq[(string, proc (value: string): bool {.closure.})]): float =
  if collection.records.len == 0:
    return 0.0
  var validCount = 0
  for record in collection.records:
    var valid = true
    for (fieldName, check) in rules:
      if record.fields.hasKey(fieldName):
        if not check(record.fields[fieldName].fieldValueToString()):
          valid = false
      else:
        valid = false
    if valid:
      validCount += 1
  float(validCount) / float(collection.records.len)

proc timelinessScore*(collection: RecordCollection, fieldName: string, thresholdDays: int): float =
  if collection.records.len == 0:
    return 0.0
  var onTime = 0
  let threshold = initDuration(days = thresholdDays)
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let raw = record.fields[fieldName].fieldValueToString()
      try:
        let timestamp = parse(raw)
        if now() - timestamp <= threshold:
          onTime += 1
      except ValueError:
        discard
  float(onTime) / float(collection.records.len)

proc consistencyScore*(collection: RecordCollection, fieldName: string, allowed: seq[string]): float =
  if collection.records.len == 0:
    return 0.0
  var consistent = 0
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      if record.fields[fieldName].fieldValueToString() in allowed:
        consistent += 1
  float(consistent) / float(collection.records.len)

proc evaluateQuality*(collection: RecordCollection, requiredFields: seq[string], uniqueField: string): QualityReport =
  result = initQualityReport()
  result.scores[qualityCompleteness] = completenessScore(collection, requiredFields)
  result.scores[qualityUniqueness] = uniquenessScore(collection, uniqueField)

proc flagMissingFields*(collection: RecordCollection, requiredFields: seq[string], report: var QualityReport) =
  for record in collection.records:
    for field in requiredFields:
      if not record.fields.hasKey(field) or record.fields[field].fieldValueToString().strip().len == 0:
        report.addIssue(qualityCompleteness, field, "missing value", record.key.id)

proc flagInvalidValues*(collection: RecordCollection, fieldName: string, allowed: seq[string], report: var QualityReport) =
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let value = record.fields[fieldName].fieldValueToString()
      if value notin allowed:
        report.addIssue(qualityValidity, fieldName, "unexpected value", record.key.id)

proc flagDuplicateValues*(collection: RecordCollection, fieldName: string, report: var QualityReport) =
  var seen = initTable[string, string]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let value = record.fields[fieldName].fieldValueToString()
      if seen.hasKey(value):
        report.addIssue(qualityUniqueness, fieldName, "duplicate value", record.key.id)
      else:
        seen[value] = record.key.id

proc reportSummary*(report: QualityReport): seq[string] =
  for dimension, score in report.scores:
    result.add($dimension & ":" & $(score * 100).formatFloat(ffDecimal, 1) & "%")
  result.add("issues=" & $report.issues.len)

proc issuesByField*(report: QualityReport): Table[string, seq[QualityIssue]] =
  result = initTable[string, seq[QualityIssue]]()
  for issue in report.issues:
    if not result.hasKey(issue.fieldName):
      result[issue.fieldName] = @[]
    result[issue.fieldName].add(issue)

proc issuesByDimension*(report: QualityReport): Table[QualityDimension, seq[QualityIssue]] =
  result = initTable[QualityDimension, seq[QualityIssue]]()
  for issue in report.issues:
    if not result.hasKey(issue.dimension):
      result[issue.dimension] = @[]
    result[issue.dimension].add(issue)
