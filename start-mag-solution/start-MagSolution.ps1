<#
    .DESCRIPTION
        

    .NOTES
        AUTHOR: 
        LASTEDIT: 
#>

param (
    [Parameter(Mandatory=$false)]
    [string] 
    $solution = "Identity"
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$vms_detail = @()

$vms = get-azurermvm

foreach ($vm in $vms)
{
    $vmtags = $vm.Tags

    if ( $vmtags.ContainsKey('Solution') )
    {
        if ( $vmtags.Item('Solution') -eq $solution )
        {
            $vm_detail = new-object System.Object
            $vm_detail | add-member -type NoteProperty -name vmname -value $vm.Name
            $vm_detail | add-member -type NoteProperty -name rgname -value $vm.ResourceGroupName
            
            if ( $vmtags.ContainsKey('Ring') )
            {
                $vm_detail | add-member -type NoteProperty -name ring -value $vmtags.Ring
            }
            else
            {
                                $vm_detail | add-member -type NoteProperty -name ring -value 99
            }
            if ( $vmtags.ContainsKey('Requires') )
            {
                $vm_detail | add-member -type NoteProperty -name requires -value $vmtags.Requires
            }
            else
            {
                                $vm_detail | add-member -type NoteProperty -name requires -value ""
            }
            $vms_detail += $vm_detail
        }

    }

}

$vms_detail = $vms_detail | sort ring

foreach ($vm_detail in $vms_detail )
{
    if ( $vm_detail.Requires )
    {   
        $required_solutions = $vm_detail.Requires -split (",") 
        foreach($required_solution in $required_solutions)
        {
           .\Start-MagSolution.ps1 -solution $required_solution
        }
    }
    Start-AzureRmVM -Name $vm_detail.vmname -ResourceGroupName $vm_detail.rgname
}

