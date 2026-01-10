import std/[tables, sequtils, strutils, times, options]
import ./records
import ./types


type
  RetentionPolicy* = object
    name*: string
    retentionDays*: int
    tags*: seq[string]

  RedactionRule* = object
    fieldName*: string
    maskChar*: char
    visibleTail*: int

  AccessPolicy* = object
    name*: string
    allowedTags*: seq[string]
    deniedTags*: seq[string]

proc initRetentionPolicy*(name: string, retentionDays: int, tags: seq[string] = @[]): RetentionPolicy =
  RetentionPolicy(name: name, retentionDays: retentionDays, tags: tags)

proc initAccessPolicy*(name: string, allowedTags: seq[string], deniedTags: seq[string] = @[]): AccessPolicy =
  AccessPolicy(name: name, allowedTags: allowedTags, deniedTags: deniedTags)

proc initRedactionRule*(fieldName: string, visibleTail = 4, maskChar = '*'): RedactionRule =
  RedactionRule(fieldName: fieldName, visibleTail: visibleTail, maskChar: maskChar)

proc applyRetention*(collection: RecordCollection, policy: RetentionPolicy): RecordCollection =
  result = initCollection(collection.namespace)
  let cutoff = now() - initDuration(days = policy.retentionDays)
  for record in collection.records:
    if record.metadata.processedAt.isSome:
      if record.metadata.processedAt.get() >= cutoff:
        result.addRecord(record)
    else:
      result.addRecord(record)
    for tag in policy.tags:
      if tag notin record.metadata.tags:
        discard

proc applyRedaction*(record: var Record, rules: seq[RedactionRule]) =
  for rule in rules:
    if record.fields.hasKey(rule.fieldName):
      let raw = record.fields[rule.fieldName].fieldValueToString()
      if raw.len <= rule.visibleTail:
        continue
      let masked = rule.maskChar.repeat(raw.len - rule.visibleTail) & raw[raw.len - rule.visibleTail .. ^1]
      record.fields[rule.fieldName] = FieldValue(kind: fieldString, strValue: masked)

proc applyRedaction*(collection: var RecordCollection, rules: seq[RedactionRule]) =
  for record in collection.records.mitems:
    record.applyRedaction(rules)

proc isAllowed*(record: Record, policy: AccessPolicy): bool =
  for tag in policy.deniedTags:
    if tag in record.metadata.tags:
      return false
  if policy.allowedTags.len == 0:
    return true
  for tag in policy.allowedTags:
    if tag in record.metadata.tags:
      return true
  false

proc filterByPolicy*(collection: RecordCollection, policy: AccessPolicy): RecordCollection =
  result = initCollection(collection.namespace)
  for record in collection.records:
    if record.isAllowed(policy):
      result.addRecord(record)

proc tagRetention*(collection: var RecordCollection, policy: RetentionPolicy) =
  let cutoff = now() - initDuration(days = policy.retentionDays)
  for record in collection.records.mitems:
    if record.metadata.processedAt.isSome and record.metadata.processedAt.get() < cutoff:
      record.metadata.addTag("expired")

proc redactFields*(record: var Record, fields: seq[string]) =
  for field in fields:
    record.applyRedaction(@[initRedactionRule(field)])

proc mapRetention*(policies: seq[RetentionPolicy]): Table[string, RetentionPolicy] =
  result = initTable[string, RetentionPolicy]()
  for policy in policies:
    result[policy.name] = policy

proc describePolicy*(policy: RetentionPolicy): string =
  policy.name & "(" & $policy.retentionDays & " days)"
