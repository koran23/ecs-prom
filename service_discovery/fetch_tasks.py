import boto3
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

region = 'us-east-1'

try:
    boto3.Session().get_credentials().get_frozen_credentials()
except Exception as e:
    logger.error("AWS credentials are not set properly. Please check your configuration.")
    exit(1)

try:
    ecs_client = boto3.client('ecs', region_name=region)
    elb_client = boto3.client('elbv2', region_name=region)
except Exception as e:
    logger.error(f"Error initializing AWS clients: {e}")
    exit(1)

def get_clusters():
    try:
        return ecs_client.list_clusters()['clusterArns']
    except Exception as e:
        logger.error(f"Error retrieving ECS clusters: {e}")
        return []

def get_service_names(cluster_name):
    try:
        service_list = ecs_client.list_services(cluster=cluster_name)['serviceArns']
        return [service.split('/')[-1] for service in service_list]
    except Exception as e:
        logger.error(f"Error retrieving service names for cluster {cluster_name}: {e}")
        return []

def get_load_balancer_dns(service_name, cluster_name):
    try:
        services = ecs_client.describe_services(cluster=cluster_name, services=[service_name])
        if services['services'][0]['loadBalancers']:
            lb_arn = services['services'][0]['loadBalancers'][0]['targetGroupArn']
            lb_info = elb_client.describe_target_groups(TargetGroupArns=[lb_arn])
            lb_name = lb_info['TargetGroups'][0]['LoadBalancerArns'][0]
            lb_details = elb_client.describe_load_balancers(LoadBalancerArns=[lb_name])
            return lb_details['LoadBalancers'][0]['DNSName']
    except Exception as e:
        logger.warning(f"No load balancer found for service {service_name}, or error retrieving info: {e}")
    return None

def write_targets_to_file(targets):
    try:
        with open('/etc/prometheus/targets/targets.json', 'w') as f:
            json.dump(targets, f)
    except Exception as e:
        logger.error(f"Error writing to file: {e}")

def main():
    clusters = get_clusters()
    all_targets = []

    for cluster_arn in clusters:
        cluster_name = cluster_arn.split('/')[-1]
        service_names = get_service_names(cluster_name)

        for service_name in service_names:
            dns_name = get_load_balancer_dns(service_name, cluster_name)
            if dns_name:
                all_targets.append({'targets': [f'{dns_name}']})

    write_targets_to_file(all_targets)

if __name__ == "__main__":
    main()



# import boto3
# import json

# # AWS Region
#
# region = 'us-east-1'

# # Initialize ECS and ELB clients
# ecs_client = boto3.client('ecs', region_name=region)
# elb_client = boto3.client('elbv2', region_name=region)

# # ECS cluster name
# cluster_name = 'safemoon'

# # Function to get load balancer DNS names for a service
# def get_load_balancer_dns(service_name):
#     services = ecs_client.describe_services(cluster=cluster_name, services=[service_name])
#     if services['services'][0]['loadBalancers']:
#         lb_arn = services['services'][0]['loadBalancers'][0]['targetGroupArn']
#         lb_info = elb_client.describe_target_groups(TargetGroupArns=[lb_arn])
#         lb_name = lb_info['TargetGroups'][0]['LoadBalancerArns'][0]
#         lb_details = elb_client.describe_load_balancers(LoadBalancerArns=[lb_name])
#         return lb_details['LoadBalancers'][0]['DNSName']
#     return None

# # List all services in the cluster
# service_list = ecs_client.list_services(cluster=cluster_name)['serviceArns']
# service_names = [service.split('/')[-1] for service in service_list]

# # Get load balancer DNS names for all services
# targets = []
# for service_name in service_names:
#     dns_name = get_load_balancer_dns(service_name)
#     if dns_name:
#         targets.append({'targets': [f'{dns_name}']})

# # Write to file
# with open('/etc/prometheus/targets/targets.json', 'w') as f:
#     json.dump(targets, f)

# docker exec -it [prometheus_container_id] cat /etc/prometheus/targets/targets.json
