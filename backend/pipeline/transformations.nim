import std/[strutils, sequtils, tables, algorithm, times]
import ./types
import ./records

proc normalizeWhitespace*(value: string): string =
  value.splitWhitespace().join(" ")

proc trimFields*(record: var Record) =
  for key, value in record.fields.mpairs:
    if value.kind == fieldString:
      record.fields[key] = FieldValue(kind: fieldString, strValue: value.strValue.strip())

proc lowerFields*(record: var Record, fields: seq[string]) =
  for name in fields:
    if record.fields.hasKey(name):
      let value = record.fields[name]
      if value.kind == fieldString:
        record.fields[name] = FieldValue(kind: fieldString, strValue: value.strValue.toLowerAscii())

proc upperFields*(record: var Record, fields: seq[string]) =
  for name in fields:
    if record.fields.hasKey(name):
      let value = record.fields[name]
      if value.kind == fieldString:
        record.fields[name] = FieldValue(kind: fieldString, strValue: value.strValue.toUpperAscii())

proc titleCase*(value: string): string =
  result = ""
  for part in value.splitWhitespace():
    if part.len == 0:
      continue
    let head = part[0].toUpperAscii()
    let tail = if part.len > 1: part[1 .. ^1].toLowerAscii() else: ""
    if result.len > 0:
      result.add(' ')
    result.add(head & tail)

proc applyTitleCase*(record: var Record, fields: seq[string]) =
  for name in fields:
    if record.fields.hasKey(name):
      let value = record.fields[name]
      if value.kind == fieldString:
        record.fields[name] = FieldValue(kind: fieldString, strValue: titleCase(value.strValue))

proc replaceField*(record: var Record, fieldName, oldValue, newValue: string) =
  if record.fields.hasKey(fieldName):
    let value = record.fields[fieldName]
    if value.kind == fieldString:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: value.strValue.replace(oldValue, newValue))

proc appendSuffix*(record: var Record, fieldName, suffix: string) =
  if record.fields.hasKey(fieldName):
    let value = record.fields[fieldName]
    if value.kind == fieldString:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: value.strValue & suffix)

proc prependPrefix*(record: var Record, fieldName, prefix: string) =
  if record.fields.hasKey(fieldName):
    let value = record.fields[fieldName]
    if value.kind == fieldString:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: prefix & value.strValue)

proc splitField*(record: var Record, fieldName, delimiter: string, targetPrefix: string) =
  if record.fields.hasKey(fieldName):
    let value = record.fields[fieldName]
    if value.kind == fieldString:
      let parts = value.strValue.split(delimiter)
      for idx, part in parts:
        record.fields[targetPrefix & $idx] = FieldValue(kind: fieldString, strValue: part)

proc concatFields*(record: var Record, fieldNames: seq[string], target: string, separator = " ") =
  var parts: seq[string] = @[]
  for name in fieldNames:
    if record.fields.hasKey(name):
      parts.add(record.fields[name].fieldValueToString())
  record.fields[target] = FieldValue(kind: fieldString, strValue: parts.join(separator))

proc mapField*(record: var Record, fieldName: string, mapping: Table[string, string]) =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if mapping.hasKey(raw):
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: mapping[raw])

proc dropEmptyFields*(record: var Record) =
  var toRemove: seq[string] = @[]
  for key, value in record.fields:
    if value.fieldValueToString().strip().len == 0:
      toRemove.add(key)
  for key in toRemove:
    record.fields.del(key)

proc normalizeNumbers*(record: var Record, fields: seq[string]) =
  for name in fields:
    if record.fields.hasKey(name):
      let raw = record.fields[name].fieldValueToString().replace(",", "")
      if raw.len == 0:
        continue
      if raw.contains('.'):
        record.fields[name] = FieldValue(kind: fieldFloat, floatValue: parseFloat(raw))
      else:
        record.fields[name] = FieldValue(kind: fieldInt, intValue: parseInt(raw))

proc normalizeDates*(record: var Record, fields: seq[string]) =
  for name in fields:
    if record.fields.hasKey(name):
      let raw = record.fields[name].fieldValueToString()
      if raw.len == 0:
        continue
      try:
        record.fields[name] = FieldValue(kind: fieldTimestamp, timeValue: parse(raw))
      except ValueError:
        discard

proc sortFields*(record: var Record) =
  let sortedKeys = record.fields.keys.toSeq.sorted(cmp[string])
  var newFields = initTable[string, FieldValue]()
  for key in sortedKeys:
    newFields[key] = record.fields[key]
  record.fields = newFields

