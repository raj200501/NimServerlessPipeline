import std/[tables, sequtils, algorithm, strutils, math]
import ./types
import ./aggregations

proc percentile*(values: seq[float], percent: float): float =
  if values.len == 0:
    return 0.0
  let sorted = values.sorted
  let idx = int(round((percent / 100) * float(sorted.len - 1)))
  sorted[min(max(idx, 0), sorted.len - 1)]

proc computeQuantiles*(values: seq[float], percentiles: seq[float]): Table[float, float] =
  result = initTable[float, float]()
  for percent in percentiles:
    result[percent] = percentile(values, percent)

proc computeHistogram*(values: seq[float], buckets: int): Table[string, int] =
  result = initTable[string, int]()
  if values.len == 0 or buckets <= 0:
    return
  let minValue = values.min
  let maxValue = values.max
  let range = maxValue - minValue
  let bucketSize = if range == 0: 1.0 else: range / float(buckets)
  for value in values:
    let idx = int(min(float(buckets - 1), floor((value - minValue) / bucketSize)))
    let lower = minValue + bucketSize * float(idx)
    let upper = lower + bucketSize
    let label = $(lower.round(2)) & "-" & $(upper.round(2))
    result[label] = result.getOrDefault(label, 0) + 1

proc summarizeMetrics*(metrics: seq[KeyedMetric]): seq[string] =
  for metric in metrics:
    var labels: seq[string] = @[]
    for key, value in metric.labels:
      labels.add(key & "=" & value)
    let suffix = if labels.len > 0: "{" & labels.join(",") & "}" else: ""
    result.add(metric.name & suffix & "=" & $metric.value)

proc mergeMetrics*(primary, secondary: seq[KeyedMetric]): seq[KeyedMetric] =
  result = primary
  for metric in secondary:
    result.add(metric)

proc metricTable*(metrics: seq[KeyedMetric]): Table[string, float] =
  result = initTable[string, float]()
  for metric in metrics:
    result[metric.name] = result.getOrDefault(metric.name, 0.0) + metric.value

proc normalizeMetricNames*(metrics: var seq[KeyedMetric]) =
  for metric in metrics.mitems:
    metric.name = metric.name.toLowerAscii().replace(" ", "_")

proc adjustMetric*(metrics: var seq[KeyedMetric], name: string, delta: float) =
  var found = false
  for metric in metrics.mitems:
    if metric.name == name:
      metric.value += delta
      found = true
      break
  if not found:
    metrics.add(KeyedMetric(name: name, value: delta, labels: initTable[string, string]()))

proc computeAggregationMetrics*(result: AggregationResult): seq[KeyedMetric] =
  var metrics: seq[KeyedMetric] = @[]
  for key, count in result.counts:
    metrics.add(KeyedMetric(name: key & ".count", value: float(count), labels: initTable[string, string]()))
  for key, total in result.totals:
    metrics.add(KeyedMetric(name: key & ".total", value: total, labels: initTable[string, string]()))
  for key, avg in result.averages:
    metrics.add(KeyedMetric(name: key & ".avg", value: avg, labels: initTable[string, string]()))
  for key, minValue in result.mins:
    metrics.add(KeyedMetric(name: key & ".min", value: minValue, labels: initTable[string, string]()))
  for key, maxValue in result.maxes:
    metrics.add(KeyedMetric(name: key & ".max", value: maxValue, labels: initTable[string, string]()))
  metrics

proc formatMetricsLine*(metrics: seq[KeyedMetric]): string =
  metrics.summarizeMetrics().join(" ")

proc combineMetricTables*(tables: seq[Table[string, float]]): Table[string, float] =
  result = initTable[string, float]()
  for table in tables:
    for key, value in table:
      result[key] = result.getOrDefault(key, 0.0) + value

proc deltaMetrics*(previous, current: Table[string, float]): Table[string, float] =
  result = initTable[string, float]()
  for key, value in current:
    result[key] = value - previous.getOrDefault(key, 0.0)

proc scaleMetrics*(metrics: var seq[KeyedMetric], factor: float) =
  for metric in metrics.mitems:
    metric.value *= factor

proc tagMetrics*(metrics: var seq[KeyedMetric], labels: Table[string, string]) =
  for metric in metrics.mitems:
    for key, value in labels:
      metric.labels[key] = value

proc metricsToMap*(metrics: seq[KeyedMetric]): Table[string, string] =
  result = initTable[string, string]()
  for metric in metrics:
    result[metric.name] = $metric.value

proc trimMetrics*(metrics: seq[KeyedMetric], allowList: seq[string]): seq[KeyedMetric] =
  for metric in metrics:
    if metric.name in allowList:
      result.add(metric)

proc compactMetrics*(metrics: seq[KeyedMetric]): seq[KeyedMetric] =
  var table = initTable[string, KeyedMetric]()
  for metric in metrics:
    if table.hasKey(metric.name):
      var existing = table[metric.name]
      existing.value += metric.value
      table[metric.name] = existing
    else:
      table[metric.name] = metric
  result = table.values.toSeq

proc histogramMetrics*(values: seq[float], bucketSize: float, namePrefix: string): seq[KeyedMetric] =
  let histogram = bucketize(values, bucketSize)
  for label, count in histogram:
    var labels = initTable[string, string]()
    labels["range"] = label
    result.add(KeyedMetric(name: namePrefix & ".bucket", value: float(count), labels: labels))

proc quantileMetrics*(values: seq[float], percentiles: seq[float], namePrefix: string): seq[KeyedMetric] =
  let quantiles = computeQuantiles(values, percentiles)
  for percent, value in quantiles:
    var labels = initTable[string, string]()
    labels["percentile"] = $percent
    result.add(KeyedMetric(name: namePrefix & ".quantile", value: value, labels: labels))

proc mapMetricNames*(metrics: var seq[KeyedMetric], mapping: Table[string, string]) =
  for metric in metrics.mitems:
    if mapping.hasKey(metric.name):
      metric.name = mapping[metric.name]

proc filterMetrics*(metrics: seq[KeyedMetric], predicate: proc (m: KeyedMetric): bool {.closure.}): seq[KeyedMetric] =
  for metric in metrics:
    if predicate(metric):
      result.add(metric)
