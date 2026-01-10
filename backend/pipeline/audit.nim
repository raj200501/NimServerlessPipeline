import std/[tables, sequtils, times]
import ./types
import ./records


type
  AuditEventKind* = enum
    auditCreate,
    auditUpdate,
    auditDelete,
    auditProcess,
    auditExport

  AuditEvent* = object
    kind*: AuditEventKind
    recordKey*: RecordKey
    timestamp*: DateTime
    actor*: string
    details*: Table[string, string]

  AuditLog* = object
    events*: seq[AuditEvent]

proc initAuditLog*(): AuditLog =
  AuditLog(events: @[])

proc addEvent*(log: var AuditLog, kind: AuditEventKind, recordKey: RecordKey, actor: string, details: Table[string, string] = initTable[string, string]()) =
  log.events.add(AuditEvent(kind: kind, recordKey: recordKey, timestamp: now(), actor: actor, details: details))

proc addRecordCreated*(log: var AuditLog, record: Record, actor = "system") =
  log.addEvent(auditCreate, record.key, actor)

proc addRecordUpdated*(log: var AuditLog, record: Record, actor = "system") =
  log.addEvent(auditUpdate, record.key, actor)

proc addRecordDeleted*(log: var AuditLog, recordKey: RecordKey, actor = "system") =
  log.addEvent(auditDelete, recordKey, actor)

proc addRecordProcessed*(log: var AuditLog, record: Record, stage: PipelineStageKind, actor = "system") =
  var details = initTable[string, string]()
  details["stage"] = $stage
  log.addEvent(auditProcess, record.key, actor, details)

proc addExport*(log: var AuditLog, recordKey: RecordKey, target: string, actor = "system") =
  var details = initTable[string, string]()
  details["target"] = target
  log.addEvent(auditExport, recordKey, actor, details)

proc eventsForRecord*(log: AuditLog, recordKey: RecordKey): seq[AuditEvent] =
  for event in log.events:
    if event.recordKey == recordKey:
      result.add(event)

proc eventsByKind*(log: AuditLog, kind: AuditEventKind): seq[AuditEvent] =
  for event in log.events:
    if event.kind == kind:
      result.add(event)

proc actorSummary*(log: AuditLog): Table[string, int] =
  result = initTable[string, int]()
  for event in log.events:
    result[event.actor] = result.getOrDefault(event.actor, 0) + 1

proc recordSummary*(log: AuditLog): Table[string, int] =
  result = initTable[string, int]()
  for event in log.events:
    let key = event.recordKey.namespace & ":" & event.recordKey.id
    result[key] = result.getOrDefault(key, 0) + 1

proc summarizeEvent*(event: AuditEvent): string =
  var parts: seq[string] = @[]
  parts.add($event.kind)
  parts.add(event.recordKey.namespace & ":" & event.recordKey.id)
  parts.add($event.timestamp)
  parts.add("actor=" & event.actor)
  for key, value in event.details:
    parts.add(key & "=" & value)
  parts.join(" ")

proc summarizeLog*(log: AuditLog, limit = 20): seq[string] =
  let events = log.events[0 ..< min(limit, log.events.len)]
  for event in events:
    result.add(event.summarizeEvent())

proc pruneLog*(log: var AuditLog, keepLast: int) =
  if log.events.len > keepLast:
    log.events = log.events[log.events.len - keepLast .. ^1]

proc appendDetails*(event: var AuditEvent, key, value: string) =
  event.details[key] = value

proc addNote*(log: var AuditLog, recordKey: RecordKey, note: string, actor = "system") =
  var details = initTable[string, string]()
  details["note"] = note
  log.addEvent(auditUpdate, recordKey, actor, details)

proc mergeLogs*(primary, secondary: AuditLog): AuditLog =
  result = primary
  for event in secondary.events:
    result.events.add(event)
