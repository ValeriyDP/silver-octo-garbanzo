---
name: Anchoring Bucket Diagrams
date: 2026-11-11T14:55:00.000Z
tags:
  - bulk-anchoring
  - inv-43987
  - on-hold
  - wiki
  - diagram
---

# Anchoring Bucket Diagrams

> [!warning] On hold
> This investigation is on hold. Nothing here is a candidate for implementation. Use it as reference only.

**Summary**: Diagrams for the proposed hub bucket: module shape with pluggable sources (Excalidraw), an end-to-end `client_dlt` sequence from arrival to THE HUB's answer, `client_dlt` intake, finish-and-claim, per-wallet queues, and row status. The board drawing is [Anchoring Bucket Board](Anchoring%20Bucket%20Board.excalidraw.md).

**Sources**: [Anchoring Bucket](Anchoring%20Bucket.md), [ADR-0003 Keep Terminal Rows](../decisions/ADR-0003%20Keep%20Terminal%20Rows.md), [ADR-0004 Atomic Finish and Claim](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md), [ADR-0007 Pluggable Bucket Sources](../decisions/ADR-0007%20Pluggable%20Bucket%20Sources.md), [ADR-0009 One In Flight Per Signing Wallet](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md).

**Last updated**: 2026-11-12

---

These diagrams describe the proposed module. They are not a picture of shipped code. Current behaviour is [File Start Today](File%20Start%20Today.md).

## Module and sources

The core does not know events or commands. Each source plugs in an adapter. The entry event picks the source.

![Anchoring Bucket Module](Anchoring%20Bucket%20Module.excalidraw.md)

Drawing: [Anchoring Bucket Module](Anchoring%20Bucket%20Module.excalidraw.md). Standalone JSON for excalidraw.com: [Anchoring Bucket Module.excalidraw](Anchoring%20Bucket%20Module.excalidraw).

## End to end (`client_dlt`)

Two files, A1 and A2, for the same portfolio wallet arrive together. A2 waits until A1's whole business process ends with THE HUB's answer, then starts. Files for other wallets run the same flow in parallel. The in-memory stretch is lost if the pod stops; the wait for THE HUB's answer survives it.

```plantuml
@startuml
title client_dlt file, end to end through the bucket

skinparam sequenceMessageAlign center
hide footbox
autonumber

participant "Data room" as DR
queue "SNS / SQS FIFO" as Bus
participant "client_dlt adapter" as Adapter
participant "Bucket core" as Core
database "anchoring_bucket" as Bucket
participant "Provisioning chain\nRunPortfolioProvisioningCommand" as Chain
participant "THE HUB" as Hub
participant "Hub webhook handler\nHubDocumentSyncing*Event" as WH

== Arrival ==
DR -> Bus : ClientDLTTransaction A1
DR -> Bus : ClientDLTTransaction A2
Bus -> Adapter ++ : A1
Adapter -> Adapter : io_hub_organisation_map row?\nresolveProvisioningPortfolioId(dealId)
Adapter -> Core ++ : intake(A1, identity:{portfolioId})
Core -> Bucket : BEGIN, pg_advisory_xact_lock(queue_key)\nINSERT A1 waiting\nclaim A1 (no in_flight) -> in_flight\nCOMMIT
Core -> Chain : start A1 (after commit)
deactivate Core
deactivate Adapter

Bus -> Adapter ++ : A2
Adapter -> Core ++ : intake(A2, identity:{portfolioId})
Core -> Bucket : BEGIN, lock\nINSERT A2 waiting\nA1 is in_flight -> no claim\nCOMMIT
note right of Bucket : A2 waits.\nThe broker message is done;\nthe row keeps A2's place.
deactivate Core
deactivate Adapter

== A1: in-memory stretch (lost on pod stop) ==
activate Chain
Chain -> Hub : admin calls: organisation,\nIdentity {portfolioId}@measurabl.com, wallets
Hub --> Chain : ok

alt registry already in deal_anchors
  Chain -> Hub : addRecord\nPOST /ledgers/write | /ledgers/v3/write
  Hub --> Chain : accepted (transactionId | jobId)
else no registry
  Chain -> Hub : RegisterSymbolCommand (addRegistry)
  Hub --> Chain : accepted
  note right of Chain : document parked in\ndeal_anchors.pending_document;\nthe run ends here
  Hub -> WH : symbol registered (webhook)
  WH -> Chain : HubSymbolRegisteringSucceededEvent\n-> StoreDealAnchorRegistryCommand\n-> RunDocumentProvisioningCommand
  Chain -> Hub : addRecord
  Hub --> Chain : accepted
end
deactivate Chain

== A1: waiting for THE HUB (survives pod stop) ==
note over Hub : THE HUB queues the write\nper signing wallet and\nwrites it on chain
Hub -> WH ++ : webhook: Success or Failed

== A1 finishes, A2 starts ==
WH -> Core ++ : finish(taxonomyId = A1,\nSyncSuccess | sync_failed + reason)
Core -> Bucket : BEGIN, lock\nUPDATE A1 terminal WHERE status = in_flight\nclaim oldest waiting -> A2 in_flight\nCOMMIT
Core -> Chain : start A2 (after commit)
deactivate Core
deactivate WH
note over Chain, Hub : A2 runs the same steps.\nThe wallet now holds A2.

== Other finish exits for A1 ==
note over Chain, Core
  Each one runs the same finish transaction:
  - HubSymbolRegisteringFailedEvent -> sync_failed (matched by dealId)
  - throw in RunPortfolioProvisioningCommand -> sync_failed
  - throw in StoreDealAnchorRegistryCommand -> sync_failed
  - 503 queue full -> back to the tail as waiting (Open Questions #6)
  No exit at all (pod reset mid-stretch): A1 stays in_flight and
  holds the wallet (ADR-0005; recovery is Open Questions #7,
  graceful shutdown is #8).
end note
@enduml
```

