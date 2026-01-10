import std/[tables, sequtils, strutils, options, times]
import ./types

type
  RecordCollection* = object
    namespace*: string
    records*: seq[Record]
    index*: Table[string, int]

proc initCollection*(namespace: string): RecordCollection =
  RecordCollection(namespace: namespace, records: @[], index: initTable[string, int]())

proc addRecord*(collection: var RecordCollection, record: Record) =
  if record.key.namespace != collection.namespace:
    return
  if collection.index.hasKey(record.key.id):
    return
  collection.index[record.key.id] = collection.records.len
  collection.records.add(record)

proc getRecord*(collection: RecordCollection, id: string): Option[Record] =
  if collection.index.hasKey(id):
    some(collection.records[collection.index[id]])
  else:
    none(Record)

proc updateRecord*(collection: var RecordCollection, record: Record) =
  if record.key.namespace != collection.namespace:
    return
  if collection.index.hasKey(record.key.id):
    let idx = collection.index[record.key.id]
    collection.records[idx] = record
  else:
    collection.addRecord(record)

proc removeRecord*(collection: var RecordCollection, id: string): bool =
  if not collection.index.hasKey(id):
    return false
  let idx = collection.index[id]
  collection.records.delete(idx)
  collection.index.del(id)
  for i in idx ..< collection.records.len:
    collection.index[collection.records[i].key.id] = i
  true

proc recordIds*(collection: RecordCollection): seq[string] =
  collection.records.mapIt(it.key.id)

proc filterByStatus*(collection: RecordCollection, statuses: set[RecordStatus]): seq[Record] =
  for record in collection.records:
    if record.metadata.status in statuses:
      result.add(record)

proc filterByTag*(collection: RecordCollection, tag: string): seq[Record] =
  for record in collection.records:
    if tag in record.metadata.tags:
      result.add(record)

proc filterByField*(collection: RecordCollection, fieldName: string, value: string): seq[Record] =
  for record in collection.records:
    let fieldOpt = record.getField(fieldName)
    if fieldOpt.isSome and fieldValueToString(fieldOpt.get()) == value:
      result.add(record)

proc markSkipped*(record: var Record, reason: string) =
  record.metadata.status = recordSkipped
  record.metadata.processedAt = some(now())
  record.metadata.addNote(reason)

proc markFailed*(record: var Record, reason: string) =
  record.metadata.status = recordFailed
  record.metadata.processedAt = some(now())
  record.metadata.addNote(reason)

proc markProcessed*(record: var Record, note: string = "") =
  record.metadata.setProcessed(now())
  if note.len > 0:
    record.metadata.addNote(note)

proc fieldNames*(record: Record): seq[string] =
  record.fields.keys.toSeq.sorted

proc cloneRecord*(record: Record): Record =
  result = record
  result.fields = initTable[string, FieldValue]()
  for key, value in record.fields:
    result.fields[key] = value
  result.metadata = record.metadata

proc mergeRecords*(primary, secondary: Record): Record =
  result = primary
  for key, value in secondary.fields:
    result.fields[key] = value
  result.metadata = mergeMetadata(primary.metadata, secondary.metadata)

proc toKeyValueLines*(record: Record): seq[string] =
  for name in record.fieldNames():
    let value = record.fields[name]
    result.add(name & "=" & fieldValueToString(value))

proc toDelimitedLine*(record: Record, fieldOrder: seq[string], delimiter: string = ","): string =
  var parts: seq[string] = @[]
  for field in fieldOrder:
    if record.fields.hasKey(field):
      parts.add(record.fields[field].fieldValueToString())
    else:
      parts.add("")
  parts.join(delimiter)

proc fromDelimitedLine*(namespace: string, id: string, fieldOrder: seq[string], line: string, delimiter: string = ","): Record =
  result = initRecord(namespace, id)
  let parts = line.split(delimiter)
  for idx, field in fieldOrder:
    if idx < parts.len:
      result.fields[field] = FieldValue(kind: fieldString, strValue: parts[idx])

proc fieldsToMap*(record: Record): Table[string, string] =
  result = initTable[string, string]()
  for key, value in record.fields:
    result[key] = value.fieldValueToString()

proc attachMap*(record: var Record, values: Table[string, string]) =
  for key, value in values:
    record.fields[key] = FieldValue(kind: fieldString, strValue: value)

