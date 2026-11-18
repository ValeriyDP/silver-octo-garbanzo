---
name: Smart Accounts Diagram
date: 2026-08-08T20:14:00.000Z
tags:
  - smart-accounts
  - zerodev
  - erc-4337
  - architecture
  - diagram
---

# SmartAccounts — PlantUML Diagrams

Companion to [Smart Accounts Implementation State](Smart%20Accounts%20Implementation%20State.md) and [Smart Accounts Happy Flow](Smart%20Accounts%20Happy%20Flow.md).
Render with any PlantUML tool (e.g. the Obsidian PlantUML plugin, or https://www.plantuml.com/plantuml).

---

## 1. Component / architecture view

```plantuml
@startuml SmartAccounts-Components
skinparam monochrome true
title SmartAccounts -- Component Architecture

actor "Owner\n(passkey / EOA)" as Owner
rectangle "Client / Frontend\n(ZeroDev SDK — NOT built yet)" as FE

package "iam-service\n(custody & governance)" {
  [InternalSmartAccountsController\n/io-internal/smart-accounts/sessions] as IamInternal
  [SmartAccountsController\n/iam/smart-accounts] as IamPublic
  [Commands: Create / Renew / Revoke\n+ Actions: propose/sign/execute/cancel] as IamCmds
  database "Postgres\n(metadata, signers, actions)" as IamDb
}

package "hub-service\n(on-chain execution)" {
  [transactions.model\nshouldUseSmartAccount()] as HubModel
  [SmartAccountConfigProvider\n(30s cache)] as HubCfg
  [SmartAccountTokenizationProvider\n(write/read/status)] as HubProv
  [UserOpReceiptPollingService] as HubPoll
}

cloud "ZeroDev Bundler\n{url}/chain/{chainId}" as Bundler
cloud "ZeroDev Paymaster\n(sponsors gas)" as Paymaster
database "HashiCorp Vault\n(session-key material)" as Vault
node "EVM testnet\nSepolia / Base Sepolia / Amoy\n(Kernel v3.1 + EntryPoint 0.7)" as Chain

Owner --> FE : approve session key (off-chain sig)
FE --> IamPublic : POST /iam/smart-accounts (JWT)
IamPublic --> IamCmds
IamCmds --> Vault : write session key
IamCmds --> IamDb : persist metadata

HubModel --> HubCfg : is enabled?
HubCfg --> IamInternal : GET sessions (Bearer IO_KEY)
IamInternal --> Vault : read session key
HubModel --> HubProv : build provider
HubProv --> Bundler : sendUserOperation
HubProv --> Paymaster : getPaymasterData (sponsor)
Bundler --> Chain : submit UserOp
HubPoll --> Bundler : poll receipt
@enduml
```

---

## 2. Sequence — Phase A: provision account + session key (client-driven, one-time per org/chain)

```plantuml
@startuml SmartAccounts-PhaseA
skinparam monochrome true
title SmartAccounts — Phase A: Provision account + session key

actor Owner
participant "Client\n(ZeroDev SDK)" as FE
participant "iam-service" as IAM
database "Vault" as Vault
database "Postgres" as DB

Owner -> FE : initiate account setup
FE -> FE : create Kernel v3.1 account\n(counterfactual) -> address, index
FE -> FE : generate session key
Owner -> FE : approve session permissions\n(off-chain signature)
FE -> FE : serializePermissionAccount()\n-> sessionKey blob

FE -> IAM : POST /iam/smart-accounts\nAuthorization: Bearer <org-jwt>\n{address,index,chainIds,signingKey,sessions[]}
activate IAM
IAM -> Vault : writeSessionKey(vaultPath, sessionKey)
IAM -> DB : persist smart account\n(implementation=KERNEL_3_1, threshold=50, signer weight=50)
note right of IAM
  create hard-codes a single signer
  (// default to one signer for now)
end note
IAM --> FE : 201 Created
deactivate IAM
@enduml
```

---

## 3. Sequence — Phase B: automatic on-chain execution (per tokenization / verification tx)

```plantuml
@startuml SmartAccounts-PhaseB
skinparam monochrome true
title SmartAccounts — Phase B: Automatic on-chain execution

participant "Caller\n(existing tx flow)" as Caller
participant "hub-service\ntransactions.model" as Hub
participant "SmartAccountConfigProvider\n(30s cache)" as Cfg
participant "iam-service\n/io-internal/.../sessions" as IAM
database "Vault" as Vault
participant "SmartAccountTokenizationProvider" as Prov
participant "Bundler" as Bundler
participant "Paymaster" as Paymaster
participant "EVM chain" as Chain
participant "UserOpReceiptPollingService" as Poll

Caller -> Hub : tokenization / verification tx\n(organisationId, ledger)
activate Hub
Hub -> Cfg : shouldUseSmartAccount(org, ledger)
Cfg -> IAM : GET sessions?organisationId&chainId\nAuthorization: Bearer <IO_KEY>
activate IAM
IAM -> Vault : read active session key
IAM --> Cfg : {smartAccountAddress, chains[{chainId,session}]}
deactivate IAM

alt no active session / error
  Cfg --> Hub : false
  Hub -> Hub : fall back to legacy Hub API
else active session exists
  Cfg --> Hub : true (+ config)
  Hub -> Prov : build provider + deserialize session key\n(delegate SMART_ACCOUNT_SIGNING_KEY co-signs)
  Prov -> Paymaster : getPaymasterData (sponsor, gasless)
  Prov -> Bundler : sendUserOperation
  Bundler -> Chain : submit UserOp
  Prov --> Hub : userOpHash (= tx id)
  Hub --> Caller : accepted (userOpHash)

  loop until receipt or 24h expiry (backoff)
    Poll -> Bundler : getUserOperationReceipt(userOpHash)
    Bundler --> Poll : pending / receipt
  end
  Poll -> Poll : settle via onComplete\n(applied / failed)
end
deactivate Hub
@enduml
```

---

## 4. Sequence — Phase C: multisig governance action (client-signed, iam coordinates)

```plantuml
@startuml SmartAccounts-PhaseC
skinparam monochrome true
title SmartAccounts — Phase C: Multisig governance action

actor "Proposer" as P
actor "Co-signer(s)" as C
participant "Client" as FE
participant "iam-service" as IAM
database "Postgres" as DB
participant "Bundler/Chain" as Chain

P -> FE : initiate action (add/remove signer,\nrotate/revoke session key)
FE -> IAM : POST /iam/smart-accounts/:addr/actions\n{signature, publicKey, type, params}
IAM -> DB : create action + first signature
IAM -> IAM : signedWeight = proposer.weight
note right of IAM : threshold reached if\nsignedWeight >= threshold

loop until signedWeight >= threshold
  C -> FE : co-sign
  FE -> IAM : POST /actions/:id/sign\n{signature, publicKey}
  IAM -> DB : add signature
  IAM -> IAM : signedWeight += signer.weight
end

FE -> Chain : submit governance UserOp\n(client-signed)
Chain --> FE : userOperationHash
FE -> IAM : POST /actions/:id/execute\n{userOperationHash}
IAM -> DB : mark executed + update projection\n(add/remove signer, session key)
@enduml
```
