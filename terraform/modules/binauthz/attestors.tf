resource "google_container_analysis_note" "build_note" {
  project = var.project_id
  name    = "${var.environment}-build-note"

  attestation_authority {
    hint {
      human_readable_name = "Build Attestor Note (${var.environment})"
    }
  }
}

resource "google_container_analysis_note" "vulnerability_scan_note" {
  project = var.project_id
  name    = "${var.environment}-vulnerability-scan-note"

  attestation_authority {
    hint {
      human_readable_name = "Vulnerability Scan Attestor Note (${var.environment})"
    }
  }
}

data "google_kms_crypto_key_version" "attestor_key_version" {
  crypto_key = var.attestor_signing_key_id
  version    = "1"
}

resource "google_binary_authorization_attestor" "build_attestor" {
  project = var.project_id
  name    = "${var.environment}-build-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name

    public_keys {
      id = "//cloudkms.googleapis.com/v1/${data.google_kms_crypto_key_version.attestor_key_version.name}"
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor_key_version.public_key[0].pem
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}

resource "google_binary_authorization_attestor" "vulnerability_scan_attestor" {
  project = var.project_id
  name    = "${var.environment}-vulnerability-scan-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.vulnerability_scan_note.name

    public_keys {
      id = "//cloudkms.googleapis.com/v1/${data.google_kms_crypto_key_version.attestor_key_version.name}"
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor_key_version.public_key[0].pem
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}
