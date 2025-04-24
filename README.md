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

```bash
rails server
```

---

## 🧪 Example API Usage

```bash
curl -F "file=@Patients.zip" http://localhost:3000/convert
```

You'll get:

```json
{ "status": "success" }
```

Files will be saved under the `output/` directory.

---

## 🧪 Testing with RSpec

Run the following command to execute the test suite:

```bash
bundle exec rspec
```

### 📊 Code Coverage

To generate a code coverage report, ensure you have the `simplecov` gem installed. Run the tests with:

```bash
COVERAGE=true bundle exec rspec
```

The coverage report will be available in the `coverage/` directory as an HTML file. Open it in your browser to view detailed metrics.

---

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Commit your changes and push the branch.
4. Open a pull request with a detailed description of your changes.

---

## 👨‍💻 Author

Built with ❤️ by [@karthikishorejs](https://github.com/karthikishorejs)
