import std/[tables, sequtils, strutils, options]
import ./types
import ./records

type
  ValidationRuleKind* = enum
    ruleRequired,
    ruleMinLength,
    ruleMaxLength,
    rulePattern,
    ruleRange,
    ruleAllowedValues

  ValidationRule* = object
    fieldName*: string
    kind*: ValidationRuleKind
    minValue*: float
    maxValue*: float
    minLength*: int
    maxLength*: int
    pattern*: string
    allowed*: seq[string]
    message*: string

  ValidationResult* = object
    fieldName*: string
    valid*: bool
    message*: string

proc requiredRule*(fieldName: string, message = "required"): ValidationRule =
  ValidationRule(fieldName: fieldName, kind: ruleRequired, message: message)

proc minLengthRule*(fieldName: string, minLength: int, message = "too short"): ValidationRule =
  ValidationRule(fieldName: fieldName, kind: ruleMinLength, minLength: minLength, message: message)

proc maxLengthRule*(fieldName: string, maxLength: int, message = "too long"): ValidationRule =
  ValidationRule(fieldName: fieldName, kind: ruleMaxLength, maxLength: maxLength, message: message)

proc patternRule*(fieldName: string, pattern: string, message = "invalid format"): ValidationRule =
  ValidationRule(fieldName: fieldName, kind: rulePattern, pattern: pattern, message: message)

proc rangeRule*(fieldName: string, minValue, maxValue: float, message = "out of range"): ValidationRule =
  ValidationRule(fieldName: fieldName, kind: ruleRange, minValue: minValue, maxValue: maxValue, message: message)

proc allowedValuesRule*(fieldName: string, allowed: seq[string], message = "invalid value"): ValidationRule =
  ValidationRule(fieldName: fieldName, kind: ruleAllowedValues, allowed: allowed, message: message)

proc validateRule*(record: Record, rule: ValidationRule): ValidationResult =
  if not record.fields.hasKey(rule.fieldName):
    if rule.kind == ruleRequired:
      return ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)
    return ValidationResult(fieldName: rule.fieldName, valid: true, message: "")

  let value = record.fields[rule.fieldName].fieldValueToString()
  case rule.kind
  of ruleRequired:
    if value.strip().len == 0:
      ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)
    else:
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
  of ruleMinLength:
    if value.len < rule.minLength:
      ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)
    else:
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
  of ruleMaxLength:
    if value.len > rule.maxLength:
      ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)
    else:
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
  of rulePattern:
    if rule.pattern.len == 0:
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
    elif value.contains(rule.pattern):
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
    else:
      ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)
  of ruleRange:
    let number = parseFloat(value)
    if number < rule.minValue or number > rule.maxValue:
      ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)
    else:
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
  of ruleAllowedValues:
    if value in rule.allowed:
      ValidationResult(fieldName: rule.fieldName, valid: true, message: "")
    else:
      ValidationResult(fieldName: rule.fieldName, valid: false, message: rule.message)

proc validateRecord*(record: Record, rules: seq[ValidationRule]): seq[ValidationResult] =
  for rule in rules:
    result.add(record.validateRule(rule))

proc recordIsValid*(record: Record, rules: seq[ValidationRule]): bool =
  for resultItem in record.validateRecord(rules):
    if not resultItem.valid:
      return false
  true

proc validationErrors*(results: seq[ValidationResult]): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()
  for res in results:
    if not res.valid:
      if not result.hasKey(res.fieldName):
        result[res.fieldName] = @[]
      result[res.fieldName].add(res.message)

proc applyValidation*(collection: var RecordCollection, rules: seq[ValidationRule], errorTag = "validation-error") =
  for record in collection.records.mitems:
    let results = record.validateRecord(rules)
    for res in results:
      if not res.valid:
        record.metadata.addTag(errorTag)
        record.metadata.addNote(res.fieldName & ":" & res.message)

proc requireFields*(fields: seq[string]): seq[ValidationRule] =
  for field in fields:
    result.add(requiredRule(field))

proc numericRangeRules*(fieldName: string, ranges: seq[(float, float)]): seq[ValidationRule] =
  for (minValue, maxValue) in ranges:
    result.add(rangeRule(fieldName, minValue, maxValue))

proc allowedValuesRules*(fieldName: string, values: seq[string]): seq[ValidationRule] =
  result.add(allowedValuesRule(fieldName, values))

proc validationSummary*(collection: RecordCollection, rules: seq[ValidationRule]): Table[string, int] =
  result = initTable[string, int]()
  for record in collection.records:
    for res in record.validateRecord(rules):
      if not res.valid:
        result[res.fieldName] = result.getOrDefault(res.fieldName, 0) + 1

proc normalizeRules*(rules: var seq[ValidationRule]) =
  for rule in rules.mitems:
    rule.fieldName = rule.fieldName.strip().toLowerAscii()
    rule.message = rule.message.strip()
