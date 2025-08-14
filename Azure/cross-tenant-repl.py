import csv
from azure.identity import DefaultAzureCredential
from azure.mgmt.subscription import SubscriptionClient
from azure.mgmt.storage import StorageManagementClient

# Authenticate
credential = DefaultAzureCredential()

# CSV output path
csv_path = r"C:\Temp\CrossTenantReplicationEnabled.csv"

# Get subscriptions
sub_client = SubscriptionClient(credential)
subscriptions = sub_client.subscriptions.list()

# Prepare CSV
results = []

# Loop through subscriptions
for sub in subscriptions:
    sub_id = sub.subscription_id
    sub_name = sub.display_name

    storage_client = StorageManagementClient(credential, sub_id)
    accounts = storage_client.storage_accounts.list()

    for account in accounts:
        # Get full account properties
        acct_props = storage_client.storage_accounts.get_properties(
            account.id.split('/')[4],  # Extract resource group from ID
            account.name
        )

        if getattr(acct_props, 'allow_cross_tenant_replication', False):
            results.append({
                "SubscriptionName": sub_name,
                "SubscriptionId": sub_id,
                "ResourceGroupName": account.id.split('/')[4],
                "StorageAccountName": account.name,
                "Location": account.location,
                "Sku": account.sku.name,
                "Kind": account.kind,
                "CrossTenantReplication": True
            })

# Write to CSV
with open(csv_path, mode='w', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)

print(f"Exported {len(results)} storage accounts with cross-tenant replication to: {csv_path}")
