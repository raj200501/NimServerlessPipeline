import std/[tables, sequtils, strutils, times, options]
import ./types


type
  DatasetStatus* = enum
    datasetDraft,
    datasetActive,
    datasetDeprecated

  DatasetDescriptor* = object
    name*: string
    description*: string
    owner*: string
    createdAt*: DateTime
    updatedAt*: DateTime
    status*: DatasetStatus
    fields*: seq[FieldDef]
    tags*: seq[string]

  DatasetCatalog* = object
    datasets*: Table[string, DatasetDescriptor]

proc initDescriptor*(name: string, description: string, owner = "unknown"): DatasetDescriptor =
  DatasetDescriptor(
    name: name,
    description: description,
    owner: owner,
    createdAt: now(),
    updatedAt: now(),
    status: datasetDraft,
    fields: @[],
    tags: @[]
  )

proc initCatalog*(): DatasetCatalog =
  DatasetCatalog(datasets: initTable[string, DatasetDescriptor]())

proc addDataset*(catalog: var DatasetCatalog, descriptor: DatasetDescriptor) =
  catalog.datasets[descriptor.name] = descriptor

proc updateDataset*(catalog: var DatasetCatalog, name: string, update: proc (d: var DatasetDescriptor) {.closure.}) =
  if catalog.datasets.hasKey(name):
    var descriptor = catalog.datasets[name]
    update(descriptor)
    descriptor.updatedAt = now()
    catalog.datasets[name] = descriptor

proc removeDataset*(catalog: var DatasetCatalog, name: string) =
  if catalog.datasets.hasKey(name):
    catalog.datasets.del(name)

proc getDataset*(catalog: DatasetCatalog, name: string): Option[DatasetDescriptor] =
  if catalog.datasets.hasKey(name):
    some(catalog.datasets[name])
  else:
    none(DatasetDescriptor)

proc listDatasets*(catalog: DatasetCatalog): seq[string] =
  catalog.datasets.keys.toSeq.sorted

proc searchByTag*(catalog: DatasetCatalog, tag: string): seq[DatasetDescriptor] =
  for descriptor in catalog.datasets.values:
    if tag in descriptor.tags:
      result.add(descriptor)

proc addField*(descriptor: var DatasetDescriptor, field: FieldDef) =
  descriptor.fields.add(field)

proc addTag*(descriptor: var DatasetDescriptor, tag: string) =
  if tag.len > 0 and tag notin descriptor.tags:
    descriptor.tags.add(tag)

proc removeTag*(descriptor: var DatasetDescriptor, tag: string) =
  descriptor.tags = descriptor.tags.filterIt(it != tag)

proc setStatus*(descriptor: var DatasetDescriptor, status: DatasetStatus) =
  descriptor.status = status

proc fieldNames*(descriptor: DatasetDescriptor): seq[string] =
  descriptor.fields.mapIt(it.name)

proc findField*(descriptor: DatasetDescriptor, name: string): Option[FieldDef] =
  for field in descriptor.fields:
    if field.name == name:
      return some(field)
  none(FieldDef)

proc schemaSignature*(descriptor: DatasetDescriptor): string =
  var parts: seq[string] = @[]
  for field in descriptor.fields:
    parts.add(field.name & ":" & $field.kind)
  parts.join(",")

proc describeDataset*(descriptor: DatasetDescriptor): seq[string] =
  result.add("name=" & descriptor.name)
  result.add("owner=" & descriptor.owner)
  result.add("status=" & $descriptor.status)
  result.add("fields=" & $descriptor.fields.len)
  result.add("tags=" & descriptor.tags.join(","))

proc catalogSummary*(catalog: DatasetCatalog): seq[string] =
  result.add("datasets=" & $catalog.datasets.len)
  for name in catalog.listDatasets():
    result.add("- " & name)

proc mergeCatalogs*(primary, secondary: DatasetCatalog): DatasetCatalog =
  result = primary
  for name, descriptor in secondary.datasets:
    result.datasets[name] = descriptor
