$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$filePath = $json.tool_input.file_path

if ($filePath) {
    Set-Clipboard -Value $filePath
}
exit 0
