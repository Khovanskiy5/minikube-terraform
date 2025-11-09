plugin "yandex" {
  enabled = false
}

config {
  format = "default"
  call_module_type = "all"
}

rule "terraform_unused_declarations" { enabled = true }
rule "terraform_deprecated_index" { enabled = true }
rule "terraform_documented_variables" { enabled = true }
rule "terraform_typed_variables" { enabled = true }
rule "terraform_required_version" { enabled = true }
