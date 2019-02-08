import requests
import os

interested_events = [
  "EC2 Spot Instance Interruption Warning"
  "EC2 Instance State-change Notification"
]

_key_webhook_url = 'webhook_url'
def _get_webhook_url():
  return os.getenv(_key_webhook_url, '')

def _execute_webhook(url, value1, value2, value3):
  response = requests.post(url, json={'value1': value1, 'value2': value2, 'value3': value3})
  response.raise_for_status()
  return response.text

def handle(event, context):
  if 'detail-type' in event and event['detail-type'] in interested_events:
    value1 = event['detail-type']
    value2 = event['detail']['instance-id']
    value3 = event['detail']['instance-action'] if 'instance-action' in event['detail'] else event['detail']['state']

    return _execute_webhook(_get_webhook_url(), value1, value2, value3)

  return "success"
