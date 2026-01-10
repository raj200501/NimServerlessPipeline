import std/[times, math, tables, strutils]

from ./types import Severity

type
  RetryPolicy* = object
    maxAttempts*: int
    baseDelayMs*: int
    maxDelayMs*: int
    jitter*: float

  RetryState* = object
    attempts*: int
    lastDelayMs*: int

  RetryOutcome* = object
    success*: bool
    attempts*: int
    delayMs*: int

proc initPolicy*(maxAttempts = 3, baseDelayMs = 100, maxDelayMs = 5000, jitter = 0.2): RetryPolicy =
  RetryPolicy(maxAttempts: maxAttempts, baseDelayMs: baseDelayMs, maxDelayMs: maxDelayMs, jitter: jitter)

proc nextDelayMs*(policy: RetryPolicy, state: RetryState): int =
  let exponent = min(state.attempts, 10)
  let base = float(policy.baseDelayMs) * pow(2.0, float(exponent))
  var delay = int(min(base, float(policy.maxDelayMs)))
  if policy.jitter > 0:
    let jitterWindow = int(float(delay) * policy.jitter)
    delay = delay + (if jitterWindow > 0: (jitterWindow div 2) else: 0)
  delay

proc shouldRetry*(policy: RetryPolicy, state: RetryState): bool =
  state.attempts < policy.maxAttempts

proc registerFailure*(state: var RetryState, policy: RetryPolicy): int =
  state.attempts += 1
  state.lastDelayMs = policy.nextDelayMs(state)
  state.lastDelayMs

proc runWithRetry*[T](policy: RetryPolicy, op: proc (): T {.closure.}): (T, RetryOutcome) =
  var state = RetryState(attempts: 0, lastDelayMs: 0)
  var lastException: ref Exception = nil
  while policy.shouldRetry(state):
    try:
      let value = op()
      return (value, RetryOutcome(success: true, attempts: state.attempts, delayMs: state.lastDelayMs))
    except Exception as exc:
      lastException = exc
      let delayMs = state.registerFailure(policy)
      if policy.shouldRetry(state):
        sleep(delayMs)
  raise lastException

proc classifyRetrySeverity*(state: RetryState): Severity =
  if state.attempts <= 1:
    severityWarning
  elif state.attempts <= 3:
    severityError
  else:
    severityCritical

proc policyFromLabels*(labels: Table[string, string]): RetryPolicy =
  result = initPolicy()
  if labels.hasKey("maxAttempts"):
    result.maxAttempts = parseInt(labels["maxAttempts"])
  if labels.hasKey("baseDelayMs"):
    result.baseDelayMs = parseInt(labels["baseDelayMs"])
  if labels.hasKey("maxDelayMs"):
    result.maxDelayMs = parseInt(labels["maxDelayMs"])
  if labels.hasKey("jitter"):
    result.jitter = parseFloat(labels["jitter"])

proc outcomeSummary*(outcome: RetryOutcome): string =
  if outcome.success:
    "success after " & $outcome.attempts & " attempts"
  else:
    "failed after " & $outcome.attempts & " attempts"

proc delaySchedule*(policy: RetryPolicy): seq[int] =
  var state = RetryState(attempts: 0, lastDelayMs: 0)
  while policy.shouldRetry(state):
    let delay = state.registerFailure(policy)
    result.add(delay)