## Intake (`client_dlt`)

Unknown organisation or unresolved portfolio: refused before a row exists. Insert and claim share one transaction under the wallet key's lock. The command runs after commit.

```plantuml
@startuml
title ClientDLTTransaction intake

skinparam sequenceMessageAlign center
hide footbox
autonumber

participant "Broker" as Bus
participant "client_dlt adapter" as Adapter
database "io_hub_organisation_map" as Map
database "deal_anchors" as Anchors
participant "Bucket core" as Core
database "anchoring_bucket" as Bucket
participant "RunPortfolioProvisioningCommand" as Cmd

Bus -> Adapter ++ : ClientDLTTransaction
Adapter -> Map ++ : findByIoOrganisationId(organisationId)

alt no map row
  Map --> Adapter -- : none
  note right of Adapter : log and stop\nno row\nchain does not start\nTHE HUB is not called
else known organisation
  Map --> Adapter -- : row
  Adapter -> Anchors : resolveProvisioningPortfolioId(dealId)
  alt no deal row or no portfolio
    Anchors --> Adapter : none
    note right of Adapter : log and stop\nno row\nTHE HUB is not called
  else portfolio found
    Anchors --> Adapter : portfolioId
    Adapter -> Core ++ : intake(source = client_dlt,\nqueue_key = identity:{portfolioId})
    Core -> Bucket ++ : BEGIN
    Core -> Bucket : pg_advisory_xact_lock(queue_key)
    Core -> Bucket : INSERT waiting\nON CONFLICT (source, taxonomy_id) DO NOTHING
    Core -> Bucket : claim oldest waiting\nif no in_flight for queue_key
    Bucket --> Core -- : COMMIT, claimed row or none
    opt a row was claimed
      Core -> Cmd : start claimed row\nafter commit
      note right of Cmd : may be an older waiting file\nnot the one just inserted
    end
    deactivate Core
  end
end

deactivate Adapter
@enduml
```

## Finish and claim

Every finish exit runs the same transaction. The terminal update is guarded by `status = 'in_flight'`, so a duplicate exit does nothing.