proc ensureTags*(record: var Record, requiredTags: seq[string]) =
  for tag in requiredTags:
    if tag notin record.metadata.tags:
      record.metadata.addTag(tag)

proc replaceIfEmpty*(record: var Record, fieldName, fallback: string) =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString().strip()
    if raw.len == 0:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: fallback)

proc applyTransforms*(collection: var RecordCollection, transforms: seq[proc (r: var Record) {.closure.}]) =
  for record in collection.records.mitems:
    for transform in transforms:
      transform(record)

proc tagIfMissingFields*(record: var Record, fields: seq[string], tag = "missing-field") =
  for name in fields:
    if not record.fields.hasKey(name):
      record.metadata.addTag(tag)

proc tagIfFieldEquals*(record: var Record, fieldName, expected, tag: string) =
  if record.fields.hasKey(fieldName):
    let actual = record.fields[fieldName].fieldValueToString()
    if actual == expected:
      record.metadata.addTag(tag)

proc addDerivedScore*(record: var Record, numeratorField, denominatorField, targetField: string) =
  if record.fields.hasKey(numeratorField) and record.fields.hasKey(denominatorField):
    let numerator = record.fields[numeratorField].fieldValueToString().parseFloat()
    let denominator = record.fields[denominatorField].fieldValueToString().parseFloat()
    if denominator != 0:
      record.fields[targetField] = FieldValue(kind: fieldFloat, floatValue: numerator / denominator)

proc padLeft*(record: var Record, fieldName: string, length: int, padChar = '0') =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if raw.len < length:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: padChar.repeat(length - raw.len) & raw)

proc padRight*(record: var Record, fieldName: string, length: int, padChar = '0') =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if raw.len < length:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: raw & padChar.repeat(length - raw.len))

proc stripPrefix*(record: var Record, fieldName, prefix: string) =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if raw.startsWith(prefix):
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: raw[prefix.len .. ^1])

proc stripSuffix*(record: var Record, fieldName, suffix: string) =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if raw.endsWith(suffix):
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: raw[0 ..< raw.len - suffix.len])

proc maskField*(record: var Record, fieldName: string, visibleTail = 4, maskChar = '*') =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if raw.len <= visibleTail:
      return
    let masked = maskChar.repeat(raw.len - visibleTail) & raw[raw.len - visibleTail .. ^1]
    record.fields[fieldName] = FieldValue(kind: fieldString, strValue: masked)

proc normalizePhone*(record: var Record, fieldName: string, countryCode = "+1") =
  if record.fields.hasKey(fieldName):
    var digits = ""
    for ch in record.fields[fieldName].fieldValueToString():
      if ch in {'0'..'9'}:
        digits.add(ch)
    if digits.len == 10:
      digits = countryCode & digits
    record.fields[fieldName] = FieldValue(kind: fieldString, strValue: digits)

proc mapWithLookup*(record: var Record, fieldName: string, lookup: Table[string, string], defaultValue = "") =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    if lookup.hasKey(raw):
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: lookup[raw])
    elif defaultValue.len > 0:
      record.fields[fieldName] = FieldValue(kind: fieldString, strValue: defaultValue)

proc enforceRange*(record: var Record, fieldName: string, minValue, maxValue: float) =
  if record.fields.hasKey(fieldName):
    let raw = record.fields[fieldName].fieldValueToString()
    let value = parseFloat(raw)
    if value < minValue or value > maxValue:
      record.metadata.addTag("out-of-range")

proc normalizeCollection*(collection: var RecordCollection) =
  collection.applyStatus(recordProcessed)
  collection.addBatchTag("normalized")

proc stripAccents*(value: string): string =
  result = ""
  for ch in value:
    case ch
    of 'á', 'à', 'â', 'ä': result.add('a')
    of 'é', 'è', 'ê', 'ë': result.add('e')
    of 'í', 'ì', 'î', 'ï': result.add('i')
    of 'ó', 'ò', 'ô', 'ö': result.add('o')
    of 'ú', 'ù', 'û', 'ü': result.add('u')
    of 'ñ': result.add('n')
    of 'ç': result.add('c')
    else: result.add(ch)

proc normalizeTextFields*(record: var Record, fields: seq[string]) =
  for name in fields:
    if record.fields.hasKey(name):
      let raw = record.fields[name].fieldValueToString()
      record.fields[name] = FieldValue(kind: fieldString, strValue: stripAccents(normalizeWhitespace(raw)))
