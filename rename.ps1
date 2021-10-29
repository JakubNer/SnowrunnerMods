$prefix="vanilla_"
Get-ChildItem -path "." -file -force -recurse -filter "*.xml" | foreach-object {
	if (!$_.name.contains("joat")) {
		cd  $_.DirectoryName
		mv "$_" "${prefix}_$($_.BaseName).xml"
	}
}