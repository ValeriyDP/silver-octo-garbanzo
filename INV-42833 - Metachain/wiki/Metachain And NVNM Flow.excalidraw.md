---
name: Metachain And NVNM Flow Excalidraw
date: 2026-10-02T13:00:00.000Z
tags:
  - metachain
  - inv-42833
  - nvnm
  - wiki
  - diagram
  - excalidraw
excalidraw-plugin: parsed
---

# Metachain And NVNM Flow

Switch this note to Excalidraw view in Obsidian, or open the standalone JSON on excalidraw.com. Companion discussion: [Metachain And NVNM Flow](Metachain%20And%20NVNM%20Flow.md). Standalone JSON: [Metachain And NVNM Flow.excalidraw](Metachain%20And%20NVNM%20Flow.excalidraw). Orientation is **top → bottom**.

# Excalidraw Data

## Text Elements
metachain-service — two actions (INV-42833) ^title

Top → bottom. Same MS, same Immudb. Different trigger, payload, table, and UI.
NVNM is the Hub cousin of taxonomy sync — not of event hashing. ^subtitle

metachain-service
started by Compose / Helm  ·  stays up  ·  consumes the broker ^mc-t

Action 1 — Track platform events and push hashes to Immudb
automatic audit  ·  INV-42833 is this lane  ·  does NOT set file Synced ^act1-label

Producers
data-room · deals · iam · hub
tasks · workflows · ai · notification ^prod-t

Broker
RabbitMQ / SNS→SQS ^broker-t

ProcessInveniamEvent
sha256(JSON.stringify(BaseEvent))
needs meta.eventId ^hash-t

Postgres  transactions
full BaseEvent + checksum ^pg-t

Immudb
{ eventId, hash } ^im-hash-t

Does NOT set file Synced
Deal-create ConnectInvMetachain is settings only ^no-badge-t

Action 1 payload
sha256(JSON.stringify(BaseEvent))
key eventId → { eventId, hash, key }   ·   generated key → { eventId, hash }
transactionId = generated key, not an EVM hash ^act1-payload

Action 2 — File taxonomy sync
DLT-style file fingerprint  ·  this is what shows the file as Synced ^act2-label

Start
Manual DLT sync  or  auto-sync after link
(skip file version 1) ^user-t

data-room-service
checksum still matches?
ledgerType = Metachain   ·   isHubConnected = false ^dr-t

MetachainSyncDocument
write(documentTaxonomy)
uri · checksum · dealName ^tax-t

Immudb (or QLDB)
full taxonomy JSON ^im-tax-t

Postgres sync-document tx
+ data-room taxonomy Succeed ^pg-tax-t

File chip: Synced
Deal log: user synced file to Metachain ^badge-t

Action 2 payload
documentTaxonomy JSON: dealName, document, uri, checksum, checksumAlgo,
timestamp, location, individualId ^act2-payload

Cousin of Action 2 only — NVNM / any EVM-like Hub ledger
not a Metachain write  ·  same kind of file fingerprint ^act3-label

User DLT sync
isHubConnected = true ^hub-user-t

data-room taxonomy
HubDocumentSyncingRequested ^hub-dr-t

hub-service codec
addRegistry / addRecord ^hub-t

Hub app
sign + broadcast ^happ-t

NVNM Chain
(or ETH / Polygon / Base) ^chain-t

NVNM cousin payload
addRecord: uri, checksum, metadata { taxonomyId, fileId, …taxonomy },
registryId = deal symbol
needs addRegistry(dealId) first ^act3-payload

