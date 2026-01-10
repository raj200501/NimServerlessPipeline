import std/[sequtils, strutils, tables]
import ./records
import ./types


type
  StreamWindow* = object
    size*: int
    buffer*: seq[Record]

  StreamProcessor* = object
    window*: StreamWindow
    handlers*: seq[proc (records: seq[Record]) {.closure.}]

proc initWindow*(size: int): StreamWindow =
  StreamWindow(size: size, buffer: @[])

proc initStreamProcessor*(windowSize: int): StreamProcessor =
  StreamProcessor(window: initWindow(windowSize), handlers: @[])

proc addHandler*(processor: var StreamProcessor, handler: proc (records: seq[Record]) {.closure.}) =
  processor.handlers.add(handler)

proc flush*(processor: var StreamProcessor) =
  if processor.window.buffer.len == 0:
    return
  for handler in processor.handlers:
    handler(processor.window.buffer)
  processor.window.buffer = @[]

proc push*(processor: var StreamProcessor, record: Record) =
  processor.window.buffer.add(record)
  if processor.window.buffer.len >= processor.window.size:
    processor.flush()

proc processCollection*(processor: var StreamProcessor, collection: RecordCollection) =
  for record in collection.records:
    processor.push(record)
  processor.flush()

proc slidingWindow*(collection: RecordCollection, windowSize: int, step = 1): seq[seq[Record]] =
  if windowSize <= 0:
    return @[]
  var idx = 0
  while idx + windowSize <= collection.records.len:
    result.add(collection.records[idx ..< idx + windowSize])
    idx += step

proc streamMap*(collection: RecordCollection, windowSize: int, mapper: proc (records: seq[Record]): RecordCollection {.closure.}): seq[RecordCollection] =
  for window in collection.slidingWindow(windowSize):
    result.add(mapper(window))

proc streamReduce*(collection: RecordCollection, windowSize: int, reducer: proc (records: seq[Record]): Record {.closure.}): seq[Record] =
  for window in collection.slidingWindow(windowSize):
    result.add(reducer(window))

proc bufferSummary*(processor: StreamProcessor): string =
  "window=" & $processor.window.size & " buffered=" & $processor.window.buffer.len

proc recordWindowIds*(records: seq[Record]): seq[string] =
  records.mapIt(it.key.id)

proc toCollection*(namespace: string, records: seq[Record]): RecordCollection =
  var collection = initCollection(namespace)
  for record in records:
    collection.addRecord(record)
  collection

proc sumFieldInWindow*(records: seq[Record], fieldName: string): float =
  for record in records:
    if record.fields.hasKey(fieldName):
      result += parseFloat(record.fields[fieldName].fieldValueToString())

proc partitionByField*(collection: RecordCollection, fieldName: string): Table[string, RecordCollection] =
  result = initTable[string, RecordCollection]()
  for record in collection.records:
    if not record.fields.hasKey(fieldName):
      continue
    let value = record.fields[fieldName].fieldValueToString()
    if not result.hasKey(value):
      result[value] = initCollection(collection.namespace)
    result[value].addRecord(record)

proc streamPartition*(collection: RecordCollection, fieldName: string): seq[RecordCollection] =
  collection.partitionByField(fieldName).values.toSeq

proc limitRecords*(collection: RecordCollection, maxRecords: int): RecordCollection =
  result = initCollection(collection.namespace)
  for record in collection.records[0 ..< min(maxRecords, collection.records.len)]:
    result.addRecord(record)
