import std/[tables, sequtils, sets]

type
  NodeId* = string

  GraphNode* = object
    id*: NodeId
    label*: string
    metadata*: Table[string, string]

  Graph* = object
    nodes*: Table[NodeId, GraphNode]
    edges*: Table[NodeId, HashSet[NodeId]]

proc initGraph*(): Graph =
  Graph(nodes: initTable[NodeId, GraphNode](), edges: initTable[NodeId, HashSet[NodeId]]())

proc addNode*(graph: var Graph, id: NodeId, label = ""): GraphNode =
  if not graph.nodes.hasKey(id):
    let node = GraphNode(id: id, label: label, metadata: initTable[string, string]())
    graph.nodes[id] = node
  graph.nodes[id]

proc addEdge*(graph: var Graph, fromId, toId: NodeId) =
  discard graph.addNode(fromId)
  discard graph.addNode(toId)
  if not graph.edges.hasKey(fromId):
    graph.edges[fromId] = initHashSet[NodeId]()
  graph.edges[fromId].incl(toId)

proc neighbors*(graph: Graph, id: NodeId): seq[NodeId] =
  if graph.edges.hasKey(id):
    graph.edges[id].toSeq
  else:
    @[]

proc indegree*(graph: Graph, id: NodeId): int =
  var count = 0
  for fromId, targets in graph.edges:
    if id in targets:
      count += 1
  count

proc outdegree*(graph: Graph, id: NodeId): int =
  if graph.edges.hasKey(id):
    graph.edges[id].len
  else:
    0

proc topologicalSort*(graph: Graph): seq[NodeId] =
  var inDegrees = initTable[NodeId, int]()
  for nodeId in graph.nodes.keys:
    inDegrees[nodeId] = 0
  for fromId, targets in graph.edges:
    for target in targets:
      inDegrees[target] = inDegrees.getOrDefault(target, 0) + 1
  var queue: seq[NodeId] = @[]
  for nodeId, degree in inDegrees:
    if degree == 0:
      queue.add(nodeId)
  var idx = 0
  while idx < queue.len:
    let nodeId = queue[idx]
    idx += 1
    result.add(nodeId)
    if graph.edges.hasKey(nodeId):
      for neighbor in graph.edges[nodeId]:
        inDegrees[neighbor] = inDegrees.getOrDefault(neighbor, 0) - 1
        if inDegrees[neighbor] == 0:
          queue.add(neighbor)

proc hasCycle*(graph: Graph): bool =
  graph.topologicalSort().len != graph.nodes.len

proc findRoots*(graph: Graph): seq[NodeId] =
  for nodeId in graph.nodes.keys:
    if graph.indegree(nodeId) == 0:
      result.add(nodeId)

proc findLeaves*(graph: Graph): seq[NodeId] =
  for nodeId in graph.nodes.keys:
    if graph.outdegree(nodeId) == 0:
      result.add(nodeId)

proc reverse*(graph: Graph): Graph =
  result = initGraph()
  for nodeId, node in graph.nodes:
    result.nodes[nodeId] = node
  for fromId, targets in graph.edges:
    for target in targets:
      result.addEdge(target, fromId)

proc pathExists*(graph: Graph, startId, targetId: NodeId): bool =
  var visited = initHashSet[NodeId]()
  var stack: seq[NodeId] = @[startId]
  while stack.len > 0:
    let current = stack.pop()
    if current == targetId:
      return true
    if current in visited:
      continue
    visited.incl(current)
    for neighbor in graph.neighbors(current):
      stack.add(neighbor)
  false

proc depthFirstOrder*(graph: Graph, startId: NodeId): seq[NodeId] =
  var visited = initHashSet[NodeId]()
  var stack: seq[NodeId] = @[startId]
  while stack.len > 0:
    let current = stack.pop()
    if current in visited:
      continue
    visited.incl(current)
    result.add(current)
    for neighbor in graph.neighbors(current):
      stack.add(neighbor)

proc toAdjacencyList*(graph: Graph): Table[NodeId, seq[NodeId]] =
  result = initTable[NodeId, seq[NodeId]]()
  for nodeId in graph.nodes.keys:
    result[nodeId] = graph.neighbors(nodeId)

proc cloneGraph*(graph: Graph): Graph =
  result = initGraph()
  for nodeId, node in graph.nodes:
    result.nodes[nodeId] = node
  for fromId, targets in graph.edges:
    result.edges[fromId] = targets

proc addMetadata*(graph: var Graph, nodeId, key, value: string) =
  discard graph.addNode(nodeId)
  graph.nodes[nodeId].metadata[key] = value

proc getMetadata*(graph: Graph, nodeId, key: string): string =
  if graph.nodes.hasKey(nodeId) and graph.nodes[nodeId].metadata.hasKey(key):
    graph.nodes[nodeId].metadata[key]
  else:
    ""
