import std/[os, strformat, times]

proc makeTempDir*(name: string): string =
  let base = getTempDir() / "nim_pipeline_tests"
  createDir(base)
  let suffix = now().format("yyyyMMddHHmmss")
  let path = base / fmt"{name}_{suffix}"
  createDir(path)
  path

proc withTempDir*(name: string, body: proc(path: string)) =
  let path = makeTempDir(name)
  body(path)
  removeDir(path, true)
