import std/[tables, times, options, sequtils]

type
  PipelineStageKind* = enum
    stageParse,
    stageTransform,
    stageAggregate,
    stageReport,
    stagePersist

  RecordStatus* = enum
    recordNew,
    recordProcessed,
    recordSkipped,
    recordFailed

  Severity* = enum
    severityInfo,
    severityWarning,
    severityError,
    severityCritical

  FieldType* = enum
    fieldString,
    fieldInt,
    fieldFloat,
    fieldBool,
    fieldTimestamp

  FieldValue* = object
    case kind*: FieldType
    of fieldString:
      strValue*: string
    of fieldInt:
      intValue*: int
    of fieldFloat:
      floatValue*: float
    of fieldBool:
      boolValue*: bool
    of fieldTimestamp:
      timeValue*: DateTime

  FieldDef* = object
    name*: string
    kind*: FieldType
    required*: bool

  RecordKey* = object
    namespace*: string
    id*: string

  RecordMetadata* = object
    receivedAt*: DateTime
    processedAt*: Option[DateTime]
    status*: RecordStatus
    tags*: seq[string]
    notes*: seq[string]

  Record* = object
    key*: RecordKey
    fields*: Table[string, FieldValue]
    metadata*: RecordMetadata

  StageResult* = object
    stage*: PipelineStageKind
    recordKey*: RecordKey
    success*: bool
    message*: string
    details*: Table[string, string]

  PipelineError* = object
    message*: string
    severity*: Severity
    recordKey*: Option[RecordKey]
    stage*: Option[PipelineStageKind]

  BatchSummary* = object
    batchId*: string
    total*: int
    processed*: int
    skipped*: int
    failed*: int
    startedAt*: DateTime
    finishedAt*: Option[DateTime]

  KeyedMetric* = object
    name*: string
    value*: float
    labels*: Table[string, string]

proc initRecordKey*(namespace, id: string): RecordKey =
  RecordKey(namespace: namespace, id: id)

proc initMetadata*(receivedAt: DateTime = now()): RecordMetadata =
  RecordMetadata(
    receivedAt: receivedAt,
    processedAt: none(DateTime),
    status: recordNew,
    tags: @[],
    notes: @[]
  )

proc initRecord*(namespace, id: string): Record =
  Record(
    key: initRecordKey(namespace, id),
    fields: initTable[string, FieldValue](),
    metadata: initMetadata()
  )

proc setProcessed*(metadata: var RecordMetadata, processedAt: DateTime = now()) =
  metadata.processedAt = some(processedAt)
  metadata.status = recordProcessed

proc addTag*(metadata: var RecordMetadata, tag: string) =
  if tag.len > 0:
    metadata.tags.add(tag)

proc addNote*(metadata: var RecordMetadata, note: string) =
  if note.len > 0:
    metadata.notes.add(note)

proc setField*(record: var Record, name: string, value: FieldValue) =
  record.fields[name] = value

proc getField*(record: Record, name: string): Option[FieldValue] =
  if record.fields.hasKey(name):
    some(record.fields[name])
  else:
    none(FieldValue)

proc fieldValueToString*(value: FieldValue): string =
  case value.kind
  of fieldString:
    value.strValue
  of fieldInt:
    $value.intValue
  of fieldFloat:
    $value.floatValue
  of fieldBool:
    if value.boolValue: "true" else: "false"
  of fieldTimestamp:
    $value.timeValue

proc isTerminal*(status: RecordStatus): bool =
  status in {recordProcessed, recordSkipped, recordFailed}

proc mergeTags*(tags: seq[string]): seq[string] =
  result = tags.deduplicate()
  result.sort()

proc mergeMetadata*(primary, secondary: RecordMetadata): RecordMetadata =
  result = primary
  for tag in secondary.tags:
    result.tags.add(tag)
  for note in secondary.notes:
    result.notes.add(note)
  result.tags = mergeTags(result.tags)
  if secondary.processedAt.isSome:
    result.processedAt = secondary.processedAt
    result.status = secondary.status

proc initStageResult*(stage: PipelineStageKind, key: RecordKey, success: bool, message: string): StageResult =
  StageResult(stage: stage, recordKey: key, success: success, message: message, details: initTable[string, string]())

proc addDetail*(result: var StageResult, key, value: string) =
  result.details[key] = value

proc initError*(message: string, severity: Severity = severityError, recordKey: Option[RecordKey] = none(RecordKey), stage: Option[PipelineStageKind] = none(PipelineStageKind)): PipelineError =
  PipelineError(message: message, severity: severity, recordKey: recordKey, stage: stage)

proc initBatchSummary*(batchId: string, total: int): BatchSummary =
  BatchSummary(
    batchId: batchId,
    total: total,
    processed: 0,
    skipped: 0,
    failed: 0,
    startedAt: now(),
    finishedAt: none(DateTime)
  )

proc markBatchFinished*(summary: var BatchSummary, finishedAt: DateTime = now()) =
  summary.finishedAt = some(finishedAt)

proc addMetric*(metrics: var seq[KeyedMetric], name: string, value: float, labels: Table[string, string] = initTable[string, string]()) =
  metrics.add(KeyedMetric(name: name, value: value, labels: labels))

proc metricLabel*(metric: KeyedMetric, key: string): string =
  if metric.labels.hasKey(key):
    metric.labels[key]
  else:
    ""

proc metricLabelPairs*(metric: KeyedMetric): seq[(string, string)] =
  toSeq(metric.labels.pairs())

proc withLabel*(metric: KeyedMetric, key, value: string): KeyedMetric =
  result = metric
  result.labels[key] = value
