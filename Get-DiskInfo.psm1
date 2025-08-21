# Documentation home: https://github.com/engrit-illinois/Get-DiskInfo

function Get-DiskInfo {
	
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string[]]$ComputerName,
		
		[string]$SearchBase,
		
		[int]$ThrottleLimit = 50,
		[int]$OperationTimeoutSec = 10,
		
		[switch]$PassThru,
		
		[switch]$DisablePsVersionCheck
	)
	
	function Get-Comps {
		$comps = @()
		$params = @{}
		if($SearchBase) { $params.SearchBase = $SearchBase }
		foreach($query in @($ComputerName)) {
			$params.Filter = "name -like '$query'"
			$thisQueryComps = (Get-ADComputer @params | Select Name).Name
			$comps += @($thisQueryComps)
		}
		$comps
	}
	
	function Get-Data($comps) {
		
		$scriptblock = {
			$comp = $_

			function addm($property, $value, $object) {
				$object | Add-Member -NotePropertyName $property -NotePropertyValue $value -PassThru
			}
			
			function Translate-DriveType($int) {
				# https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-logicaldisk
				switch($int) {
					0 { "Unknown (0)" }
					1 { "No Root Directory (1)" }
					2 { "Removable Disk (2)" }
					3 { "Local Disk (3)" }
					4 { "Network Drive (4)" }
					5 { "Compact Disc (5)" }
					6 { "RAM Disk (6)" }
				}
			}
			
			try {
				$OperationTimeoutSec = $using:OperationTimeoutSec
			}
			catch {}
			
			try {
				$diskInfo = Get-CimInstance -ClassName "Win32_LogicalDisk" -ComputerName $comp -OperationTimeoutSec $OperationTimeoutSec -ErrorAction "Stop"
			}
			catch {
				$err = $_.Exception.Message
			}
			
			$diskInfo | ForEach-Object {
				$diskInfo = $_
				
				if(-not $err) {
					$driveType = Translate-DriveType $diskInfo.DriveType
					$sizeGB = [math]::Round($diskInfo.Size/1GB,2)
					$freeGB = [math]::Round($diskInfo.FreeSpace/1GB,2)
					if(
						($null -ne $sizeGB) -and
						($null -ne $freeGB)
					) { $freePercent = [math]::Round((($freeGB/$sizeGB)*100),2) }
				}
				
				[PSCustomObject]@{
					"ComputerName" = $comp
					"DeviceId" = $diskInfo.DeviceID
					"VolumeName" = $diskInfo.VolumeName
					"VolumeSerialNumber" = $diskInfo.VolumeSerialNumber
					"DriveType" = $driveType
					"FileSystem" = $diskInfo.FileSystem
					"DiskSizeGB" = $sizeGB
					"FreeSpaceGB" = $freeGB
					"FreeSpacePercent" = $freePercent
					"Error" = $err
					"DiskInfo" = $diskInfo
				}
			}
		}
		
		$comps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel $scriptblock
	}
	
	function Organize-Data {
		$data = $data | Select ComputerName,DeviceId,VolumeName,VolumeSerialNumber,DriveType,FileSystem,DiskSizeGB,FreeSpaceGB,FreeSpacePercent,Error,DiskInfo
		$data | Sort ComputerName,DeviceId
	}
	
	function Print-Data {
		$data | Select ComputerName,DeviceId,VolumeName,VolumeSerialNumber,DriveType,FileSystem,DiskSizeGB,FreeSpaceGB,FreeSpacePercent,Error | Format-Table
	}
	
	function Return-Data($data) {
		if($PassThru) {
			$data
		}
	}
	
	function Validate-PsVersion {
		if(-not $DisablePsVersionCheck) {
			$ver = $Host.Version
			if($ver.Major -lt 7) {
				Throw "PowerShell version not supported!"
			}
		}
	}
	
	function Do-Stuff {
		Validate-PsVersion
		$comps = Get-Comps
		$data = Get-Data $comps
		$data = Organize-Data $comps
		Print-Data $data
		Return-Data $data
	}
	
	Do-Stuff
}