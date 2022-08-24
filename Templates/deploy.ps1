param(

[Parameter(Mandatory=$True)]
[string]
$subscriptionName,


[Parameter(Mandatory=$True)]
[string]
$resourceGroupName

)

#*********************************************************************************************************************************
#Script body                                                                                                                    **
#Execution beins here                                                                                                           **
#*********************************************************************************************************************************

#Sign in
Clear-AzContext

#Sign in
Write-Host "Login..."
Login-AzAccount  

#Select Subscription

try {
    $context= Set-AzContext -SubscriptionName $subscriptionName -ErrorAction Stop
}catch {
   throw "an error occured while attempting to select the subscription, please confirm the name of the subscription"
}

Select-AzSubscription -Name $subscriptionName -Context $context -ErrorAction Stop


#validate resource group or create a new one 

try {
    
    Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop

    Write-Host "Using resource group: $resourceGroupName" -ForegroundColor Green

}catch {
   
   Write-Host "Creating resource group, please provide region in the format eastus, westus, eastus2, etc..." -ForegroundColor Green
   $location = Read-Host -Prompt 'location: '

   $location = ($location -replace " ","").ToLower()

   Write-Host "The resource group with name $resourceGroupName in the location $location will be created" -ForegroundColor Green
   Write-Host "Creating resource group..." -ForegroundColor Green

   New-AzResourceGroup -Name $resourceGroupName -Location $location

}


#Deploy resources
New-AzResourceGroupDeployment -Name "functionapp" -ResourceGroupName $resourceGroupName -TemplateFile ".\main.bicep" -TemplateParameterFile ".\azuredeploy.parameters.json" -Verbose


