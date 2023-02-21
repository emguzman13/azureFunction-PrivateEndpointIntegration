
export subscriptionId="1b89348f-c373-485a-9460-69cf12ada509";
export resourceGroup="rg-arc-test";
export tenantId="72f988bf-86f1-41af-91ab-2d7cd011db47";
export location="eastus2";
export authType="token";
export correlationId="85907b2b-df15-4dd7-8500-77f2e063cd19";
export cloud="AzureCloud";

# Download the installation package
output=$(wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh 2>&1);
if [ $? != 0 ]; then wget -qO- --method=PUT --body-data="{\"subscriptionId\":\"$subscriptionId\",\"resourceGroup\":\"$resourceGroup\",\"tenantId\":\"$tenantId\",\"location\":\"$location\",\"correlationId\":\"$correlationId\",\"authType\":\"$authType\",\"operation\":\"onboarding\",\"messageType\":\"DownloadScriptFailed\",\"message\":\"$output\"}" "https://gbl.his.arc.azure.com/log" &> /dev/null || true; fi;
echo "$output";

# Install the hybrid agent
bash ~/install_linux_azcmagent.sh;

# Run connect command
sudo azcmagent connect --resource-group "$resourceGroup" --tenant-id "$tenantId" --location "$location" --subscription-id "$subscriptionId" --cloud "$cloud" --tags "Datacenter=Mexico,City=CDMX,StateOrDistrict=CDMX,CountryOrRegion=Mexico" --correlation-id "$correlationId";
