import std/[tables, strutils, sequtils]
import ./records
import ./types


type
  LookupTable* = object
    name*: string
    keyField*: string
    valueField*: string
    data*: Table[string, string]

proc initLookupTable*(name, keyField, valueField: string): LookupTable =
  LookupTable(name: name, keyField: keyField, valueField: valueField, data: initTable[string, string]())

proc addEntry*(lookup: var LookupTable, key, value: string) =
  lookup.data[key] = value

proc loadEntries*(lookup: var LookupTable, entries: Table[string, string]) =
  for key, value in entries:
    lookup.data[key] = value

proc enrichRecord*(record: var Record, lookup: LookupTable, targetField: string) =
  if record.fields.hasKey(lookup.keyField):
    let key = record.fields[lookup.keyField].fieldValueToString()
    if lookup.data.hasKey(key):
      record.fields[targetField] = FieldValue(kind: fieldString, strValue: lookup.data[key])

proc enrichCollection*(collection: var RecordCollection, lookup: LookupTable, targetField: string) =
  for record in collection.records.mitems:
    record.enrichRecord(lookup, targetField)

proc mergeLookups*(primary, secondary: LookupTable): LookupTable =
  result = primary
  for key, value in secondary.data:
    result.data[key] = value

proc expandFromCompositeKey*(record: var Record, sourceField: string, parts: seq[string], delimiter = "-") =
  if record.fields.hasKey(sourceField):
    let raw = record.fields[sourceField].fieldValueToString()
    let segments = raw.split(delimiter)
    for idx, name in parts:
      if idx < segments.len:
        record.fields[name] = FieldValue(kind: fieldString, strValue: segments[idx])

proc tagMissingLookup*(record: var Record, lookup: LookupTable, tag = "lookup-miss") =
  if record.fields.hasKey(lookup.keyField):
    let key = record.fields[lookup.keyField].fieldValueToString()
    if not lookup.data.hasKey(key):
      record.metadata.addTag(tag)

proc enrichWithFallback*(record: var Record, lookup: LookupTable, targetField, fallbackField: string) =
  if record.fields.hasKey(lookup.keyField):
    let key = record.fields[lookup.keyField].fieldValueToString()
    if lookup.data.hasKey(key):
      record.fields[targetField] = FieldValue(kind: fieldString, strValue: lookup.data[key])
    elif record.fields.hasKey(fallbackField):
      record.fields[targetField] = record.fields[fallbackField]

proc lookupSummary*(lookup: LookupTable): seq[string] =
  result.add("lookup=" & lookup.name)
  result.add("entries=" & $lookup.data.len)
  result.add("key=" & lookup.keyField & " value=" & lookup.valueField)
