variable "bucket_name" {
  description = "Nome globalmente único do bucket S3 do domínio."
  type        = string
}

variable "tags" {
  description = "Tags obrigatórias aplicadas a todos os recursos do módulo."
  type        = map(string)
}

variable "enable_versioning" {
  description = "Habilita versionamento no bucket para rastreabilidade de Data Products."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Permite destruir o bucket mesmo com objetos (recomendado apenas em dev)."
  type        = bool
  default     = false
}
