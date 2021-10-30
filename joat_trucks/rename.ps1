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

cd $pwd/classes/trucks

Get-ChildItem -path "." -file -filter "*.xml" | foreach-object {
	$file = $_
	$content = Get-Content -path $file -Raw
	Write-Host $content
	exit
	Write-Host "replacing for $file"
	if ($file.name.contains("joat") -and ! $_.PSIsContainer) {
		$names | % {
			$nameToChange = $_
			Write-Host "   processing $nameToChange"
			$content.replace("$name0ToChange","vanilla_$nameToChange")
		}				
	}
	
	$content | Set-Content -Path $file
}

cd $pwd