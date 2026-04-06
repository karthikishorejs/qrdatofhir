# QRDA to FHIR (QI-Core) Converter

This Ruby-based tool parses QRDA Category I XML files and converts them into FHIR R4 JSON resources (Patient, Encounter, MedicationAdministration) conforming to [QI-Core](http://hl7.org/fhir/us/qicore/index.html) profiles.

---

## ✅ Features

- Parses QRDA Category I XML (HL7 CDA)
- Extracts demographic and clinical data
- Builds:
  - `Patient` (with gender, birthdate, race, ethnicity, name)
  - `Encounter`
  - `MedicationAdministration`
- Outputs three separate FHIR JSON files per input XML

---

## 🚀 Setup

### 1. Clone and Install

```bash
git clone https://github.com/karthikishorejs/qrdatofhir.git
cd qrdatofhir
bundle install
```

### 2. Start the Rails Server

```bash
rails server
```

---

## 🧪 Example API Usage

### 1) Convert QRDA ZIP → FHIR JSON output files

```bash
curl -F "file=@Patients.zip" http://localhost:3000/convert
```

You'll get:

```json
{ "status": "success" }
```

Files will be saved under the `output/` directory.

---

### 2) Load generated FHIR JSON into a HAPI FHIR server (FHIR R4)

Assuming HAPI FHIR is running at:

- Base URL: `http://127.0.0.1:8080/fhir`

#### Resource endpoints (API paths)

These are standard FHIR REST endpoints:

- `Patient` → `/fhir/Patient/{id}`
- `Encounter` → `/fhir/Encounter/{id}`
- `Condition` (diagnosis) → `/fhir/Condition/{id}`
- `Observation` → `/fhir/Observation/{id}`
- `Procedure` → `/fhir/Procedure/{id}`
- `ServiceRequest` → `/fhir/ServiceRequest/{id}`
- `MedicationAdministration` → `/fhir/MedicationAdministration/{id}`
- `MedicationStatement` → `/fhir/MedicationStatement/{id}`
- `MedicationRequest` → `/fhir/MedicationRequest/{id}`

#### Important rules when uploading

- If your JSON contains an `"id"` (all generated files do), use **PUT** with that same id in the URL.
- Upload in dependency order to avoid “reference not found” errors:
  1) Patient
  2) Condition(s)
  3) Encounter(s)
  4) Everything else

---

## 🧪 Loading ValueSets into HAPI (required for $evaluate-measure)

For `$evaluate-measure`, HAPI needs the **Measure**, **Libraries**, and **ValueSets** available. In this repo we load ValueSets by uploading a Bundle of `ValueSet` resources.

### 1) Start HAPI with Clinical Reasoning enabled

Example:
```bash
docker run --rm -p 8080:8080 \
  -e HAPI_FHIR_CR_ENABLED=true \
  hapiproject/hapi:latest
```

### 2) Upload the source ValueSet bundle

This repo includes a ValueSet bundle file (example):
- `dqm_vs_20251117.json`

**Important:** If you `POST /fhir` with `Bundle.type=collection`, HAPI will reject it. To have HAPI create/update the entries, you must use a `transaction` bundle (`type=transaction`) with `entry[].request`.

### 3) Convert to a server-aware transaction bundle (recommended)

HAPI enforces uniqueness on `ValueSet.url + ValueSet.version`. If you upload the same canonical under a different id, you can get:
- `HAPI-0902: Can not create multiple ValueSet resources with ValueSet.url ... and ValueSet.version ...`

We generate a “server-aware” transaction bundle that:
- searches the server by `(url, version)`
- PUTs to the existing server id if found
- otherwise creates a deterministic client id `<oid>-<version>`

Command:
```bash
python3 tools/server_aware_valueset_transaction.py \
  --base http://127.0.0.1:8080/fhir \
  --in dqm_vs_20251117.json \
  --out dqm_vs_20251117.transaction.serveraware.json
```

### 4) Load the generated transaction bundle into HAPI

```bash
curl --http1.1 -4 -X POST "http://127.0.0.1:8080/fhir" \
  -H "Content-Type: application/fhir+json" -H "Expect:" \
  --data-binary @dqm_vs_20251117.transaction.serveraware.json
```

### 5) Verify a ValueSet exists

```bash
curl -s -i "http://127.0.0.1:8080/fhir/ValueSet/2.16.840.1.113883.3.3157.1002.70-20240221" \
  -H "Accept: application/fhir+json"
```

### Notes / common gotchas

- If you restart HAPI without persistence, you must reload ValueSets + Measures.
- `$evaluate-measure` resolves ValueSets by **canonical URL**, so canonical resolution must work on your server.

---

## 🧯 Troubleshooting HAPI FHIR uploads (bundles / measure evaluation)

### Error: `HAPI-0527: Unable to process transaction where incoming Bundle.type = collection`

**Cause:** You POSTed a Bundle with `type=collection` to `POST /fhir`. HAPI interprets `POST /fhir` as a transaction/batch endpoint, and it rejects bundles that are not `type=transaction` or `type=batch`.

**Resolution options:**
1) If you want to store the Bundle *as a Bundle resource* (not process the entries), post to `/fhir/Bundle`:
```bash
curl --http1.1 -4 -X POST "http://127.0.0.1:8080/fhir/Bundle" \
  -H "Content-Type: application/fhir+json" -H "Expect:" \
  --data-binary @dqm_vs_20251117.json
```

2) If you want HAPI to create/update the entries, convert it to a `type=transaction` bundle and add `entry[].request`.

### Error: `HAPI-0902: Can not create multiple ValueSet resources with ValueSet.url ... and ValueSet.version ...`

**Cause:** HAPI enforces uniqueness on `ValueSet.url + ValueSet.version`.

**Resolution:** Use the server-aware transaction approach above:
- `tools/server_aware_valueset_transaction.py`

---

## 🧪 Testing with RSpec

Run the following command to execute the test suite:

```bash
bundle exec rspec
```

---

## 👨‍💻 Author

Built with ❤️ by [@karthikishorejs](https://github.com/karthikishorejs)
