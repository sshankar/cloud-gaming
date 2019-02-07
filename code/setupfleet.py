import os
import json
import boto3
import datetime

_env_lt_versions = 'lt_version_json'
def get_lt_spec():
  '''Parse launch template and version environment variable set during provisioning.
  Transform it to launch template spec for spot fleet request config.
  '''
  version_map = json.loads(os.getenv(_env_lt_versions, ''))
  return list(map(lambda x: dict(LaunchTemplateSpecification=dict(LaunchTemplateId=x[0], Version=x[1])), version_map.items()))

_env_valid_duration_mins = 'valid_duration_mins'
def get_valid_until():
  duration = int(os.getenv(_env_valid_duration_mins, '60'))
  return (datetime.datetime.now().replace(microsecond=0) + datetime.timedelta(minutes=duration))

_env_fleet_role = 'fleet_role_arn'
def get_fleet_role():
  return os.getenv(_env_fleet_role, '')

def handle(event, context):
  client = boto3.client('ec2')
  click_type = event['clickType']
  fleet_role = get_fleet_role()
  spot_req_id = active_request(client, fleet_role)
  
  if click_type == 'SINGLE' and not spot_req_id:
    create(client, fleet_role, '1.0', get_valid_until(), get_lt_spec())
  elif click_type == 'DOUBLE' and spot_req_id:
    cancel(client, spot_req_id)
  
  return "success"

# best case, keeping the $ low - check to see if any active spot request
# exists with the gamebox fleet role.
def active_request(client, fleet_role):
  pager = client.get_paginator('describe_spot_fleet_requests')
  pages = pager.paginate()
  for page in pages:
    for request in page['SpotFleetRequestConfigs']:
      if request['SpotFleetRequestState'] in ['submitted', 'active', 'modifying']:
        if request['SpotFleetRequestConfig']['IamFleetRole'] == fleet_role:
          return request['SpotFleetRequestId']

  return None

def create(client, fleet_role, spot_price, valid_until, lt_spec):
  return client.request_spot_fleet(
    SpotFleetRequestConfig={
      'AllocationStrategy': 'lowestPrice',
      'OnDemandAllocationStrategy': 'lowestPrice',
      'IamFleetRole': fleet_role,
      'SpotPrice': spot_price,
      'TargetCapacity': 1,
      'OnDemandTargetCapacity': 0,
      'TerminateInstancesWithExpiration': True,
      'Type': 'request',
      'ValidUntil': valid_until,
      'ReplaceUnhealthyInstances': False,
      'InstanceInterruptionBehavior': 'terminate',
      'LaunchTemplateConfigs': lt_spec
    }
  )

def cancel(client, request_id):
  return client.cancel_spot_fleet_requests(SpotFleetRequestIds=[request_id], TerminateInstances=True)