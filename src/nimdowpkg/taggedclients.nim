import
  x11/x,
  lists,
  listutils,
  sets,
  sequtils,
  sugar

import
  client,
  tag,
  taginfo

export tag, taginfo, client, lists, sets

type
  ClientNode* = DoublyLinkedNode[Client]

  TaggedClients* = ref object
    clients*: DoublyLinkedList[Client]
    # TODO: Needs a better name.
    # This is the order of clients based on selection order, oldest to newest.
    clientSelection*: DoublyLinkedList[Client]

    tags*: seq[Tag]
    selectedTags*: OrderedSet[TagID]

proc contains*(this: TaggedClients, window: Window): bool
proc currClientsContains*(this: TaggedClients, window: Window): bool
proc currClientsContains*(this: TaggedClients, client: Client): bool
proc findCurrentClients*(this: TaggedClients): seq[Client]
proc getFirstSelectedTag*(this: TaggedClients): Tag

proc newTaggedClients*(tagCount: int): TaggedClients = TaggedClients()

iterator currClientsIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in stack order.
  for node in this.clients.nodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

iterator currClientsReverseIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in reverse stack order.
  for node in this.clients.reverseNodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

proc findNodeByWindow*(this: TaggedClients, window: Window): ClientNode =
  ## Finds a client based on its window property.
  for node in this.clients.nodes:
    if node.value.window == window:
      return node
  return nil

proc findByWindow*(this: TaggedClients, window: Window): Client =
  ## Finds a client based on its window property.
  let node = this.findNodeByWindow(window)
  if node != nil:
    return node.value

proc findByWindowInCurrentTags*(this: TaggedClients, window: Window): Client =
  ## Finds a client based on its window property,
  ## searching only the currently selected tags.
  for node in this.currClientsIter:
    let client = node.value
    if client.window == window:
      return client
  return nil

proc findNextCurrClient*(
  this: TaggedClients,
  startClient: Client,
  reversed: bool = false,
  accept: proc(client: Client): bool = (client: Client) => true
): ClientNode =
  if startClient == nil or this.clients.len <= 1:
    return nil

  template forEachClientNode(node, body: untyped) =
    if reversed:
      for n in this.currClientsReverseIter:
        var node: ClientNode = n
        body
    else:
      for n in this.currClientsIter:
        var node: ClientNode = n
        body

  var startClientFound = false
  forEachClientNode(node):
    if startClientFound:
      return node
    if startClient == node.value:
      startClientFound = true
      continue

  # Client was not in the list!
  if not startClientFound:
    return nil

  forEachClientNode(node):
    return node

iterator clientWithTagIter*(this: TaggedClients, tagID: TagID): ClientNode {.inline, closure.} =
  for node in this.clients.nodes:
    if node.value.tagIDs.contains(tagID):
      yield node

iterator currClientsSelectionNewToOldIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in order of selection,
  ## from most recent to least recent.
  for node in this.clientSelection.reverseNodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

iterator currClientsSelectionOldToNewIter*(this: TaggedClients): ClientNode {.inline, closure.} =
  ## Iterates over clients in order of selection,
  ## from least recent to most recent.
  for node in this.clientSelection.nodes:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      yield node

proc getFirstSelectedTag*(this: TaggedClients): Tag =
  ## Gets the first selected tag,
  ## or `nil` if to tags are selected.
  for tag in this.tags.items:
    result = tag
    break

proc findCurrentClients*(this: TaggedClients): seq[Client] =
  for node in this.currClientsIter:
    result.add(node.value)

proc currClientsContains*(this: TaggedClients, client: Client): bool =
  for node in this.currClientsIter:
    if node.value == client:
      return true
  return false

proc currClientsContains*(this: TaggedClients, window: Window): bool =
  for node in this.currClientsIter:
    if node.value != nil and node.value.window == window:
      return true
  return false

proc contains*(this: TaggedClients, window: Window): bool =
  for client in this.clients.items:
    if client != nil and client.window == window:
      return true
  return false

proc currClientNode*(this: TaggedClients): ClientNode =
  ## Gets the most recently selected client (as a node) in the list
  ## of clients that are available in the selectedTags.
  var currClient: Client
  for node in this.currClientsSelectionNewToOldIter:
    if node.value.tagIDs.anyIt(this.selectedTags.contains(it)):
      currClient = node.value
      break

  if currClient == nil:
    return nil

  return this.findNodeByWindow(currClient.window)

proc currClient*(this: TaggedClients): Client =
  ## Gets the most recently selected client in the list
  ## of clients that are available in the selectedTags.
  let node = this.currClientNode
  if node != nil:
    node.value
  else:
    nil

template withSomeCurrClient*(this: TaggedClients, client, body: untyped) =
  ## Executes `body` if `this.currClient != nil`
  if this.currClient != nil:
    var client: Client = this.currClient
    body

proc removeByWindow*(this: TaggedClients, window: Window): bool =
  # Remove the client from the list.
  for node in this.clients.nodes:
    if node.value.window == window:
      this.clients.remove(node)
      result = true
      break

  # Remove the client from the selection list.
  for node in this.clientSelection.nodes:
    if node.value.window == window:
      this.clientSelection.remove(node)
      break

proc findFirstSelectedTag*(this: TaggedClients): Tag =
  for id in this.selectedTags.items:
    return this.tags[id - 1]

proc find*(list: DoublyLinkedList[Client], window: Window): ClientNode =
  for node in list.nodes:
    if node.value != nil and node.value.window == window:
      result = node
      break

