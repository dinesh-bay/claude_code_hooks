$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$filePath = $json.tool_input.file_path

if (-not $filePath) { exit 0 }

$ext = [System.IO.Path]::GetExtension($filePath)

switch ($ext) {
    { $_ -in ".js", ".jsx", ".ts", ".tsx", ".css", ".json", ".html" } {
        $prettier = Get-Command npx -ErrorAction SilentlyContinue
        if ($prettier) { & npx prettier --write $filePath 2>$null }
    }
    { $_ -in ".py" } {
        $black = Get-Command black -ErrorAction SilentlyContinue
        if ($black) { & black --quiet $filePath 2>$null }
    }
}

exit 0
