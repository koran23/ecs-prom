import boto3
import json

# AWS Region
region = 'us-east-1'

# Initialize ECS and ELB clients
ecs_client = boto3.client('ecs', region_name=region)
elb_client = boto3.client('elbv2', region_name=region)

# ECS cluster name
cluster_name = 'safemoon'

# Function to get load balancer DNS names for a service
def get_load_balancer_dns(service_name):
    services = ecs_client.describe_services(cluster=cluster_name, services=[service_name])
    if services['services'][0]['loadBalancers']:
        lb_arn = services['services'][0]['loadBalancers'][0]['targetGroupArn']
        lb_info = elb_client.describe_target_groups(TargetGroupArns=[lb_arn])
        lb_name = lb_info['TargetGroups'][0]['LoadBalancerArns'][0]
        lb_details = elb_client.describe_load_balancers(LoadBalancerArns=[lb_name])
        return lb_details['LoadBalancers'][0]['DNSName']
    return None

# List all services in the cluster
service_list = ecs_client.list_services(cluster=cluster_name)['serviceArns']
service_names = [service.split('/')[-1] for service in service_list]

# Get load balancer DNS names for all services
targets = []
for service_name in service_names:
    dns_name = get_load_balancer_dns(service_name)
    if dns_name:
        targets.append({'targets': [f'{dns_name}']})

# Write to file
with open('/etc/prometheus/targets/targets.json', 'w') as f:
    json.dump(targets, f)

# docker exec -it [prometheus_container_id] cat /etc/prometheus/targets/targets.json

# import boto3
# import json

# add region

# client = boto3.client('ecs', region_name=region)

# cluster_name = 'safemoon'

# tasks = client.list_tasks(cluster=cluster_name)

# targets = []
# for task_arn in tasks['taskArns']:
#     task_detail = client.describe_tasks(cluster=cluster_name, tasks=[task_arn])['tasks'][0]
#     container = task_detail['containers'][0]
#     ip_address = container['networkInterfaces'][0]['privateIpv4Address']
#     port = 3000 
#     targets.append({'targets': [f'{ip_address}:{port}']})

# with open('/etc/prometheus/targets/targets.json', 'w') as f:
#     json.dump(targets, f)
