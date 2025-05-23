Set-AzVMExtension -ResourceGroupName "AZUREEASTPRODVMS" `
    -VMName "IDC2ADS04" `
    -Name "AzureMonitorWindowsAgent" `
    -Publisher "Microsoft.Azure.Monitor" `
    -ExtensionType "AzureMonitorWindowsAgent" `
    -TypeHandlerVersion "1.31.0.0" `
    -SettingString '{"workspaceId":"6fda7f5d-109b-4c67-b1e0-efb40e387f38"}' `
    -ProtectedSettingString '{"workspaceKey":"NFSTwQrnj4LeoN9LqJpy+wvWTRz+dsYpYPZPmoWSRvs3mk9atihk5CCKeXVYFhKHPqtNwNVCshRtcaEnDh5Iag=="}'
	


