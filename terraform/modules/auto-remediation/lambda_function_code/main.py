# terraform/modules/auto-remediation/lambda_function_code/main.py

import json
import os
import boto3
import time
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
            
            # Ensure perm is a dictionary before proceeding
            if not isinstance(perm, dict):
                print(f"Permission is not a dict: {type(perm)}, value: {perm}")
                continue
            
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
                    print(f"Processing ip_range: {type(ip_range)}, value: {ip_range}")
                    
                    # Handle different ip_range formats
                    cidr_ip = None
                    if isinstance(ip_range, dict):
                        cidr_ip = ip_range.get('cidrIp')
                    elif isinstance(ip_range, str):
                        # Sometimes the CIDR might be directly as a string
                        cidr_ip = ip_range
                    else:
                        print(f"Unexpected ip_range type: {type(ip_range)}, value: {ip_range}")
                        continue
                    
                    if cidr_ip == '0.0.0.0/0':
                        print(f"Found SSH 0.0.0.0/0 rule in SG {security_group_id}. Attempting to revoke...")
                        try:
                            # Try to revoke using the exact permission structure
                            revoke_permission = {
                                'IpProtocol': perm.get('ipProtocol'),
                                'FromPort': perm.get('fromPort'),
                                'ToPort': perm.get('toPort'),
                                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                            }
                            
                            # Add description if it exists
                            if isinstance(ip_range, dict) and ip_range.get('description'):
                                revoke_permission['IpRanges'][0]['Description'] = ip_range.get('description')
                            
                            print(f"Revoking with permission: {json.dumps(revoke_permission, indent=2)}")
                            
                            ec2_client.revoke_security_group_ingress(
                                GroupId=security_group_id,
                                IpPermissions=[revoke_permission]
                            )
                            revoked_rules.append(f"Revoked SSH 0.0.0.0/0 from {security_group_id}")
                            print(f"Successfully revoked SSH 0.0.0.0/0 from {security_group_id}")
                            
                        except ClientError as e:
                            if e.response['Error']['Code'] == 'InvalidPermission.NotFound':
                                print(f"Rule already removed or not found: {e}")
                            else:
                                print(f"Error revoking rule for {security_group_id}: {e}")
                                
                                # Try alternative approach using rule ID if available
                                if 'securityGroupRuleSet' in response_elements:
                                    rule_set = response_elements['securityGroupRuleSet']
                                    if isinstance(rule_set, dict) and 'items' in rule_set:
                                        for rule_item in rule_set['items']:
                                            if (isinstance(rule_item, dict) and 
                                                rule_item.get('fromPort') == 22 and 
                                                rule_item.get('toPort') == 22 and
                                                rule_item.get('cidrIpv4') == '0.0.0.0/0'):
                                                
                                                rule_id = rule_item.get('securityGroupRuleId')
                                                if rule_id:
                                                    try:
                                                        print(f"Attempting to revoke using rule ID: {rule_id}")
                                                        ec2_client.revoke_security_group_ingress(
                                                            GroupId=security_group_id,
                                                            SecurityGroupRuleIds=[rule_id]
                                                        )
                                                        revoked_rules.append(f"Revoked SSH 0.0.0.0/0 from {security_group_id} using rule ID")
                                                        print(f"Successfully revoked using rule ID: {rule_id}")
                                                        break
                                                    except ClientError as rule_e:
                                                        print(f"Error revoking with rule ID {rule_id}: {rule_e}")
                                else:
                                    print(f"Could not revoke rule: {e}")
                                    raise
                        except Exception as e:
                            print(f"Unexpected error during revocation: {e}")
                            raise
                            
            # Also check for ALL TCP or ALL protocols from 0.0.0.0/0 on port 22
            elif (perm.get('fromPort') == 22 and perm.get('toPort') == 22 and perm.get('ipProtocol') in ['tcp', '-1']):
                for ip_range in ip_ranges:
                    print(f"Processing broader rule ip_range: {type(ip_range)}, value: {ip_range}")
                    
                    # Handle different ip_range formats
                    cidr_ip = None
                    if isinstance(ip_range, dict):
                        cidr_ip = ip_range.get('cidrIp')
                    elif isinstance(ip_range, str):
                        cidr_ip = ip_range
                    else:
                        print(f"Unexpected ip_range type: {type(ip_range)}, value: {ip_range}")
                        continue
                    
                    if cidr_ip == '0.0.0.0/0':
                        print(f"Found broader rule (e.g., ALL TCP or ALL) for port 22 0.0.0.0/0 in SG {security_group_id}. Attempting to revoke...")
                        try:
                            # Try to revoke using the exact permission structure
                            revoke_permission = {
                                'IpProtocol': perm.get('ipProtocol'),
                                'FromPort': perm.get('fromPort'),
                                'ToPort': perm.get('toPort'),
                                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                            }
                            
                            # Add description if it exists
                            if isinstance(ip_range, dict) and ip_range.get('description'):
                                revoke_permission['IpRanges'][0]['Description'] = ip_range.get('description')
                            
                            ec2_client.revoke_security_group_ingress(
                                GroupId=security_group_id,
                                IpPermissions=[revoke_permission]
                            )
                            revoked_rules.append(f"Revoked broader port 22 0.0.0.0/0 rule from {security_group_id}")
                            print(f"Successfully revoked broader port 22 0.0.0.0/0 rule from {security_group_id}")
                            
                        except ClientError as e:
                            if e.response['Error']['Code'] == 'InvalidPermission.NotFound':
                                print(f"Rule already removed or not found: {e}")
                            else:
                                print(f"Error revoking broader rule for {security_group_id}: {e}")
                                raise
                        except Exception as e:
                            print(f"Unexpected error during broader rule revocation: {e}")
                            raise

        if not revoked_rules:
            print(f"No problematic SSH 0.0.0.0/0 rules found in event for SG {security_group_id}.")
        return {"status": "success", "revoked_rules": revoked_rules}
        
    except Exception as e:
        print(f"An error occurred during SSH remediation: {e}")
        return {"status": "failed", "error": str(e)}

