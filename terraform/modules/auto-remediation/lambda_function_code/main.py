import json
import os
import boto3
from botocore.exceptions import ClientError

ec2_client = boto3.client('ec2')
s3_client = boto3.client('s3') # For potential future S3 remediation
iam_client = boto3.client('iam') # For potential future IAM key remediation

def revoke_ssh_0_0_0_0_sg_rule(event):
    """
    Remediates Security Group ingress rules allowing SSH from 0.0.0.0/0.
    Triggered by CloudTrail event 'AuthorizeSecurityGroupIngress'.
    """
    print(f"Received event for SSH remediation: {json.dumps(event, indent=2)}")

    try:
        detail = event['detail']
        request_parameters = detail['requestParameters']
        response_elements = detail['responseElements']

        if 'securityGroupId' not in request_parameters and 'groupId' not in request_parameters:
            print("No security group ID found in event. Skipping.")
            return
        
        security_group_id = request_parameters.get('securityGroupId') or request_parameters.get('groupId')

        # Handle ipPermissions structure - it can be a dict with 'items' or a list
        ip_permissions_raw = request_parameters.get('ipPermissions', [])
        if isinstance(ip_permissions_raw, dict):
            ip_permissions = ip_permissions_raw.get('items', [])
        else:
            ip_permissions = ip_permissions_raw
            
        if not ip_permissions:
            print("No IP permissions found in event. Skipping.")
            return
        
        revoked_rules = []

        for perm in ip_permissions:
            # Debug: Print the permission structure
            print(f"Processing permission: {json.dumps(perm, indent=2)}")
            
            # Get IP ranges - handle different possible structures
            ip_ranges = []
            ip_ranges_raw = perm.get("ipRanges", [])
            
            print(f"ip_ranges_raw type: {type(ip_ranges_raw)}, value: {ip_ranges_raw}")
            
            if isinstance(ip_ranges_raw, dict):
                # Handle case where ipRanges is a dict with 'items' key (CloudTrail format)
                items = ip_ranges_raw.get("items", [])
                if isinstance(items, list):
                    ip_ranges = items
                elif isinstance(items, dict):
                    ip_ranges = [items]
                else:
                    print(f"Unexpected items type: {type(items)}, value: {items}")
                    ip_ranges = []
            elif isinstance(ip_ranges_raw, list):
                ip_ranges = ip_ranges_raw
            else:
                print(f"Unexpected ip_ranges_raw type: {type(ip_ranges_raw)}")
                ip_ranges = []
                
            print(f"Final ip_ranges: {ip_ranges}")
                
            # Check for SSH (port 22) and 0.0.0.0/0 CIDR
            if perm.get('fromPort') == 22 and perm.get('toPort') == 22 and perm.get('ipProtocol') == 'tcp':
                for ip_range in ip_ranges:
                    # Ensure ip_range is a dict before calling .get()
                    if isinstance(ip_range, dict) and ip_range.get('cidrIp') == '0.0.0.0/0':
                        print(f"Found SSH 0.0.0.0/0 rule in SG {security_group_id}. Attempting to revoke...")
                        try:
                            ec2_client.revoke_security_group_ingress(
                                GroupId=security_group_id,
                                IpPermissions=[perm] # Revoke the exact permission
                            )
                            revoked_rules.append(f"Revoked SSH 0.0.0.0/0 from {security_group_id}")
                            print(f"Successfully revoked SSH 0.0.0.0/0 from {security_group_id}")
                        except ClientError as e:
                            if e.response['Error']['Code'] == 'InvalidPermission.NotFound':
                                print(f"Rule already removed or not found: {e}")
                            else:
                                print(f"Error revoking rule for {security_group_id}: {e}")
                                raise
                    elif not isinstance(ip_range, dict):
                        print(f"ip_range is not a dict: {type(ip_range)}, value: {ip_range}")
                        
            # Also check for ALL TCP or ALL protocols from 0.0.0.0/0 on port 22
            elif (perm.get('fromPort') == 22 and perm.get('toPort') == 22 and perm.get('ipProtocol') in ['tcp', '-1']):
                for ip_range in ip_ranges:
                    # Ensure ip_range is a dict before calling .get()
                    if isinstance(ip_range, dict) and ip_range.get('cidrIp') == '0.0.0.0/0':
                        print(f"Found broader rule (e.g., ALL TCP or ALL) for port 22 0.0.0.0/0 in SG {security_group_id}. Attempting to revoke...")
                        try:
                            ec2_client.revoke_security_group_ingress(
                                GroupId=security_group_id,
                                IpPermissions=[perm]
                            )
                            revoked_rules.append(f"Revoked broader port 22 0.0.0.0/0 rule from {security_group_id}")
                            print(f"Successfully revoked broader port 22 0.0.0.0/0 rule from  {security_group_id}")
                        except ClientError as e:
                            if e.response['Error']['Code'] == 'InvalidPermission.NotFound':
                                print(f"Rule already removed or not found: {e}")
                            else:
                                print(f"Error revoking broader rule for {security_group_id}: {e}")
                                raise
                    elif not isinstance(ip_range, dict):
                        print(f"ip_range is not a dict: {type(ip_range)}, value: {ip_range}")

        if not revoked_rules:
            print(f"No problematic SSH 0.0.0.0/0 rules found in event for SG {security_group_id}.")
        return {"status": "success", "revoked_rules": revoked_rules}
        
    except Exception as e:
        print(f"An error occurred during SSH remediation: {e}")
        return {"status": "failed", "error": str(e)}
    
