# hook.ps1 — Dependency Change Guard
# Event: PreToolUse | Matcher: Write, Edit
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$filePath = $json.tool_input.file_path

if (-not $filePath) { exit 0 }

$fileName = [System.IO.Path]::GetFileName($filePath)

$dependencyFiles = @(
    'package.json', 'package-lock.json',
    'requirements.txt', 'Pipfile', 'Pipfile.lock',
    'Gemfile', 'Gemfile.lock',
    'go.mod', 'go.sum',
    'pom.xml', 'build.gradle',
    'Cargo.toml', 'Cargo.lock'
)

if ($dependencyFiles -contains $fileName) {
    [Console]::Error.WriteLine("CAUTION: Modifying dependency file: $fileName")
    [Console]::Error.WriteLine("Dependency changes can break builds, introduce vulnerabilities, or change behavior.")
    [Console]::Error.WriteLine("Review the changes carefully before allowing.")
    exit 2
}

exit 0
