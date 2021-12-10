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
		
		$content.Trim()
		$content | Set-Content -Path $file
	}
}


function prune() {
	$content = ""
	
	Get-ChildItem -path "$pwd\classes\trucks" -file -filter "*.xml" | foreach-object {
		$file = $_
		$content += Get-Content $file.FullName -Raw
	}
	
	Get-ChildItem -path "$pwd\classes\trucks\joat\" -file -filter "*.xml" | foreach-object {
		$file = $_
		$content += Get-Content $file.FullName -Raw
	}
	

	$names | % {
		$nameToCheck = $_
		Write-Host " $nameToCheck :: $($content.contains($nameToCheck))"
		if (! ($content.contains($nameToCheck))) {
			Get-ChildItem -path "$pwd/classes" -file -force -recurse -filter "*.xml" | foreach-object {
				if ($_.BaseName -eq "$prefix$nameToCheck") {
					Write-Host removing $_.FullName
					rm $_.FullName
				}
			}			
		}
	}					
}

cd $pwd/classes/trucks
renameXmls

cd $pwd/classes/trucks/joat
renameXmls

prune

cd $pwd