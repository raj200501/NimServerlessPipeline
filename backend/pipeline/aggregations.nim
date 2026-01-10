import std/[tables, sequtils, strutils, algorithm, math]
import ./types
import ./records

type
  AggregationResult* = object
    counts*: Table[string, int]
    totals*: Table[string, float]
    averages*: Table[string, float]
    mins*: Table[string, float]
    maxes*: Table[string, float]

proc initAggregationResult*(): AggregationResult =
  AggregationResult(
    counts: initTable[string, int](),
    totals: initTable[string, float](),
    averages: initTable[string, float](),
    mins: initTable[string, float](),
    maxes: initTable[string, float]()
  )

proc addCount*(result: var AggregationResult, key: string, amount = 1) =
  result.counts[key] = result.counts.getOrDefault(key, 0) + amount

proc addTotal*(result: var AggregationResult, key: string, value: float) =
  result.totals[key] = result.totals.getOrDefault(key, 0.0) + value
  if not result.mins.hasKey(key) or value < result.mins[key]:
    result.mins[key] = value
  if not result.maxes.hasKey(key) or value > result.maxes[key]:
    result.maxes[key] = value

proc finalizeAverages*(result: var AggregationResult) =
  for key, total in result.totals:
    let count = result.counts.getOrDefault(key, 0)
    if count > 0:
      result.averages[key] = total / float(count)

proc countByField*(collection: RecordCollection, fieldName: string): Table[string, int] =
  result = initTable[string, int]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let value = record.fields[fieldName].fieldValueToString()
      result[value] = result.getOrDefault(value, 0) + 1

proc sumByField*(collection: RecordCollection, fieldName: string): float =
  result = 0.0
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      result += parseFloat(record.fields[fieldName].fieldValueToString())

proc averageByField*(collection: RecordCollection, fieldName: string): float =
  if collection.records.len == 0:
    return 0.0
  let total = sumByField(collection, fieldName)
  total / float(collection.records.len)

proc aggregateByGroup*(collection: RecordCollection, groupField: string, valueField: string): AggregationResult =
  result = initAggregationResult()
  for record in collection.records:
    if not record.fields.hasKey(groupField):
      continue
    if not record.fields.hasKey(valueField):
      continue
    let groupKey = record.fields[groupField].fieldValueToString()
    let value = parseFloat(record.fields[valueField].fieldValueToString())
    result.addCount(groupKey)
    result.addTotal(groupKey, value)
  result.finalizeAverages()

proc groupRecords*(collection: RecordCollection, groupField: string): Table[string, RecordCollection] =
  result = initTable[string, RecordCollection]()
  for record in collection.records:
    if not record.fields.hasKey(groupField):
      continue
    let key = record.fields[groupField].fieldValueToString()
    if not result.hasKey(key):
      result[key] = initCollection(collection.namespace)
    result[key].addRecord(record)

proc distinctValues*(collection: RecordCollection, fieldName: string): seq[string] =
  var seen = initHashSet[string]()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let value = record.fields[fieldName].fieldValueToString()
      if value notin seen:
        seen.incl(value)
        result.add(value)
  result.sort()

proc topValues*(collection: RecordCollection, fieldName: string, limit = 5): seq[(string, int)] =
  let counts = collection.countByField(fieldName)
  var pairs = counts.pairs.toSeq
  pairs.sort(proc (a, b: (string, int)): int = cmp(b[1], a[1]))
  result = pairs[0 ..< min(limit, pairs.len)]

proc numericStats*(collection: RecordCollection, fieldName: string): AggregationResult =
  result = initAggregationResult()
  for record in collection.records:
    if record.fields.hasKey(fieldName):
      let value = parseFloat(record.fields[fieldName].fieldValueToString())
      result.addCount(fieldName)
      result.addTotal(fieldName, value)
  result.finalizeAverages()

proc pivotCounts*(collection: RecordCollection, rowField, columnField: string): Table[string, Table[string, int]] =
  result = initTable[string, Table[string, int]]()
  for record in collection.records:
    if not record.fields.hasKey(rowField) or not record.fields.hasKey(columnField):
      continue
    let rowKey = record.fields[rowField].fieldValueToString()
    let columnKey = record.fields[columnField].fieldValueToString()
    if not result.hasKey(rowKey):
      result[rowKey] = initTable[string, int]()
    result[rowKey][columnKey] = result[rowKey].getOrDefault(columnKey, 0) + 1

proc pivotTotals*(collection: RecordCollection, rowField, columnField, valueField: string): Table[string, Table[string, float]] =
  result = initTable[string, Table[string, float]]()
  for record in collection.records:
    if not record.fields.hasKey(rowField) or not record.fields.hasKey(columnField) or not record.fields.hasKey(valueField):
      continue
    let rowKey = record.fields[rowField].fieldValueToString()
    let columnKey = record.fields[columnField].fieldValueToString()
    let value = parseFloat(record.fields[valueField].fieldValueToString())
    if not result.hasKey(rowKey):
      result[rowKey] = initTable[string, float]()
    result[rowKey][columnKey] = result[rowKey].getOrDefault(columnKey, 0.0) + value

proc pivotAverages*(collection: RecordCollection, rowField, columnField, valueField: string): Table[string, Table[string, float]] =
  let totals = collection.pivotTotals(rowField, columnField, valueField)
  let counts = collection.pivotCounts(rowField, columnField)
  result = initTable[string, Table[string, float]]()
  for rowKey, rowTotals in totals:
    var row = initTable[string, float]()
    if counts.hasKey(rowKey):
      for colKey, totalValue in rowTotals:
        let count = counts[rowKey].getOrDefault(colKey, 0)
        if count > 0:
          row[colKey] = totalValue / float(count)
    result[rowKey] = row

proc summarizeAggregation*(result: AggregationResult): seq[string] =
  var output: seq[string] = @[]
  for key, count in result.counts:
    let avg = result.averages.getOrDefault(key, 0.0)
    let total = result.totals.getOrDefault(key, 0.0)
    let minValue = result.mins.getOrDefault(key, 0.0)
    let maxValue = result.maxes.getOrDefault(key, 0.0)
    output.add(key & ": count=" & $count & " total=" & $total & " avg=" & $avg & " min=" & $minValue & " max=" & $maxValue)
  output

proc rollingAverage*(values: seq[float], window: int): seq[float] =
  if window <= 0:
    return @[]
  var sum = 0.0
  for idx, value in values:
    sum += value
    if idx >= window:
      sum -= values[idx - window]
    if idx >= window - 1:
      result.add(sum / float(window))

proc cumulativeSum*(values: seq[float]): seq[float] =
  var sum = 0.0
  for value in values:
    sum += value
    result.add(sum)

proc bucketize*(values: seq[float], bucketSize: float): Table[string, int] =
  result = initTable[string, int]()
  for value in values:
    let bucket = floor(value / bucketSize) * bucketSize
    let label = $bucket & "-" & $(bucket + bucketSize)
    result[label] = result.getOrDefault(label, 0) + 1
