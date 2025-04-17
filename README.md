# QRDA to FHIR (QI-Core) Converter

This Ruby-based tool parses QRDA Category I XML files and converts them into FHIR R4 JSON resources (Patient, Encounter, MedicationAdministration) conforming to [QI-Core](http://hl7.org/fhir/us/qicore/index.html) profiles.

### ✅ Features

- Parses QRDA Category I XML (HL7 CDA)
- Extracts demographic and clinical data
- Builds:
  - `Patient` (with gender, birthdate, race, ethnicity, name)
  - `Encounter`
  - `MedicationAdministration`
- Outputs three separate FHIR JSON files per input XML
- Supports local ZIP uploads and AWS S3 input/output
- Compatible with AWS Lambda (writes to `/tmp`, S3 optional)

---

## 🚀 Setup

### 1. Clone and Install

```bash
git clone https://github.com/karthikishorejs/qrdatofhir.git
cd qrdatofhir
bundle install
```

### 2. Start the Rails Server
``` rails server ```

## 🧪 Example API Usage
```curl -F "file=@Patients.zip" http://localhost:3000/convert```
You'll get ```{ "status": "success" }``` and files will be saved under output/

### 🧪 Testing with RSpec
```bundle exec rspec```

👨‍💻 Author
Built with ❤️ by @karthikishorejs