%%
## Drawing
Canonical scene is the sibling `.excalidraw` file. Copy below into excalidraw.com via File → Open if the plugin does not render this note.

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.28.1",
  "elements": [
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4001,
      "version": 454,
      "versionNonce": 1062726379,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "title",
      "type": "text",
      "x": 318.9951080000001,
      "y": -1008.8030630000003,
      "width": 586.1956787109375,
      "height": 32.5,
      "text": "metachain-service \u2014 two actions (INV-42833)",
      "fontSize": 26,
      "fontFamily": 5,
      "textAlign": "left",
      "verticalAlign": "top",
      "containerId": null,
      "originalText": "metachain-service \u2014 two actions (INV-42833)",
      "autoResize": true,
      "lineHeight": 1.25,
      "index": "aT",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#495057",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4002,
      "version": 454,
      "versionNonce": 512841099,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "subtitle",
      "type": "text",
      "x": 318.9951080000001,
      "y": -966.8030630000003,
      "width": 593.0846557617188,
      "height": 37.5,
      "text": "Top \u2192 bottom. Same MS, same Immudb. Different trigger, payload, table, and UI.\nNVNM is the Hub cousin of taxonomy sync \u2014 not of event hashing.",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "left",
      "verticalAlign": "top",
      "containerId": null,
      "originalText": "Top \u2192 bottom. Same MS, same Immudb. Different trigger, payload, table, and UI.\nNVNM is the Hub cousin of taxonomy sync \u2014 not of event hashing.",
      "autoResize": true,
      "lineHeight": 1.25,
      "index": "aU",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#4dabf7",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4003,
      "version": 456,
      "versionNonce": 881093675,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "mc-t",
          "type": "text"
        },
        {
          "id": "CIbPm2f0",
          "type": "arrow"
        },
        {
          "id": "w5ZFhl8S",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "mc",
      "type": "rectangle",
      "x": 358.9951080000001,
      "y": -904.8030630000003,
      "width": 720,
      "height": 72,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "aV",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4004,
      "version": 456,
      "versionNonce": 1427877579,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "mc-t",
      "type": "text",
      "x": 471.2993072187501,
      "y": -888.8030630000003,
      "width": 495.3916015625,
      "height": 40,
      "text": "metachain-service\nstarted by Compose / Helm  \u00b7  stays up  \u00b7  consumes the broker",
      "fontSize": 16,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "mc",
      "originalText": "metachain-service\nstarted by Compose / Helm  \u00b7  stays up  \u00b7  consumes the broker",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "aW",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#e7f5ff",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4005,
      "version": 1247,
      "versionNonce": 1928437099,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "CIbPm2f0",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "act1",
      "type": "rectangle",
      "x": -252.3020575239134,
      "y": -732.434245402916,
      "width": 800,
      "height": 980,
      "index": "aX",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1864ab",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4006,
      "version": 1080,
      "versionNonce": 1230026763,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "fJyXcUpf",
      "type": "text",
      "x": -226.93118971780268,
      "y": -717.413538238346,
      "width": 559.9835205078125,
      "height": 40,
      "text": "Action 1 \u2014 Track platform events and push hashes to Immudb\nautomatic audit  \u00b7  INV-42833 is this lane  \u00b7  does NOT set file Synced",
      "fontSize": 16,
      "fontFamily": 5,
      "textAlign": "left",
      "verticalAlign": "top",
      "containerId": null,
      "originalText": "Action 1 \u2014 Track platform events and push hashes to Immudb\nautomatic audit  \u00b7  INV-42833 is this lane  \u00b7  does NOT set file Synced",
      "autoResize": true,
      "lineHeight": 1.25,
      "index": "aY",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#a5d8ff",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4007,
      "version": 1080,
      "versionNonce": 1177779883,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "prod-t",
          "type": "text"
        },
        {
          "id": "a1",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "prod",
      "type": "rectangle",
      "x": -202.93118971780268,
      "y": -653.413538238346,
      "width": 720,
      "height": 120,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "aZ",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4008,
      "version": 1084,
      "versionNonce": 876900683,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "prod-t",
      "type": "text",
      "x": 29.33638840719732,
      "y": -621.538538238346,
      "width": 255.46484375,
      "height": 56.25,
      "text": "Producers\ndata-room \u00b7 deals \u00b7 iam \u00b7 hub\ntasks \u00b7 workflows \u00b7 ai \u00b7 notification",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "prod",
      "originalText": "Producers\ndata-room \u00b7 deals \u00b7 iam \u00b7 hub\ntasks \u00b7 workflows \u00b7 ai \u00b7 notification",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "aa",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#74c0fc",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4009,
      "version": 1070,
      "versionNonce": 618532843,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "broker-t",
          "type": "text"
        },
        {
          "id": "a1",
          "type": "arrow"
        },
        {
          "id": "a2",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "broker",
      "type": "rectangle",
      "x": -202.93118971780268,
      "y": -501.41353823834584,
      "width": 720,
      "height": 80,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "ab",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4010,
      "version": 1068,
      "versionNonce": 436918923,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "broker-t",
      "type": "text",
      "x": 69.052864847627,
      "y": -481.41353823834584,
      "width": 176.03189086914062,
      "height": 40,
      "text": "Broker\nRabbitMQ / SNS\u2192SQS",
      "fontSize": 16,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "broker",
      "originalText": "Broker\nRabbitMQ / SNS\u2192SQS",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "ac",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#4dabf7",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4011,
      "version": 1065,
      "versionNonce": 1887785259,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "hash-t",
          "type": "text"
        },
        {
          "id": "a2",
          "type": "arrow"
        },
        {
          "id": "a3",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "hash",
      "type": "rectangle",
      "x": -202.93118971780268,
      "y": -389.41353823834584,
      "width": 720,
      "height": 110,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "ad",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4012,
      "version": 1069,
      "versionNonce": 163050443,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "hash-t",
      "type": "text",
      "x": 25.346428690400444,
      "y": -362.53853823834584,
      "width": 263.44476318359375,
      "height": 56.25,
      "text": "ProcessInveniamEvent\nsha256(JSON.stringify(BaseEvent))\nneeds meta.eventId",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "hash",
      "originalText": "ProcessInveniamEvent\nsha256(JSON.stringify(BaseEvent))\nneeds meta.eventId",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "ae",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#d0bfff",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4013,
      "version": 1067,
      "versionNonce": 901595755,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "pg-t",
          "type": "text"
        },
        {
          "id": "a3",
          "type": "arrow"
        },
        {
          "id": "a4",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "pg",
      "type": "rectangle",
      "x": -202.93118971780268,
      "y": -247.41353823834584,
      "width": 720,
      "height": 90,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "af",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4014,
      "version": 1068,
      "versionNonce": 1566555403,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "pg-t",
      "type": "text",
      "x": 60.2513740639356,
      "y": -221.16353823834584,
      "width": 193.63487243652344,
      "height": 37.5,
      "text": "Postgres  transactions\nfull BaseEvent + checksum",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "pg",
      "originalText": "Postgres  transactions\nfull BaseEvent + checksum",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "ag",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#b197fc",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4015,
      "version": 1065,
      "versionNonce": 1813636011,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "oPQ5tlWh",
          "type": "text"
        },
        {
          "id": "a4",
          "type": "arrow"
        },
        {
          "id": "a5",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "im-hash",
      "type": "rectangle",
      "x": -202.93118971780268,
      "y": -125.41353823834584,
      "width": 720,
      "height": 90,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "ah",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4016,
      "version": 1067,
      "versionNonce": 2048276043,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "oPQ5tlWh",
      "type": "text",
      "x": 88.3808677773145,
      "y": -100.41353823834584,
      "width": 137.37588500976562,
      "height": 40,
      "text": "Immudb\n{ eventId, hash }",
      "fontSize": 16,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "im-hash",
      "originalText": "Immudb\n{ eventId, hash }",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "ai",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#fff3bf",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4017,
      "version": 1065,
      "versionNonce": 909063403,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "ciL1lzBq",
          "type": "text"
        },
        {
          "id": "a5",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "no-badge",
      "type": "rectangle",
      "x": -202.93118971780268,
      "y": -3.4135382383457227,
      "width": 720,
      "height": 110,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "aj",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4018,
      "version": 1069,
      "versionNonce": 267345803,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "ciL1lzBq",
      "type": "text",
      "x": -12.821021260771431,
      "y": 34.08646176165405,
      "width": 339.7796630859375,
      "height": 35,
      "text": "Does NOT set file Synced\nDeal-create ConnectInvMetachain is settings only",
      "fontSize": 14,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "no-badge",
      "originalText": "Does NOT set file Synced\nDeal-create ConnectInvMetachain is settings only",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "ak",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4019,
      "version": 1081,
      "versionNonce": 563164715,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "a1",
      "type": "arrow",
      "x": 157.14081028219732,
      "y": -527.4135382383458,
      "width": 0,
      "height": 19.999999999999886,
      "points": [
        [
          0,
          0
        ],
        [
          0,
          19.999999999999886
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "prod",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "broker",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "al",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4020,
      "version": 1076,
      "versionNonce": 1509898443,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "a2",
      "type": "arrow",
      "x": 157.14081028219732,
      "y": -415.41353823834606,
      "width": 0,
      "height": 20.000000000000114,
      "points": [
        [
          0,
          0
        ],
        [
          0,
          20.000000000000114
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "broker",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "hash",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "am",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4021,
      "version": 1068,
      "versionNonce": 1725163371,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "a3",
      "type": "arrow",
      "x": 157.14081028219744,
      "y": -273.41353823834584,
      "width": 1.1368683772161603e-13,
      "height": 20,
      "points": [
        [
          0,
          0
        ],
        [
          -1.1368683772161603e-13,
          20
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "hash",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "pg",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "an",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4022,
      "version": 1068,
      "versionNonce": 1582940683,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "a4",
      "type": "arrow",
      "x": 157.14081028219732,
      "y": -151.41353823834584,
      "width": 0,
      "height": 20,
      "points": [
        [
          0,
          0
        ],
        [
          0,
          20
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "pg",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "im-hash",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "ao",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4023,
      "version": 1076,
      "versionNonce": 696993963,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "a5",
      "type": "arrow",
      "x": 157.14081028219732,
      "y": -29.413538238345836,
      "width": 0,
      "height": 19.999999999999886,
      "points": [
        [
          0,
          0
        ],
        [
          0,
          19.999999999999886
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "im-hash",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "no-badge",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "ap",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#1864ab",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "U-GhMW9ZQ8d6XCQQN0mt5",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4024,
      "version": 1067,
      "versionNonce": 772995915,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "nxiB85MH",
      "type": "text",
      "x": -226.93118971780268,
      "y": 124.58646176165405,
      "width": 535.5692138671875,
      "height": 70,
      "text": "Action 1 payload\nsha256(JSON.stringify(BaseEvent))\nkey eventId \u2192 { eventId, hash, key }   \u00b7   generated key \u2192 { eventId, hash }\ntransactionId = generated key, not an EVM hash",
      "fontSize": 14,
      "fontFamily": 5,
      "textAlign": "left",
      "verticalAlign": "top",
      "containerId": null,
      "originalText": "Action 1 payload\nsha256(JSON.stringify(BaseEvent))\nkey eventId \u2192 { eventId, hash, key }   \u00b7   generated key \u2192 { eventId, hash }\ntransactionId = generated key, not an EVM hash",
      "autoResize": true,
      "lineHeight": 1.25,
      "index": "aq",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#ebfbee",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4025,
      "version": 733,
      "versionNonce": 944462315,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "w5ZFhl8S",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "act2",
      "type": "rectangle",
      "x": 885.566508698257,
      "y": -732.4342449918911,
      "width": 800,
      "height": 980,
      "index": "ar",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4026,
      "version": 732,
      "versionNonce": 624878731,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "mq5iz30H",
      "type": "text",
      "x": 901.566508698257,
      "y": -720.4342449918911,
      "width": 519.1515502929688,
      "height": 40,
      "text": "Action 2 \u2014 File taxonomy sync\nDLT-style file fingerprint  \u00b7  this is what shows the file as Synced",
      "fontSize": 16,
      "fontFamily": 5,
      "textAlign": "left",
      "verticalAlign": "top",
      "containerId": null,
      "originalText": "Action 2 \u2014 File taxonomy sync\nDLT-style file fingerprint  \u00b7  this is what shows the file as Synced",
      "autoResize": true,
      "lineHeight": 1.25,
      "index": "as",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#b2f2bb",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4027,
      "version": 732,
      "versionNonce": 1286085419,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "user-t",
          "type": "text"
        },
        {
          "id": "b1",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "user",
      "type": "rectangle",
      "x": 925.566508698257,
      "y": -656.4342449918911,
      "width": 720,
      "height": 110,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "at",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4028,
      "version": 734,
      "versionNonce": 720469451,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "user-t",
      "type": "text",
      "x": 1131.5465807197413,
      "y": -629.5592449918911,
      "width": 308.03985595703125,
      "height": 56.25,
      "text": "Start\nManual DLT sync  or  auto-sync after link\n(skip file version 1)",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "user",
      "originalText": "Start\nManual DLT sync  or  auto-sync after link\n(skip file version 1)",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "au",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#8ce99a",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4029,
      "version": 732,
      "versionNonce": 1261800555,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "dr-t",
          "type": "text"
        },
        {
          "id": "b1",
          "type": "arrow"
        },
        {
          "id": "b2",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "dr",
      "type": "rectangle",
      "x": 925.566508698257,
      "y": -514.4342449918911,
      "width": 720,
      "height": 120,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "av",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4030,
      "version": 732,
      "versionNonce": 1899939595,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "dr-t",
      "type": "text",
      "x": 1096.0491136787257,
      "y": -482.5592449918911,
      "width": 379.0347900390625,
      "height": 56.25,
      "text": "data-room-service\nchecksum still matches?\nledgerType = Metachain   \u00b7   isHubConnected = false",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "dr",
      "originalText": "data-room-service\nchecksum still matches?\nledgerType = Metachain   \u00b7   isHubConnected = false",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "aw",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#69db7c",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4031,
      "version": 730,
      "versionNonce": 59223467,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "tax-t",
          "type": "text"
        },
        {
          "id": "b2",
          "type": "arrow"
        },
        {
          "id": "b3",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "tax",
      "type": "rectangle",
      "x": 925.566508698257,
      "y": -362.4342449918911,
      "width": 720,
      "height": 110,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "ax",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4032,
      "version": 732,
      "versionNonce": 893042763,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "tax-t",
      "type": "text",
      "x": 1190.4590639350736,
      "y": -335.5592449918911,
      "width": 190.2148895263672,
      "height": 56.25,
      "text": "MetachainSyncDocument\nwrite(documentTaxonomy)\nuri \u00b7 checksum \u00b7 dealName",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "tax",
      "originalText": "MetachainSyncDocument\nwrite(documentTaxonomy)\nuri \u00b7 checksum \u00b7 dealName",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "ay",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#b197fc",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4033,
      "version": 730,
      "versionNonce": 1882357483,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "im-tax-t",
          "type": "text"
        },
        {
          "id": "b3",
          "type": "arrow"
        },
        {
          "id": "b4",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "im-tax",
      "type": "rectangle",
      "x": 925.566508698257,
      "y": -220.4342449918911,
      "width": 720,
      "height": 80,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "az",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4034,
      "version": 732,
      "versionNonce": 2130274699,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "im-tax-t",
      "type": "text",
      "x": 1214.2865556953275,
      "y": -199.1842449918911,
      "width": 142.55990600585938,
      "height": 37.5,
      "text": "Immudb (or QLDB)\nfull taxonomy JSON",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "im-tax",
      "originalText": "Immudb (or QLDB)\nfull taxonomy JSON",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "b00",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#d0bfff",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4035,
      "version": 730,
      "versionNonce": 1992949803,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "pg-tax-t",
          "type": "text"
        },
        {
          "id": "b4",
          "type": "arrow"
        },
        {
          "id": "b5",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "pg-tax",
      "type": "rectangle",
      "x": 925.566508698257,
      "y": -108.43424499189109,
      "width": 720,
      "height": 90,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "b01",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4036,
      "version": 732,
      "versionNonce": 1636745931,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "pg-tax-t",
      "type": "text",
      "x": 1171.2515596626126,
      "y": -82.18424499189109,
      "width": 228.62989807128906,
      "height": 37.5,
      "text": "Postgres sync-document tx\n+ data-room taxonomy Succeed",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "pg-tax",
      "originalText": "Postgres sync-document tx\n+ data-room taxonomy Succeed",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "b02",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "#fff3bf",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 3
      },
      "seed": 4037,
      "version": 730,
      "versionNonce": 669135211,
      "isDeleted": false,
      "boundElements": [
        {
          "id": "badge-t",
          "type": "text"
        },
        {
          "id": "b5",
          "type": "arrow"
        }
      ],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "badge",
      "type": "rectangle",
      "x": 925.566508698257,
      "y": 13.565755008109022,
      "width": 720,
      "height": 100,
      "customData": {
        "legacyTextWrap": true
      },
      "index": "b03",
      "created": null,
      "hasTextLink": false
    },
    {
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4038,
      "version": 732,
      "versionNonce": 990825483,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "badge-t",
      "type": "text",
      "x": 1143.4265856025538,
      "y": 44.81575500810902,
      "width": 284.27984619140625,
      "height": 37.5,
      "text": "File chip: Synced\nDeal log: user synced file to Metachain",
      "fontSize": 15,
      "fontFamily": 5,
      "textAlign": "center",
      "verticalAlign": "middle",
      "containerId": "badge",
      "originalText": "File chip: Synced\nDeal log: user synced file to Metachain",
      "autoResize": false,
      "lineHeight": 1.25,
      "index": "b04",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4039,
      "version": 733,
      "versionNonce": 2131694251,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "b1",
      "type": "arrow",
      "x": 1285.6385086982573,
      "y": -540.4342449918909,
      "width": 5.684341886080802e-14,
      "height": 19.999999999999773,
      "points": [
        [
          0,
          0
        ],
        [
          -5.684341886080802e-14,
          19.999999999999773
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "user",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "dr",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "b05",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4040,
      "version": 730,
      "versionNonce": 1955431755,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "b2",
      "type": "arrow",
      "x": 1285.6385086982573,
      "y": -388.4342449918911,
      "width": 5.684341886080802e-14,
      "height": 19.999999999999773,
      "points": [
        [
          0,
          0
        ],
        [
          -5.684341886080802e-14,
          19.999999999999773
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "dr",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "tax",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "b06",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4041,
      "version": 730,
      "versionNonce": 585409515,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "b3",
      "type": "arrow",
      "x": 1285.6385086982573,
      "y": -246.4342449918911,
      "width": 0,
      "height": 20.000000000000227,
      "points": [
        [
          0,
          0
        ],
        [
          0,
          20.000000000000227
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "tax",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "im-tax",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "b07",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4042,
      "version": 730,
      "versionNonce": 1109323403,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "b4",
      "type": "arrow",
      "x": 1285.6385086982573,
      "y": -134.43424499189086,
      "width": 1.1368683772161603e-13,
      "height": 19.999999999999773,
      "points": [
        [
          0,
          0
        ],
        [
          -1.1368683772161603e-13,
          19.999999999999773
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "im-tax",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "pg-tax",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "b08",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": {
        "type": 2
      },
      "seed": 4043,
      "version": 730,
      "versionNonce": 620160299,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "b5",
      "type": "arrow",
      "x": 1285.6385086982573,
      "y": -12.434244991891092,
      "width": 5.684341886080802e-14,
      "height": 19.999999999999773,
      "points": [
        [
          0,
          0
        ],
        [
          5.684341886080802e-14,
          19.999999999999773
        ]
      ],
      "lastCommittedPoint": null,
      "startBinding": {
        "mode": "orbit",
        "elementId": "pg-tax",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "endBinding": {
        "mode": "orbit",
        "elementId": "badge",
        "fixedPoint": [
          0.5001,
          0.5001
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "index": "b09",
      "created": null,
      "hasTextLink": false,
      "moveMidPointsWithElement": false
    },
    {
      "angle": 0,
      "strokeColor": "#2b8a3e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 1,
      "strokeStyle": "solid",
      "roughness": 0,
      "opacity": 100,
      "groupIds": [
        "jhCBl9rPb11tTIsWRTs1T",
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "roundness": null,
      "seed": 4044,
      "version": 730,
      "versionNonce": 1658259403,
      "isDeleted": false,
      "boundElements": [],
      "updated": 1790946509452,
      "link": null,
      "locked": false,
      "id": "onfLBW1y",
      "type": "text",
      "x": 901.566508698257,
      "y": 137.56575500810902,
      "width": 515.8014526367188,
      "height": 52.5,
      "text": "Action 2 payload\ndocumentTaxonomy JSON: dealName, document, uri, checksum, checksumAlgo,\ntimestamp, location, individualId",
      "fontSize": 14,
      "fontFamily": 5,
      "textAlign": "left",
      "verticalAlign": "top",
      "containerId": null,
      "originalText": "Action 2 payload\ndocumentTaxonomy JSON: dealName, document, uri, checksum, checksumAlgo,\ntimestamp, location, individualId",
      "autoResize": true,
      "lineHeight": 1.25,
      "index": "b0A",
      "created": null,
      "hasTextLink": false,
      "rawText": "",
      "labelPosition": null,
      "baseFontSize": null
    },
    {
      "id": "CIbPm2f0",
      "type": "arrow",
      "x": 688.1780882793544,
      "y": -826.8030630000003,
      "width": 457.5117765511366,
      "height": 88.86881759708433,
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "groupIds": [
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "index": "b0B",
      "roundness": {
        "type": 2
      },
      "seed": 91631333,
      "version": 544,
      "versionNonce": 1104795243,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1790946509452,
      "created": 1790946320311,
      "link": null,
      "locked": false,
      "points": [
        [
          0,
          0
        ],
        [
          -457.5117765511366,
          88.86881759708433
        ]
      ],
      "startBinding": {
        "elementId": "mc",
        "mode": "orbit",
        "fixedPoint": [
          0.5001,
          1
        ]
      },
      "endBinding": {
        "elementId": "act1",
        "mode": "orbit",
        "fixedPoint": [
          0.07778227001544175,
          0.07778227001544179
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "elbowed": false
    },
    {
      "id": "w5ZFhl8S",
      "type": "arrow",
      "x": 752.9369539507104,
      "y": -826.8030630000003,
      "width": 501.66219595939555,
      "height": 88.86881800810917,
      "angle": 0,
      "strokeColor": "#1e1e1e",
      "backgroundColor": "transparent",
      "fillStyle": "solid",
      "strokeWidth": 2,
      "strokeStyle": "solid",
      "roughness": 1,
      "opacity": 100,
      "groupIds": [
        "-zJArXdU8bG1VpQQZ0wfj"
      ],
      "frameId": null,
      "index": "b0C",
      "roundness": {
        "type": 2
      },
      "seed": 534951973,
      "version": 597,
      "versionNonce": 1623838987,
      "isDeleted": false,
      "boundElements": null,
      "updated": 1790946509452,
      "created": 1790946326561,
      "link": null,
      "locked": false,
      "points": [
        [
          0,
          0
        ],
        [
          501.66219595939555,
          88.86881800810917
        ]
      ],
      "startBinding": {
        "elementId": "mc",
        "mode": "orbit",
        "fixedPoint": [
          0.5001,
          1
        ]
      },
      "endBinding": {
        "elementId": "act2",
        "mode": "orbit",
        "fixedPoint": [
          0.5001,
          0
        ]
      },
      "startArrowhead": null,
      "endArrowhead": "arrow",
      "elbowed": false
    }
  ],
  "appState": {
    "theme": "light",
    "viewBackgroundColor": "#ffffff",
    "currentItemStrokeColor": "#1e1e1e",
    "currentItemBackgroundColor": "transparent",
    "currentItemFillStyle": "solid",
    "currentItemStickynoteStrokeColor": "#1e1e1e",
    "currentItemStrokeWidthKey": "medium",
    "currentItemStrokeVariability": "constant",
    "currentItemStrokeStyle": "solid",
    "currentItemRoughness": 1,
    "currentItemOpacity": 100,
    "currentItemFontFamily": 5,
    "currentItemFontSize": 20,
    "currentItemTextAlign": "left",
    "currentItemStartArrowhead": null,
    "currentItemEndArrowhead": "arrow",
    "currentItemArrowType": "round",
    "currentItemFrameRole": null,
    "scrollX": 332.9270629182071,
    "scrollY": 636.293779197955,
    "zoom": {
      "value": 1.032501
    },
    "currentItemRoundness": "round",
    "gridSize": 20,
    "gridStep": 5,
    "gridModeEnabled": false,
    "gridColor": {
      "Bold": "rgba(179, 179, 179, 0.5)",
      "Regular": "rgba(204, 204, 204, 0.5)"
    },
    "colorTopPicks": {
      "elementStroke": null,
      "elementBackground": null,
      "bucketFill": null,
      "stickyNoteStroke": null,
      "stickyNoteBackground": null
    },
    "fontTopPicks": null,
    "currentStrokeOptions": null,
    "frameRendering": {
      "enabled": true,
      "clip": true,
      "name": true,
      "outline": true,
      "markerName": true,
      "markerEnabled": true
    },
    "objectsSnapModeEnabled": true,
    "activeTool": {
      "type": "selection",
      "customType": null,
      "locked": false,
      "fromSelection": false,
      "lastActiveTool": null
    },
    "disableContextMenu": false,
    "bindingPreference": "enabled",
    "isMidpointSnappingEnabled": true,
    "boxSelectionMode": "contain",
    "inputDevice": "auto"
  },
  "files": {}
}
```