def wait_for_instance_state(instance_id, target_state, max_wait_time=300):
    """
    Wait for an instance to reach a specific state.
    Returns True if target state is reached, False if timeout.
    """
    start_time = time.time()
    while time.time() - start_time < max_wait_time:
        try:
            response = ec2_client.describe_instances(InstanceIds=[instance_id])
            if response['Reservations']:
                current_state = response['Reservations'][0]['Instances'][0]['State']['Name']
                print(f"Instance {instance_id} current state: {current_state}")
                
                if current_state == target_state:
                    return True
                elif current_state in ['terminated', 'terminating']:
                    print(f"Instance {instance_id} is already terminated/terminating")
                    return False
                    
            time.sleep(10)  # Wait 10 seconds before checking again
            
        except ClientError as e:
            print(f"Error checking instance {instance_id} state: {e}")
            return False
            
    return False
    
def stop_and_terminate_unapproved_ami_instance(event):
    """
    Remediates EC2 instances launched with an unapproved AMI.
    First stops the instance, then terminates it.
    Triggered by CloudTrail event 'RunInstances'.
    """
    print(f"Received event for unapproved AMI remediation: {json.dumps(event, indent=2)}")

    # Define your list of approved AMI IDs
    approved_ami_ids = [os.environ.get('APPROVED_AMI_ID')]                     
    if not approved_ami_ids or approved_ami_ids == ['']:
        print("APPROVED_AMI_ID environment variable not set. Remediation cannot proceed.")
        return {"status": "failed", "message": "Approved AMI ID not configured."}
    
    try:
        detail = event['detail']
        request_parameters = detail['requestParameters']
        response_elements = detail['responseElements']

        # Extract AMI ID from the correct location
        ami_id = None
        
        # First, try direct lookup (for other API calls)
        ami_id = request_parameters.get('imageId')
        
        # If not found, check nested in instancesSet (for RunInstances API call)
        if not ami_id and 'instancesSet' in request_parameters:
            instances_set = request_parameters['instancesSet']
            if 'items' in instances_set and len(instances_set['items']) > 0:
                first_instance = instances_set['items'][0]
                ami_id = first_instance.get('imageId')
        
        if not ami_id:
            print("No AMI ID found in requestParameters. Checking available keys...")
            print(f"Available keys in requestParameters: {list(request_parameters.keys())}")
            return {"status": "skipped", "message": "No AMI ID found in event"}

        print(f"AMI ID from request: {ami_id}")
        print(f"Approved AMI IDs: {approved_ami_ids}")

        # Check if AMI is approved
        if ami_id in approved_ami_ids:
            print(f"AMI {ami_id} is approved. No action needed.")
            return {"status": "approved", "ami_id": ami_id}

        print(f"AMI {ami_id} is NOT approved. Proceeding with remediation.")

        # Get instances from response
        if 'instancesSet' not in response_elements or 'items' not in response_elements['instancesSet']:
            print("No instances found in event. Skipping.")
            return {"status": "skipped", "message": "No instances found in event"}
        
        instances = response_elements['instancesSet']['items']
        remediated_instances = []

        for instance in instances:
            # Ensure instance is a dictionary before proceeding
            if not isinstance(instance, dict):
                print(f"Instance is not a dict: {type(instance)}, value: {instance}")
                continue
                
            instance_id = instance.get('instanceId')
            if not instance_id:
                print("No instance ID found in instance data")
                continue

            print(f"Processing instance {instance_id} launched with unapproved AMI: {ami_id}")
            
            try:
                # Verify instance exists and get current state
                response = ec2_client.describe_instances(InstanceIds=[instance_id])
                
                if not response['Reservations']:
                    print(f"Instance {instance_id} not found in describe_instances response")
                    continue
                    
                current_state = response['Reservations'][0]['Instances'][0]['State']['Name']
                print(f"Instance {instance_id} current state: {current_state}")

                if current_state == 'running':
                    print(f"Stopping instance {instance_id}...")
                    ec2_client.stop_instances(InstanceIds=[instance_id])
                    
                    # Wait for instance to be stopped
                    print(f"Waiting for instance {instance_id} to stop...")
                    if wait_for_instance_state(instance_id, 'stopped', max_wait_time=300):
                        print(f"Instance {instance_id} stopped successfully. Now terminating...")
                        ec2_client.terminate_instances(InstanceIds=[instance_id])
                        remediated_instances.append(f"Stopped and terminated instance {instance_id} (AMI: {ami_id})")
                        print(f"Successfully terminated instance {instance_id} after stopping.")
                    else:
                        print(f"Instance {instance_id} did not stop within timeout. Forcing termination...")
                        ec2_client.terminate_instances(InstanceIds=[instance_id])
                        remediated_instances.append(f"Force terminated instance {instance_id} (AMI: {ami_id}) - stop timeout")
                        
                elif current_state == 'pending':
                    print(f"Instance {instance_id} is still starting up. Terminating directly...")
                    ec2_client.terminate_instances(InstanceIds=[instance_id])
                    remediated_instances.append(f"Terminated instance {instance_id} (AMI: {ami_id}) - was in pending state")
                    print(f"Successfully terminated instance {instance_id}.")
                    
                elif current_state == 'stopped':
                    print(f"Instance {instance_id} is already stopped. Terminating...")
                    ec2_client.terminate_instances(InstanceIds=[instance_id])
                    remediated_instances.append(f"Terminated already stopped instance {instance_id} (AMI: {ami_id})")
                    print(f"Successfully terminated instance {instance_id}.")
                    
                elif current_state in ['terminated', 'terminating']:
                    print(f"Instance {instance_id} is already terminated/terminating. No action needed.")
                    remediated_instances.append(f"Instance {instance_id} already terminated/terminating (AMI: {ami_id})")
                    
                else:
                    print(f"Instance {instance_id} is in unexpected state '{current_state}'. Attempting termination...")
                    ec2_client.terminate_instances(InstanceIds=[instance_id])
                    remediated_instances.append(f"Terminated instance {instance_id} from state '{current_state}' (AMI: {ami_id})")

            except ClientError as e:
                error_msg = f"Error processing instance {instance_id}: {e}"
                print(error_msg)
                remediated_instances.append(error_msg)
                # Don't raise here, continue with other instances
            except Exception as e:
                error_msg = f"Unexpected error processing instance {instance_id}: {e}"
                print(error_msg)
                remediated_instances.append(error_msg)

        return {"status": "success", "ami_id": ami_id, "remediated_instances": remediated_instances}
    
    except KeyError as e:
        error_msg = f"Missing required key in event structure: {e}"
        print(error_msg)
        return {"status": "failed", "error": error_msg}
    except Exception as e:
        error_msg = f"An error occurred during unapproved AMI remediation: {e}"
        print(error_msg)
        return {"status": "failed", "error": error_msg}

def lambda_handler(event, context):
    """
    Main Lambda handler that routes events to appropriate remediation functions
    """
    try:
        print(f"Lambda received event: {json.dumps(event, indent=2)}")
        
        # Determine the event type and route to appropriate function
        detail = event.get('detail', {})
        event_name = detail.get('eventName', '')
        
        if event_name == 'AuthorizeSecurityGroupIngress':
            return revoke_ssh_0_0_0_0_sg_rule(event)
        elif event_name == 'RunInstances':
            return stop_and_terminate_unapproved_ami_instance(event)
        else:
            print(f"Unhandled event type: {event_name}")
            return {"status": "ignored", "message": f"Event type {event_name} not handled"}
            
    except Exception as e:
        print(f"Error in lambda_handler: {e}")
        return {"status": "error", "message": str(e)}