# Script to rename addons such that they don't appear twice in the mod.

$prefix="vanilla__"
$pwd = pwd
Get-ChildItem -path "./classes" -file -force -recurse -filter "*.xml" | foreach-object {
	if (!$_.name.contains("joat") -and !$_.name.contains($prefix) -and ! $_.PSIsContainer) {
		cd  $_.DirectoryName
		mv "$_" "${prefix}$($_.BaseName).xml"		
	}
}

$names = @()

Get-ChildItem -path "./classes" -file -force -recurse -filter "*.xml" | foreach-object {
	if (!$_.name.contains("joat") -and ! $_.PSIsContainer) {
		$names += $_.BaseName.replace($prefix, "")
	}
}

function renameXmls() {
	Get-ChildItem -path "." -file -filter "*.xml" | foreach-object {
		$file = $_
		$content = Get-Content -path $file -Raw
		if ($file.name.contains("joat") -and ! $_.PSIsContainer) {
			$names | % {
				$nameToChange = $_
				Write-Host "   processing $file :: $nameToChange"
				$content = $content -replace """$nameToChange""","""$prefix$nameToChange"""
			}				
		}
		
		$content | Set-Content -Path $file
	}
}

cd $pwd/classes/trucks
renameXmls

cd $pwd/classes/trucks/joat
renameXmls


cd $pwd