def stop_unapproved_ami_instance(event):
    """"
    Remediates EC2 instances launched with an unapproved AMI.
    Triggered by CloudTrail event 'RunInstances'.
    """
    print(f"Received event for unapproved AMI remediation: {json.dumps(event, indent=2)}")

    # Define your list of approved AMI IDs (replace with your actual approved AMIs)
    # In a real scenario, this would come from a configuration source (SSM Parameter Store, DynamoDB, etc.)
    # For this example, we'll use the specific ECS Optimized AMI used in the Terraform as the "approved" one
    # and assume any other AMI is unapproved.
    approved_ami_ids = [os.environ.get('APPROVED_AMI_ID')]                     
    if not approved_ami_ids or approved_ami_ids == ['']:
        print("APPROVED_AMI_ID environment variable not set. Remediation cannot proceed.")
        return {"status": "failed", "message": "Approved AMI ID not configured."}
    
    try:
        detail = event['detail']
        request_parameters = detail['requestParameters']
        response_elements = detail['responseElements']

        if 'instancesSet' not in response_elements or 'items' not in response_elements['instancesSet']:
            print("No instances found in event. Skipping.")
            return
        
        instances = response_elements['instancesSet']['items']
        remediated_instances = []

        for instance in instances:
            instance_id = instance.get('instanceId')
            ami_id = instance.get('ImageId')

            if ami_id and ami_id not in approved_ami_ids:
                print(f"Instance {instance_id} launched with unapproved AMI: {ami_id}. Stopping instance.")
                try:
                    # Verify instance is still running before stopping
                    response = ec2_client.describe_instances(InstanceIds=[instance_id])
                    current_state = response['Reservations'][0]['Instances'][0]['State']['Name']

                    if current_state == 'running':
                        ec2_client.stop_instances(InstanceIds=[instance_id])
                        remediated_instances.append(f"Stopped instance {instance_id} (AMI: {ami_id})")
                        print(f"Successfully stopped instance {instance_id}.")
                    else:
                        print(f"Instance {instance_id} is already in state '{current_state}'. Not stopping.")

                except ClientError as e:
                    print(f"Error stopping instances {instance_id}: {e}")
                    raise
            else:
                print(f"Instance {instance_id} launched with approved AMI: {ami_id}. No action needed.")

        return {"status": "success", "remediated_instances": remediated_instances}
    
    except Exception as e:
        print(f"An error occurred during unapproved AMI remediation: {e}")
        return {"status": "failed", "error": str(e)}