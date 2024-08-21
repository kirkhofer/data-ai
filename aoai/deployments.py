from azure.identity import DefaultAzureCredential
import requests

def get_deployments():
    credential = DefaultAzureCredential()
    token = credential.get_token("https://management.azure.com/.default").token
    header= {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

    items=[]
    subs = requests.get('https://management.azure.com/subscriptions?api-version=2022-12-01',headers=header).json()
    for sub in subs['value']:
        subId=sub['subscriptionId']

        rgs = requests.get(f"https://management.azure.com/subscriptions/{subId}/resourceGroups?api-version=2022-12-01",headers=header).json()
        for rg in rgs['value']:
            resourceGroupName=rg['name']
            response = requests.get(f"https://management.azure.com/subscriptions/{subId}/resourceGroups/{resourceGroupName}/providers/Microsoft.CognitiveServices/accounts?api-version=2023-05-01",headers=header)
            if response.status_code == 200:
                for account in response.json()['value']:
                    if account['kind'] == 'OpenAI':
                        print(f"Running {account['name']}")
                        # Get the endpoints and primary key
                        endpoint=account["properties"]["endpoint"]
                        keys_url = f"https://management.azure.com/subscriptions/{subId}/resourceGroups/{resourceGroupName}/providers/Microsoft.CognitiveServices/accounts/{account['name']}/listKeys?api-version=2023-05-01"
                        keys_response = requests.post(keys_url, headers=header)
                        keys_data = keys_response.json()
                        primary_key = keys_data["key1"]
                        deployments = requests.get(f"https://management.azure.com/subscriptions/{subId}/resourceGroups/{resourceGroupName}/providers/Microsoft.CognitiveServices/accounts/{account['name']}/deployments?api-version=2023-05-01",headers=header).json()
                        for deployment in deployments['value']:
                            items.append({'subscriptionId':subId,'resourceGroupName':resourceGroupName,'accountName':account['name'],'deploymentName':deployment['name'],'model':deployment['properties']['model']['name'],'version':deployment['properties']['model']['version'],'location':account['location'],'endpoint':endpoint,'key':primary_key,'skuName':deployment['sku']['name']})
    return items
