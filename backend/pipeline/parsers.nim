import std/[strutils, sequtils, json, tables, times, options]
import ./types
import ./records

proc parseKeyValueLine*(line: string, delimiter = '='): Table[string, string] =
  result = initTable[string, string]()
  for part in line.split(','):
    let trimmed = part.strip()
    if trimmed.len == 0:
      continue
    let idx = trimmed.find(delimiter)
    if idx <= 0 or idx >= trimmed.len - 1:
      continue
    let key = trimmed[0 ..< idx].strip()
    let value = trimmed[idx + 1 .. ^1].strip()
    if key.len > 0:
      result[key] = value

proc parseCsvLine*(line: string, headers: seq[string], delimiter = ','): Table[string, string] =
  result = initTable[string, string]()
  let parts = line.split(delimiter)
  for idx, header in headers:
    if idx < parts.len:
      result[header] = parts[idx].strip()

proc parseTsvLine*(line: string, headers: seq[string]): Table[string, string] =
  parseCsvLine(line, headers, '\t')

proc parseJsonObject*(line: string): Table[string, string] =
  result = initTable[string, string]()
  let node = parseJson(line)
  if node.kind != JObject:
    return
  for key, value in node:
    case value.kind
    of JString:
      result[key] = value.getStr()
    of JInt:
      result[key] = $value.getInt()
    of JFloat:
      result[key] = $value.getFloat()
    of JBool:
      result[key] = if value.getBool(): "true" else: "false"
    of JNull:
      result[key] = ""
    else:
      result[key] = $value

proc toRecord*(namespace, id: string, fields: Table[string, string]): Record =
  var record = initRecord(namespace, id)
  for key, value in fields:
    record.fields[key] = FieldValue(kind: fieldString, strValue: value)
  record

proc parseLines*(namespace: string, lines: seq[string], mode: string, headers: seq[string] = @[]): RecordCollection =
  result = initCollection(namespace)
  for idx, line in lines:
    if line.strip().len == 0:
      continue
    var fields: Table[string, string]
    case mode
    of "kv":
      fields = parseKeyValueLine(line)
    of "csv":
      fields = parseCsvLine(line, headers)
    of "tsv":
      fields = parseTsvLine(line, headers)
    of "json":
      fields = parseJsonObject(line)
    else:
      fields = parseKeyValueLine(line)
    result.addRecord(toRecord(namespace, $idx, fields))

proc parseTimestamp*(value: string, fallback = now()): DateTime =
  try:
    parse(value)
  except ValueError:
    fallback

proc parseFieldValue*(value: string, kind: FieldType): FieldValue =
  case kind
  of fieldString:
    FieldValue(kind: fieldString, strValue: value)
  of fieldInt:
    FieldValue(kind: fieldInt, intValue: parseInt(value))
  of fieldFloat:
    FieldValue(kind: fieldFloat, floatValue: parseFloat(value))
  of fieldBool:
    FieldValue(kind: fieldBool, boolValue: value.toLowerAscii() in ["true", "1", "yes", "y"]) 
  of fieldTimestamp:
    FieldValue(kind: fieldTimestamp, timeValue: parseTimestamp(value))

proc applySchema*(record: var Record, schema: seq[FieldDef]) =
  for fieldDef in schema:
    if record.fields.hasKey(fieldDef.name):
      let value = record.fields[fieldDef.name].fieldValueToString()
      record.fields[fieldDef.name] = parseFieldValue(value, fieldDef.kind)
    elif fieldDef.required:
      record.fields[fieldDef.name] = parseFieldValue("", fieldDef.kind)

proc applySchema*(collection: var RecordCollection, schema: seq[FieldDef]) =
  for record in collection.records.mitems:
    record.applySchema(schema)

proc parseWithSchema*(namespace: string, lines: seq[string], mode: string, schema: seq[FieldDef], headers: seq[string] = @[]): RecordCollection =
  result = parseLines(namespace, lines, mode, headers)
  result.applySchema(schema)

proc inferFieldTypes*(collection: RecordCollection, sampleSize: int = 10): Table[string, FieldType] =
  result = initTable[string, FieldType]()
  let sample = collection.records[0 ..< min(sampleSize, collection.records.len)]
  for record in sample:
    for key, value in record.fields:
      let raw = value.fieldValueToString()
      if raw.len == 0:
        continue
      if raw.allCharsInSet({'0'..'9', '-'}) and not raw.contains('.'): 
        result[key] = fieldInt
      elif raw.allCharsInSet({'0'..'9', '-', '.'}):
        result[key] = fieldFloat
      elif raw.toLowerAscii() in ["true", "false", "yes", "no", "1", "0"]:
        result[key] = fieldBool
      else:
        result[key] = fieldString

