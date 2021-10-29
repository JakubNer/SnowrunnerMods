# Script to rename addons such that they don't appear twice in the mod.

$prefix="vanilla_"
$pwd = pwd
Get-ChildItem -path "./classes" -file -force -recurse -filter "*.xml" | foreach-object {
	if (!$_.name.contains("joat") -and !$_.name.contains($prefix) -and ! $_.PSIsContainer) {
		cd  $_.DirectoryName
		mv "$_" "${prefix}_$($_.BaseName).xml"		
	}
}

$names = $()

Get-ChildItem -path "./classes" -file -force -recurse -filter "*.xml" | foreach-object {
	if (!$_.name.contains("joat") -and ! $_.PSIsContainer) {
		$names += $_.BaseName.replace("vanilla_", "")
	}
}

cd $pwd/classes/trucks

$names | ForEach {
	$nameToChange = $_
	Get-ChildItem -path "." -file -filter "*.xml" | foreach-object {
		if (!$_.name.contains("joat") -and ! $_.PSIsContainer) {
			((Get-Content -path $_ -Raw) -replace "$nameToChange","vanilla_$nameToChange") | Set-Content -Path $_
		}
	}
}