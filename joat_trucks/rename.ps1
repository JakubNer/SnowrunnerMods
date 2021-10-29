function renameXMLs($folder) {
	$prefix="vanilla_"
	Get-ChildItem -path $folder -file -force -recurse -filter "*.xml" | foreach-object {
		if (!$_.name.contains("joat") -and !$_.name.contains("vanilla_") -and ! $_.PSIsContainer) {
			cd  $_.DirectoryName
			mv "$_" "${prefix}_$($_.BaseName).xml"
		}
	}
}

renameXMLs("./classes")