proc castFields*(record: var Record, types: Table[string, FieldType]) =
  for key, kind in types:
    if record.fields.hasKey(key):
      let value = record.fields[key].fieldValueToString()
      record.fields[key] = parseFieldValue(value, kind)

proc castFields*(collection: var RecordCollection, types: Table[string, FieldType]) =
  for record in collection.records.mitems:
    record.castFields(types)

proc parseDelimitedBlock*(namespace: string, content: string, delimiter = ',', hasHeader = true): RecordCollection =
  let lines = content.splitLines().filterIt(it.strip().len > 0)
  if lines.len == 0:
    return initCollection(namespace)
  var headers: seq[string] = @[]
  var startIdx = 0
  if hasHeader:
    headers = lines[0].split(delimiter).mapIt(it.strip())
    startIdx = 1
  result = parseLines(namespace, lines[startIdx .. ^1], "csv", headers)

proc parseJsonLines*(namespace: string, content: string): RecordCollection =
  let lines = content.splitLines().filterIt(it.strip().len > 0)
  result = parseLines(namespace, lines, "json")

proc parseKeyValueBlock*(namespace: string, content: string): RecordCollection =
  let lines = content.splitLines().filterIt(it.strip().len > 0)
  result = parseLines(namespace, lines, "kv")

proc safeParseJson*(line: string): Option[JsonNode] =
  try:
    some(parseJson(line))
  except JsonParsingError:
    none(JsonNode)

proc parseJsonArray*(content: string): seq[Table[string, string]] =
  result = @[]
  let node = parseJson(content)
  if node.kind != JArray:
    return
  for item in node:
    if item.kind != JObject:
      continue
    var row = initTable[string, string]()
    for key, value in item:
      row[key] = $value
    result.add(row)

proc parseIsoDate*(value: string): Option[DateTime] =
  try:
    some(parse(value))
  except ValueError:
    none(DateTime)

proc parseIntSafe*(value: string, fallback = 0): int =
  try:
    parseInt(value)
  except ValueError:
    fallback

proc parseFloatSafe*(value: string, fallback = 0.0): float =
  try:
    parseFloat(value)
  except ValueError:
    fallback

proc parseBoolSafe*(value: string, fallback = false): bool =
  let normalized = value.toLowerAscii().strip()
  if normalized in ["true", "1", "yes", "y"]:
    true
  elif normalized in ["false", "0", "no", "n"]:
    false
  else:
    fallback

proc parseDurationSeconds*(value: string): float =
  if value.endsWith("ms"):
    parseFloatSafe(value[0 ..< ^2]) / 1000
  elif value.endsWith("s"):
    parseFloatSafe(value[0 ..< ^1])
  elif value.endsWith("m"):
    parseFloatSafe(value[0 ..< ^1]) * 60
  elif value.endsWith("h"):
    parseFloatSafe(value[0 ..< ^1]) * 3600
  else:
    parseFloatSafe(value)

proc parseLabelSet*(value: string): Table[string, string] =
  result = initTable[string, string]()
  for part in value.split(','):
    let trimmed = part.strip()
    if trimmed.len == 0:
      continue
    let idx = trimmed.find('=')
    if idx <= 0:
      continue
    let key = trimmed[0 ..< idx].strip()
    let val = trimmed[idx + 1 .. ^1].strip()
    result[key] = val

proc parseSchema*(value: string): seq[FieldDef] =
  result = @[]
  for part in value.split(','):
    let trimmed = part.strip()
    if trimmed.len == 0:
      continue
    let pieces = trimmed.split(':')
    if pieces.len < 2:
      continue
    let fieldName = pieces[0].strip()
    let typeName = pieces[1].strip().toLowerAscii()
    let required = if pieces.len >= 3: pieces[2].strip().toLowerAscii() == "required" else: false
    let kind = case typeName
      of "int", "integer": fieldInt
      of "float", "double": fieldFloat
      of "bool", "boolean": fieldBool
      of "timestamp", "time", "datetime": fieldTimestamp
      else: fieldString
    result.add(FieldDef(name: fieldName, kind: kind, required: required))

proc normalizeHeaders*(headers: seq[string]): seq[string] =
  headers.mapIt(it.strip().toLowerAscii().replace(" ", "_"))
