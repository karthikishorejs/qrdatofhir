module FHIRConstants
  QICORE_PATIENT_PROFILE = "http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-patient"
  QICORE_ENCOUNTER_PROFILE = "http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-encounter"
  QICORE_MEDICATION_PROFILE = "http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-medicationadministration"
  SNOMED_SYSTEM = "http://snomed.info/sct"
  LOINC_SYSTEM = "http://loinc.org"
  RXNORM_SYSTEM = "http://www.nlm.nih.gov/research/umls/rxnorm"
  US_CORE_RACE_URL = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race"
  US_CORE_ETHNICITY_URL = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity"
  OMB_RACE_SYSTEM = "urn:oid:2.16.840.1.113883.6.238"

  DEFAULT_ENCOUNTER_STATUS = "unknown".freeze
  DEFAULT_MEDICATION_STATUS = "completed".freeze
  DEFAULT_MEDICATION_CODE = "unknown".freeze

  CODE_SYSTEM_MAPPINGS = {
    "2.16.840.1.113883.6.96" => SNOMED_SYSTEM,
    "2.16.840.1.113883.6.1" => LOINC_SYSTEM,
    "2.16.840.1.113883.6.88" => RXNORM_SYSTEM
  }.freeze

  TYPE_SYSTEM_MAPPING = {
    "SNMCT" => {
      "CODE_SYSTEM" => "SNOMED",
      "CODE_SYSTEM_DISPLAY" => "http://snomed.info/sct",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    },
    "RXNORM" => {
      "CODE_SYSTEM" => "RXNORM",
      "CODE_SYSTEM_DISPLAY" => "http://www.nlm.nih.gov/research/umls/rxnorm",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    },
    "CPT4" => {
      "CODE_SYSTEM" => "CPT",
      "CODE_SYSTEM_DISPLAY" => "http://www.ama-assn.org/go/cpt",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    },
    "HCPCS" => {
      "CODE_SYSTEM" => "CMS",
      "CODE_SYSTEM_DISPLAY" => "https://www.cms.gov/Medicare/Coding/MedHCPCSGenInfo/index.html",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    },
    "LOINC" => {
      "CODE_SYSTEM" => "LOINC",
      "CODE_SYSTEM_DISPLAY" => "http://loinc.org",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    },
    "ICD10-CM" => {
      "CODE_SYSTEM" => "ICD10-CM",
      "CODE_SYSTEM_DISPLAY" => "http://hl7.org/fhir/sid/icd-10",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    },
    "ICD9-CM" => {
      "CODE_SYSTEM" => "ICD9-CM",
      "CODE_SYSTEM_DISPLAY" => "http://hl7.org/fhir/sid/icd-9",
      "VALUE_SET" => "http://cts.nlm.nih.gov/fhir/ValueSet/"
    }
  }.freeze

  ENCOUNTER_CLASS_MAPPINGS = {
    "183452005" => { code: "IMP", display: "inpatient encounter" },
    "32485007" => { code: "IMP", display: "inpatient encounter" },
    "8715000" => { code: "IMP", display: "inpatient encounter" },
    "448951000124107" => { code: "IMP", display: "inpatient encounter" },
    "4525004" => { code: "EMER", display: "emergency" }
  }.freeze

  DISCHARGE_DISPOSITION_MAPPINGS = {
    "428371000124100" => {
      "code" => "home",
      "display" => "Home",
      "system" => "http://terminology.hl7.org/CodeSystem/discharge-disposition"
    },
    "428361000124107" => {
      "code" => "hosp",
      "display" => "Hospice",
      "system" => "http://terminology.hl7.org/CodeSystem/discharge-disposition"
    },
    "306689006" => {
      "code" => "home",
      "display" => "Home",
      "system" => "http://terminology.hl7.org/CodeSystem/discharge-disposition"
    },
    "428521000124106" => {
      "code" => "rehab",
      "display" => "Rehabilitation",
      "system" => "http://terminology.hl7.org/CodeSystem/discharge-disposition"
    },
    "434781000124105" => {
      "code" => "other-hcf",
      "display" => "Other healthcare facility",
      "system" => "http://terminology.hl7.org/CodeSystem/discharge-disposition"
    }
  }.freeze
end
