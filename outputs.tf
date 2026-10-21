output "webapp_url" {
  description = "Public URL"
  value       = "https://${azurerm_linux_web_app.alweb.default_hostname}"
}
