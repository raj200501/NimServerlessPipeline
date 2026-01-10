import std/[tables, sequtils, times, options]
import ./types


type
  LineageEventKind* = enum
    lineageReceived,
    lineageParsed,
    lineageTransformed,
    lineageAggregated,
    lineageReported,
    lineagePersisted

  LineageEvent* = object
    kind*: LineageEventKind
    timestamp*: DateTime
    details*: Table[string, string]

  RecordLineage* = object
    recordKey*: RecordKey
    events*: seq[LineageEvent]

proc initLineage*(recordKey: RecordKey): RecordLineage =
  RecordLineage(recordKey: recordKey, events: @[])

proc addEvent*(lineage: var RecordLineage, kind: LineageEventKind, details: Table[string, string] = initTable[string, string]()) =
  lineage.events.add(LineageEvent(kind: kind, timestamp: now(), details: details))

proc lastEvent*(lineage: RecordLineage): Option[LineageEvent] =
  if lineage.events.len == 0:
    none(LineageEvent)
  else:
    some(lineage.events[^1])

proc eventsByKind*(lineage: RecordLineage, kind: LineageEventKind): seq[LineageEvent] =
  for event in lineage.events:
    if event.kind == kind:
      result.add(event)

proc eventSummary*(event: LineageEvent): string =
  var parts: seq[string] = @[$event.kind, $event.timestamp]
  for key, value in event.details:
    parts.add(key & "=" & value)
  parts.join(" ")

proc lineageSummary*(lineage: RecordLineage): seq[string] =
  result.add("record=" & lineage.recordKey.namespace & ":" & lineage.recordKey.id)
  for event in lineage.events:
    result.add(event.eventSummary())

proc mergeLineage*(primary, secondary: RecordLineage): RecordLineage =
  result = primary
  for event in secondary.events:
    result.events.add(event)

proc eventCount*(lineage: RecordLineage): int =
  lineage.events.len

proc elapsedBetween*(lineage: RecordLineage, startKind, endKind: LineageEventKind): Option[Duration] =
  let startEvents = lineage.eventsByKind(startKind)
  let endEvents = lineage.eventsByKind(endKind)
  if startEvents.len == 0 or endEvents.len == 0:
    return none(Duration)
  let startTime = startEvents[0].timestamp
  let endTime = endEvents[^1].timestamp
  some(endTime - startTime)

proc addDetail*(event: var LineageEvent, key, value: string) =
  event.details[key] = value

proc addProcessingStage*(lineage: var RecordLineage, stage: PipelineStageKind, message: string) =
  var details = initTable[string, string]()
  details["stage"] = $stage
  details["message"] = message
  case stage
  of stageParse:
    lineage.addEvent(lineageParsed, details)
  of stageTransform:
    lineage.addEvent(lineageTransformed, details)
  of stageAggregate:
    lineage.addEvent(lineageAggregated, details)
  of stageReport:
    lineage.addEvent(lineageReported, details)
  of stagePersist:
    lineage.addEvent(lineagePersisted, details)

proc eventKinds*(lineage: RecordLineage): seq[LineageEventKind] =
  lineage.events.mapIt(it.kind)

proc detailValue*(event: LineageEvent, key: string): string =
  if event.details.hasKey(key):
    event.details[key]
  else:
    ""