```plantuml
@startuml
title Finish the in-flight file and claim the next

skinparam sequenceMessageAlign center
hide footbox
autonumber

participant "Finish exit" as Src
participant "Bucket core" as Core
database "anchoring_bucket" as Bucket
participant "Start command" as Cmd

note over Src
  client_dlt exits:
  HubDocumentSyncingSucceededEvent  -> sync_success
  HubDocumentSyncingFailedEvent     -> sync_failed
  HubSymbolRegisteringFailedEvent   -> sync_failed (match by dealId)
  throw in RunPortfolioProvisioningCommand
  throw in StoreDealAnchorRegistryCommand
end note

Src -> Core ++ : finish(match, status, reason)
Core -> Bucket ++ : find in_flight row by match
alt none
  Bucket --> Core : none
  note right of Core : not a bucket file,\nor already finished
else found
  Core -> Bucket : BEGIN\npg_advisory_xact_lock(queue_key)
  Core -> Bucket : UPDATE status = terminal\nWHERE id AND status = in_flight
  alt zero rows
    note right of Bucket : another pod finished it\ncommit, stop
  else updated
    Core -> Bucket : claim oldest waiting for queue_key
    Bucket --> Core -- : COMMIT, claimed row or none
    opt a row was claimed
      Core -> Cmd : start through its source adapter\nafter commit
    end
  end
end
deactivate Core
@enduml
```

## Per-wallet queues

```plantuml
@startuml
title Signing-wallet queues

skinparam shadowing false
skinparam packageStyle rectangle

package "queue_key = identity:portfolio-A" {
  rectangle "in_flight\none per signing wallet" as Aflight #AliceBlue
  rectangle "waiting\noldest received_at, id" as Await1 #LightYellow
  rectangle "waiting\nlater arrival" as Await2 #LightYellow
  rectangle "sync_success\nselection ignores" as Aok #HoneyDew
  rectangle "sync_failed + reason\nselection ignores" as Abad #MistyRose
}

package "queue_key = identity:portfolio-B\n(same organisation as A)" {
  rectangle "in_flight\nruns in parallel with A" as Bflight #AliceBlue
}

package "queue_key = org:regular-org (regular, stub)" {
  rectangle "in_flight\nruns in parallel" as Cflight #WhiteSmoke
}

Await1 -up-> Aflight : claim
Await2 -up-> Await1 : FIFO
Aflight -right-> Aok : document succeeded
Aflight -right-> Abad : document failed,\nregistry failed,\nor chain threw

note bottom of Abad
  Rows are not deleted.
  Not synced = status is not sync_success.
  No finish exit: in_flight stays
  and holds portfolio A's wallet queue.
  No timeout. No reaper.
end note
@enduml
```

## State

```plantuml
@startuml
title anchoring_bucket status

[*] --> waiting : known organisation, portfolio resolved\nINSERT (dedupe on source, taxonomy_id)

waiting --> in_flight : oldest waiting row\nfor this wallet key\nwhen none is in_flight

in_flight --> sync_success : HubDocumentSyncingSucceededEvent
in_flight --> sync_failed : HubDocumentSyncingFailedEvent\nHubSymbolRegisteringFailedEvent\nor a caught chain throw

note right of sync_success
  Selection ignores
  sync_success and sync_failed.
  The row stays.
end note

note bottom of in_flight
  HubSymbolRegisteringSucceededEvent
  does not leave in_flight.
  No finish exit: stays in_flight,
  that wallet's queue does not advance.
  No timeout. No reaper.
end note
@enduml
```

## Related pages

- [Anchoring Bucket](Anchoring%20Bucket.md)
- [Anchoring Bucket Board](Anchoring%20Bucket%20Board.excalidraw.md)
- [Anchoring Bucket Module](Anchoring%20Bucket%20Module.excalidraw.md)
- [File Start Today](File%20Start%20Today.md)
- [ADR-0003 Keep Terminal Rows](../decisions/ADR-0003%20Keep%20Terminal%20Rows.md)
- [ADR-0004 Atomic Finish and Claim](../decisions/ADR-0004%20Atomic%20Finish%20and%20Claim.md)
- [ADR-0005 Unmarked In Flight Holds](../decisions/ADR-0005%20Unmarked%20In%20Flight%20Holds.md)
- [ADR-0007 Pluggable Bucket Sources](../decisions/ADR-0007%20Pluggable%20Bucket%20Sources.md)
- [ADR-0009 One In Flight Per Signing Wallet](../decisions/ADR-0009%20One%20In%20Flight%20Per%20Signing%20Wallet.md)
- [Wiki Index](index.md)
