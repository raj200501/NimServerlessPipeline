import std/[tables, sequtils, strutils]
import ./records
import ./types


type
  RouteRule* = object
    name*: string
    fieldName*: string
    matchValue*: string
    target*: string

  RouteTable* = object
    rules*: seq[RouteRule]
    defaultTarget*: string

  RoutedBatch* = object
    target*: string
    records*: seq[Record]

proc initRouteTable*(defaultTarget: string): RouteTable =
  RouteTable(rules: @[], defaultTarget: defaultTarget)

proc addRule*(table: var RouteTable, name, fieldName, matchValue, target: string) =
  table.rules.add(RouteRule(name: name, fieldName: fieldName, matchValue: matchValue, target: target))

proc resolveTarget*(table: RouteTable, record: Record): string =
  for rule in table.rules:
    if record.fields.hasKey(rule.fieldName):
      let value = record.fields[rule.fieldName].fieldValueToString()
      if value == rule.matchValue:
        return rule.target
  table.defaultTarget

proc routeRecords*(table: RouteTable, collection: RecordCollection): Table[string, RecordCollection] =
  result = initTable[string, RecordCollection]()
  for record in collection.records:
    let target = table.resolveTarget(record)
    if not result.hasKey(target):
      result[target] = initCollection(collection.namespace)
    result[target].addRecord(record)

proc routedBatches*(table: RouteTable, collection: RecordCollection): seq[RoutedBatch] =
  for target, batch in table.routeRecords(collection):
    result.add(RoutedBatch(target: target, records: batch.records))

proc summarizeRoutes*(table: RouteTable): seq[string] =
  result.add("default=" & table.defaultTarget)
  for rule in table.rules:
    result.add(rule.name & ":" & rule.fieldName & "=" & rule.matchValue & " -> " & rule.target)

proc annotateRoutes*(collection: var RecordCollection, table: RouteTable, fieldName = "route") =
  for record in collection.records.mitems:
    let target = table.resolveTarget(record)
    record.fields[fieldName] = FieldValue(kind: fieldString, strValue: target)

proc splitByRoute*(collection: RecordCollection, fieldName = "route"): Table[string, RecordCollection] =
  result = initTable[string, RecordCollection]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let target = record.fields[fieldName].fieldValueToString()
      if not result.hasKey(target):
        result[target] = initCollection(collection.namespace)
      result[target].addRecord(record)

proc routeByPrefix*(collection: RecordCollection, fieldName: string, length = 1): Table[string, RecordCollection] =
  result = initTable[string, RecordCollection]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let raw = record.fields[fieldName].fieldValueToString()
      let prefix = if raw.len >= length: raw[0 ..< length] else: raw
      if not result.hasKey(prefix):
        result[prefix] = initCollection(collection.namespace)
      result[prefix].addRecord(record)

proc normalizeRules*(table: var RouteTable) =
  for rule in table.rules.mitems:
    rule.fieldName = rule.fieldName.strip().toLowerAscii()
    rule.matchValue = rule.matchValue.strip()
    rule.target = rule.target.strip().toLowerAscii()

proc groupTargets*(table: RouteTable): seq[string] =
  var targets = @[table.defaultTarget]
  for rule in table.rules:
    if rule.target notin targets:
      targets.add(rule.target)
  targets.sort()
