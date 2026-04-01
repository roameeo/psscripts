
function Set-WindowState {
    param (
        [Parameter()]
        [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
        $Style = 'SHOW',
        
        [Parameter()]
        $MainWindowHandle = (Get-Process -Id $PID).MainWindowHandle
    )
    
    $WindowStates = @{
        HIDE = 0
        SHOWNORMAL = 1
        SHOWMINIMIZED = 2
        SHOWMAXIMIZED = 3
        MAXIMIZE = 3
        SHOWNOACTIVATE = 4
        SHOW = 5
        MINIMIZE = 6
        SHOWMINNOACTIVE = 7
        SHOWNA = 8
        RESTORE = 9
        SHOWDEFAULT = 10
        FORCEMINIMIZE = 11
    }
    
$Win32ShowWindowAsync = Add-Type -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru -MemberDefinition @"
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@
    
    $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$Style]) | Out-Null
}

If (-Not(Get-Module -ListAvailable -Name "Microsoft.Graph")) { IInstall-Module Microsoft.Graph -RequiredVersion 2.33.0 -Scope CurrentUser -Force:$True }
If (!((Get-Module).Name  -Contains "Microsoft.Graph")){ Import-Module Microsoft.Graph -RequiredVersion 2.33.0 }
Set-MgGraphOption -EnableLoginByWAM $false


$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Connect-MgGraph -ClientId "14d82eec-204b-4c2f-b7e8-296a70dab67e" -TenantId "4ae3e62c-0859-4770-bff6-d2bea3170dc7" -Scopes "Group.Read.All" -NoWelcome
$AllUltGraphGroups = Get-MgGroup -All 
$AllUltGraphGroups | ForEach-Object{ $_ | Add-Member -MemberType NoteProperty -Name "Tenant" -Value $((Get-MgContext).Account.Split('@')[1]) -Force:$true }
Write-Host -Object "Total of $($AllUltGraphGroups.count) groups within Ulterra Graph"
Start-Sleep -Seconds 3    
Disconnect-Graph   

 