proc touch*(record: var Record, tag: string = "touched") =
  record.metadata.addTag(tag)
  record.metadata.addNote("record updated")

proc renameField*(record: var Record, oldName, newName: string) =
  if record.fields.hasKey(oldName):
    record.fields[newName] = record.fields[oldName]
    record.fields.del(oldName)

proc dropField*(record: var Record, fieldName: string) =
  if record.fields.hasKey(fieldName):
    record.fields.del(fieldName)

proc copyField*(record: var Record, source, target: string) =
  if record.fields.hasKey(source):
    record.fields[target] = record.fields[source]

proc addComputedField*(record: var Record, name: string, compute: proc (r: Record): FieldValue {.closure.}) =
  record.fields[name] = compute(record)

proc ensureField*(record: var Record, name: string, defaultValue: FieldValue) =
  if not record.fields.hasKey(name):
    record.fields[name] = defaultValue

proc selectFields*(record: Record, names: seq[string]): Record =
  result = initRecord(record.key.namespace, record.key.id)
  for name in names:
    if record.fields.hasKey(name):
      result.fields[name] = record.fields[name]
  result.metadata = record.metadata

proc recordStatusCounts*(collection: RecordCollection): Table[RecordStatus, int] =
  result = initTable[RecordStatus, int]()
  for record in collection.records:
    let status = record.metadata.status
    result[status] = result.getOrDefault(status, 0) + 1

proc summaryLine*(collection: RecordCollection): string =
  let counts = collection.recordStatusCounts()
  var parts: seq[string] = @[]
  for status in RecordStatus:
    parts.add($status & ":" & $counts.getOrDefault(status, 0))
  collection.namespace & " [" & parts.join(", ") & "]"

proc mergeCollections*(primary, secondary: RecordCollection): RecordCollection =
  result = initCollection(primary.namespace)
  for record in primary.records:
    result.addRecord(record)
  for record in secondary.records:
    if result.index.hasKey(record.key.id):
      let idx = result.index[record.key.id]
      result.records[idx] = mergeRecords(result.records[idx], record)
    else:
      result.addRecord(record)

proc sortByField*(collection: var RecordCollection, fieldName: string) =
  collection.records.sort(proc (a, b: Record): int =
    let left = a.fields.getOrDefault(fieldName, FieldValue(kind: fieldString, strValue: ""))
    let right = b.fields.getOrDefault(fieldName, FieldValue(kind: fieldString, strValue: ""))
    cmp(left.fieldValueToString(), right.fieldValueToString())
  )
  collection.index.clear()
  for idx, record in collection.records:
    collection.index[record.key.id] = idx

proc deduplicate*(collection: var RecordCollection) =
  var seen = initHashSet[string]()
  var unique: seq[Record] = @[]
  for record in collection.records:
    if record.key.id notin seen:
      seen.incl(record.key.id)
      unique.add(record)
  collection.records = unique
  collection.index.clear()
  for idx, record in collection.records:
    collection.index[record.key.id] = idx

proc addBatchTag*(collection: var RecordCollection, tag: string) =
  for record in collection.records.mitems:
    record.metadata.addTag(tag)

proc applyStatus*(collection: var RecordCollection, status: RecordStatus) =
  for record in collection.records.mitems:
    record.metadata.status = status

proc fieldHistogram*(collection: RecordCollection, fieldName: string): Table[string, int] =
  result = initTable[string, int]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let key = record.fields[fieldName].fieldValueToString()
      result[key] = result.getOrDefault(key, 0) + 1

proc mapRecords*(collection: RecordCollection, op: proc (r: Record): Record {.closure.}): RecordCollection =
  result = initCollection(collection.namespace)
  for record in collection.records:
    result.addRecord(op(record))

proc filterRecords*(collection: RecordCollection, predicate: proc (r: Record): bool {.closure.}): RecordCollection =
  result = initCollection(collection.namespace)
  for record in collection.records:
    if predicate(record):
      result.addRecord(record)

proc toTable*(collection: RecordCollection): seq[Table[string, string]] =
  for record in collection.records:
    result.add(record.fieldsToMap())

proc fromTable*(namespace: string, rows: seq[Table[string, string]]): RecordCollection =
  result = initCollection(namespace)
  for idx, row in rows:
    var record = initRecord(namespace, $idx)
    record.attachMap(row)
    result.addRecord(record)
