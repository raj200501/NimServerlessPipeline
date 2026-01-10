import std/[times, tables, sequtils]

from ./types import PipelineStageKind

type
  ScheduleWindow* = object
    startTime*: DateTime
    endTime*: DateTime

  StageBudget* = object
    stage*: PipelineStageKind
    maxPerMinute*: int

  StageUsage* = object
    stage*: PipelineStageKind
    startedAt*: DateTime
    count*: int

  Scheduler* = object
    window*: ScheduleWindow
    budgets*: Table[PipelineStageKind, StageBudget]
    usage*: Table[PipelineStageKind, StageUsage]

proc initScheduleWindow*(durationMinutes = 1): ScheduleWindow =
  let startTime = now()
  ScheduleWindow(startTime: startTime, endTime: startTime + initDuration(minutes = durationMinutes))

proc initScheduler*(durationMinutes = 1): Scheduler =
  Scheduler(
    window: initScheduleWindow(durationMinutes),
    budgets: initTable[PipelineStageKind, StageBudget](),
    usage: initTable[PipelineStageKind, StageUsage]()
  )

proc setBudget*(scheduler: var Scheduler, stage: PipelineStageKind, maxPerMinute: int) =
  scheduler.budgets[stage] = StageBudget(stage: stage, maxPerMinute: maxPerMinute)

proc resetWindow*(scheduler: var Scheduler, durationMinutes = 1) =
  scheduler.window = initScheduleWindow(durationMinutes)
  scheduler.usage.clear()

proc ensureWindow*(scheduler: var Scheduler) =
  if now() > scheduler.window.endTime:
    scheduler.resetWindow()

proc stageAllowance*(scheduler: Scheduler, stage: PipelineStageKind): int =
  if scheduler.budgets.hasKey(stage):
    scheduler.budgets[stage].maxPerMinute
  else:
    high(int)

proc stageUsed*(scheduler: Scheduler, stage: PipelineStageKind): int =
  if scheduler.usage.hasKey(stage):
    scheduler.usage[stage].count
  else:
    0

proc canRun*(scheduler: Scheduler, stage: PipelineStageKind): bool =
  scheduler.stageUsed(stage) < scheduler.stageAllowance(stage)

proc registerUsage*(scheduler: var Scheduler, stage: PipelineStageKind) =
  scheduler.ensureWindow()
  if scheduler.usage.hasKey(stage):
    scheduler.usage[stage].count += 1
  else:
    scheduler.usage[stage] = StageUsage(stage: stage, startedAt: now(), count: 1)

proc remainingBudget*(scheduler: Scheduler, stage: PipelineStageKind): int =
  scheduler.stageAllowance(stage) - scheduler.stageUsed(stage)

proc budgetSnapshot*(scheduler: Scheduler): Table[string, int] =
  result = initTable[string, int]()
  for stage in PipelineStageKind:
    result[$stage & ".remaining"] = scheduler.remainingBudget(stage)

proc waitForBudget*(scheduler: var Scheduler, stage: PipelineStageKind, sleepSeconds = 1) =
  while not scheduler.canRun(stage):
    sleep(sleepSeconds * 1000)
    scheduler.ensureWindow()

proc consumeBudget*(scheduler: var Scheduler, stage: PipelineStageKind, amount: int) =
  for _ in 0 ..< amount:
    scheduler.registerUsage(stage)

proc stageUsageSnapshot*(scheduler: Scheduler): seq[string] =
  for stage in PipelineStageKind:
    result.add($stage & ":" & $scheduler.stageUsed(stage))

proc nextWindowInSeconds*(scheduler: Scheduler): int =
  let nowTime = now()
  if nowTime >= scheduler.window.endTime:
    return 0
  int((scheduler.window.endTime - nowTime).inSeconds())

proc windowElapsed*(scheduler: Scheduler): Duration =
  now() - scheduler.window.startTime

proc windowRemaining*(scheduler: Scheduler): Duration =
  scheduler.window.endTime - now()
