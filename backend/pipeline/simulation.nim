import std/[random, sequtils, strutils, times, tables]
import ./types
import ./records
import ./transformations
import ./parsers

proc sampleWords*(seed: int, count: int): seq[string] =
  var rng = initRand(seed)
  let vocabulary = @["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "theta", "lambda", "omega", "sigma"]
  for _ in 0 ..< count:
    result.add(vocabulary[rng.rand(vocabulary.len - 1)])

proc randomId*(rng: var Rand, prefix: string, width = 6): string =
  var suffix = ""
  for _ in 0 ..< width:
    suffix.add($rng.rand(9))
  prefix & suffix

proc generateRecord*(rng: var Rand, namespace: string, idPrefix: string, schema: seq[FieldDef]): Record =
  result = initRecord(namespace, randomId(rng, idPrefix))
  for field in schema:
    case field.kind
    of fieldString:
      result.fields[field.name] = FieldValue(kind: fieldString, strValue: sampleWords(rng.rand(1000), 2).join("-"))
    of fieldInt:
      result.fields[field.name] = FieldValue(kind: fieldInt, intValue: rng.rand(1000))
    of fieldFloat:
      result.fields[field.name] = FieldValue(kind: fieldFloat, floatValue: rng.rand(1000) / 10.0)
    of fieldBool:
      result.fields[field.name] = FieldValue(kind: fieldBool, boolValue: rng.rand(1) == 1)
    of fieldTimestamp:
      result.fields[field.name] = FieldValue(kind: fieldTimestamp, timeValue: now() - initDuration(hours = rng.rand(72)))
  result.metadata.addTag("synthetic")

proc generateCollection*(namespace: string, schema: seq[FieldDef], size: int, seed = 42): RecordCollection =
  var rng = initRand(seed)
  result = initCollection(namespace)
  for _ in 0 ..< size:
    result.addRecord(generateRecord(rng, namespace, "rec-", schema))

proc mutateCollection*(collection: var RecordCollection, seed = 101) =
  var rng = initRand(seed)
  for record in collection.records.mitems:
    if rng.rand(9) < 3:
      record.metadata.addTag("mutated")
    if rng.rand(9) < 2:
      record.metadata.addTag("suspect")
    if rng.rand(9) < 1:
      record.metadata.status = recordFailed
    if rng.rand(9) < 5:
      record.addComputedField("score", proc (r: Record): FieldValue =
        let value = rng.rand(1000) / 10.0
        FieldValue(kind: fieldFloat, floatValue: value)
      )

proc introduceMissingFields*(collection: var RecordCollection, fields: seq[string], ratio = 0.1, seed = 202) =
  var rng = initRand(seed)
  for record in collection.records.mitems:
    if rng.rand(100) < int(ratio * 100):
      let fieldName = fields[rng.rand(fields.len - 1)]
      record.dropField(fieldName)

proc sampleSchema*(): seq[FieldDef] =
  @[
    FieldDef(name: "customer", kind: fieldString, required: true),
    FieldDef(name: "amount", kind: fieldFloat, required: true),
    FieldDef(name: "quantity", kind: fieldInt, required: true),
    FieldDef(name: "region", kind: fieldString, required: false),
    FieldDef(name: "processed_at", kind: fieldTimestamp, required: false),
    FieldDef(name: "active", kind: fieldBool, required: false)
  ]

proc generateSimulation*(size = 25): RecordCollection =
  let schema = sampleSchema()
  result = generateCollection("simulation", schema, size)
  result.applySchema(schema)
  result.normalizeCollection()

proc simulatePipeline*(size = 25): RecordCollection =
  result = generateSimulation(size)
  mutateCollection(result)
  introduceMissingFields(result, @["region", "processed_at"], 0.2)

proc addSyntheticNotes*(collection: var RecordCollection) =
  for record in collection.records.mitems:
    record.metadata.addNote("synthetic record for benchmarking")
