#!/usr/bin/env python3
"""
Emergency cleanup script for AWS resources created by XTTS API Server deployment
Use this to clean up all AWS resources when needed
"""

import os
import sys
import json
import boto3
import logging
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Optional

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('emergency_cleanup.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class XTTSEmergencyCleanup:
    """Emergency cleanup for XTTS API Server AWS resources"""

    def __init__(self, region: str = "us-west-2"):
        self.region = region
        self.ec2_client = boto3.client('ec2', region_name=region)
        self.ecr_client = boto3.client('ecr', region_name=region)

        # XTTS-specific identifiers
        self.project_tags = ['xtts-api', 'XTTS-API-Server']
        self.resource_prefixes = ['xtts-api', 'XTTS-API', 'sg-xtts-api']
        self.instance_names = ['XTTS-API-Server']
        self.elastic_ip_allocation_id = "eipalloc-053fa187bd3ca7c89"

        logger.info(f"🧹 XTTS Emergency cleanup initialized for region: {region}")

    def find_project_instances(self) -> List[Dict]:
        """Find EC2 instances related to XTTS API Server"""
        logger.info("🔍 Searching for XTTS API Server instances...")

        instances = []
        try:
            # Search by project tags
            for tag_value in self.project_tags:
                response = self.ec2_client.describe_instances(
                    Filters=[
                        {'Name': 'tag:Project', 'Values': [tag_value]},
                        {'Name': 'instance-state-name', 'Values': ['running', 'pending', 'stopping', 'stopped']}
                    ]
                )

                for reservation in response['Reservations']:
                    for instance in reservation['Instances']:
                        if not any(i['InstanceId'] == instance['InstanceId'] for i in instances):
                            instances.append({
                                'InstanceId': instance['InstanceId'],
                                'State': instance['State']['Name'],
                                'LaunchTime': instance['LaunchTime'],
                                'Tags': instance.get('Tags', []),
                                'InstanceType': instance['InstanceType']
                            })

            # Search by instance name
            for name in self.instance_names:
                response = self.ec2_client.describe_instances(
                    Filters=[
                        {'Name': 'tag:Name', 'Values': [name]},
                        {'Name': 'instance-state-name', 'Values': ['running', 'pending', 'stopping', 'stopped']}
                    ]
                )

                for reservation in response['Reservations']:
                    for instance in reservation['Instances']:
                        if not any(i['InstanceId'] == instance['InstanceId'] for i in instances):
                            instances.append({
                                'InstanceId': instance['InstanceId'],
                                'State': instance['State']['Name'],
                                'LaunchTime': instance['LaunchTime'],
                                'Tags': instance.get('Tags', []),
                                'InstanceType': instance['InstanceType']
                            })

            # Search by environment tags (main, development)
            for env in ['main', 'development', 'production']:
                response = self.ec2_client.describe_instances(
                    Filters=[
                        {'Name': 'tag:Environment', 'Values': [env]},
                        {'Name': 'tag:Name', 'Values': ['XTTS-API-Server']},
                        {'Name': 'instance-state-name', 'Values': ['running', 'pending', 'stopping', 'stopped']}
                    ]
                )

                for reservation in response['Reservations']:
                    for instance in reservation['Instances']:
                        if not any(i['InstanceId'] == instance['InstanceId'] for i in instances):
                            instances.append({
                                'InstanceId': instance['InstanceId'],
                                'State': instance['State']['Name'],
                                'LaunchTime': instance['LaunchTime'],
                                'Tags': instance.get('Tags', []),
                                'InstanceType': instance['InstanceType']
                            })

            logger.info(f"📊 Found {len(instances)} XTTS instances")
            return instances

        except Exception as e:
            logger.error(f"❌ Error finding instances: {e}")
            return []

    def find_project_security_groups(self) -> List[Dict]:
        """Find security groups related to XTTS API Server"""
        logger.info("🔍 Searching for XTTS security groups...")

        security_groups = []
        try:
            response = self.ec2_client.describe_security_groups()

            for sg in response['SecurityGroups']:
                is_project_sg = False

                # Check by tags
                for tag in sg.get('Tags', []):
                    if tag['Key'] == 'Project' and tag['Value'] in self.project_tags:
                        is_project_sg = True
                        break

                # Check by name pattern
                for prefix in self.resource_prefixes:
                    if sg['GroupName'].startswith(prefix):
                        is_project_sg = True
                        break

                # Check specific XTTS patterns
                if any(pattern in sg['GroupName'].lower() for pattern in ['xtts', 'tts-api']):
                    is_project_sg = True

                # Check description
                if 'xtts' in sg['Description'].lower() or 'tts api' in sg['Description'].lower():
                    is_project_sg = True

                if is_project_sg and sg['GroupName'] != 'default':
                    security_groups.append({
                        'GroupId': sg['GroupId'],
                        'GroupName': sg['GroupName'],
                        'Description': sg['Description'],
                        'Tags': sg.get('Tags', [])
                    })

            logger.info(f"📊 Found {len(security_groups)} XTTS security groups")
            return security_groups

        except Exception as e:
            logger.error(f"❌ Error finding security groups: {e}")
            return []

    def find_spot_requests(self) -> List[Dict]:
        """Find active spot instance requests for XTTS"""
        logger.info("🔍 Searching for XTTS spot instance requests...")

        spot_requests = []
        try:
            response = self.ec2_client.describe_spot_instance_requests(
                Filters=[
                    {'Name': 'state', 'Values': ['open', 'active']}
                ]
            )

            for request in response['SpotInstanceRequests']:
                is_project_request = False

                # Check tags
                if 'Tags' in request:
                    for tag in request['Tags']:
                        if (tag['Key'] == 'Project' and tag['Value'] in self.project_tags) or \
                           (tag['Key'] == 'Name' and tag['Value'] in self.instance_names):
                            is_project_request = True
                            break

                # Check launch specification security groups
                if 'LaunchSpecification' in request and 'SecurityGroups' in request['LaunchSpecification']:
                    for sg in request['LaunchSpecification']['SecurityGroups']:
                        sg_name = sg.get('GroupName', '')
                        if any(prefix in sg_name for prefix in self.resource_prefixes):
                            is_project_request = True
                            break

                if is_project_request:
                    spot_requests.append({
                        'SpotInstanceRequestId': request['SpotInstanceRequestId'],
                        'State': request['State'],
                        'InstanceId': request.get('InstanceId'),
                        'Tags': request.get('Tags', [])
                    })

            logger.info(f"📊 Found {len(spot_requests)} XTTS spot requests")
            return spot_requests

        except Exception as e:
            logger.error(f"❌ Error finding spot requests: {e}")
            return []

    def find_project_volumes(self) -> List[Dict]:
        """Find EBS volumes related to XTTS API Server"""
        logger.info("🔍 Searching for XTTS EBS volumes...")

        volumes = []
        try:
            # Search by project tags
            for tag_value in self.project_tags:
                response = self.ec2_client.describe_volumes(
                    Filters=[
                        {'Name': 'tag:Project', 'Values': [tag_value]},
                        {'Name': 'status', 'Values': ['available', 'in-use']}
                    ]
                )

                for volume in response['Volumes']:
                    if not any(v['VolumeId'] == volume['VolumeId'] for v in volumes):
                        volumes.append({
                            'VolumeId': volume['VolumeId'],
                            'State': volume['State'],
                            'Size': volume['Size'],
                            'VolumeType': volume['VolumeType'],
                            'Tags': volume.get('Tags', []),
                            'Attachments': volume.get('Attachments', [])
                        })

            # Search by name patterns
            for name in self.instance_names:
                response = self.ec2_client.describe_volumes(
                    Filters=[
                        {'Name': 'tag:Name', 'Values': [f'{name}*']},
                        {'Name': 'status', 'Values': ['available', 'in-use']}
                    ]
                )

                for volume in response['Volumes']:
                    if not any(v['VolumeId'] == volume['VolumeId'] for v in volumes):
                        volumes.append({
                            'VolumeId': volume['VolumeId'],
                            'State': volume['State'],
                            'Size': volume['Size'],
                            'VolumeType': volume['VolumeType'],
                            'Tags': volume.get('Tags', []),
                            'Attachments': volume.get('Attachments', [])
                        })

            logger.info(f"📊 Found {len(volumes)} XTTS volumes")
            return volumes

        except Exception as e:
            logger.error(f"❌ Error finding volumes: {e}")
            return []

    def check_elastic_ip_association(self) -> Optional[Dict]:
        """Check if elastic IP is associated with XTTS instances"""
        logger.info("🔍 Checking elastic IP association...")

        try:
            response = self.ec2_client.describe_addresses(
                AllocationIds=[self.elastic_ip_allocation_id]
            )

            if response['Addresses']:
                address = response['Addresses'][0]
                return {
                    'AllocationId': address['AllocationId'],
                    'PublicIp': address['PublicIp'],
                    'InstanceId': address.get('InstanceId'),
                    'AssociationId': address.get('AssociationId'),
                    'Associated': 'InstanceId' in address
                }

        except Exception as e:
            logger.error(f"❌ Error checking elastic IP: {e}")

        return None

    def find_docker_images(self) -> List[Dict]:
        """Find Docker images in ECR (if using ECR and permissions allow)"""
        logger.info("🔍 Searching for XTTS Docker images in ECR...")

        images = []
        try:
            # Check if ECR repositories exist
            response = self.ecr_client.describe_repositories()

            for repo in response['repositories']:
                if 'xtts' in repo['repositoryName'].lower():
                    # Get images in this repository
                    try:
                        images_response = self.ecr_client.describe_images(
                            repositoryName=repo['repositoryName']
                        )

                        for image in images_response['imageDetails']:
                            images.append({
                                'repositoryName': repo['repositoryName'],
                                'imageDigest': image['imageDigest'],
                                'imageTags': image.get('imageTags', []),
                                'imageSizeInBytes': image.get('imageSizeInBytes', 0),
                                'imagePushedAt': image.get('imagePushedAt')
                            })
                    except Exception as e:
                        logger.warning(f"Could not list images in {repo['repositoryName']}: {e}")

            logger.info(f"📊 Found {len(images)} XTTS Docker images")
            return images

        except Exception as e:
            if "AccessDeniedException" in str(e):
                logger.info("ℹ️  No ECR permissions - skipping Docker image search (this is normal)")
            else:
                logger.error(f"❌ Error finding Docker images: {e}")
            return []

    def terminate_instances(self, instances: List[Dict], force: bool = False) -> bool:
        """Terminate XTTS EC2 instances"""
        if not instances:
            logger.info("✅ No XTTS instances to terminate")
            return True

        logger.info(f"🔄 Terminating {len(instances)} XTTS instances...")

        try:
            instance_ids = [i['InstanceId'] for i in instances]

            if not force:
                print("\n" + "="*70)
                print("XTTS INSTANCES TO TERMINATE:")
                print("="*70)
                for instance in instances:
                    tags = {tag['Key']: tag['Value'] for tag in instance['Tags']}
                    name = tags.get('Name', 'Unknown')
                    env = tags.get('Environment', 'Unknown')
                    print(f"  {instance['InstanceId']} - {name} [{env}] ({instance['State']}, {instance['InstanceType']})")

                confirm = input("\nAre you sure you want to terminate these XTTS instances? (yes/no): ")
                if confirm.lower() != 'yes':
                    logger.info("❌ Instance termination cancelled by user")
                    return False

            # Terminate instances
            self.ec2_client.terminate_instances(InstanceIds=instance_ids)
            logger.info(f"✅ Terminated {len(instance_ids)} XTTS instances")
            return True

        except Exception as e:
            logger.error(f"❌ Error terminating instances: {e}")
            return False

    def cancel_spot_requests(self, spot_requests: List[Dict]) -> bool:
        """Cancel XTTS spot instance requests"""
        if not spot_requests:
            logger.info("✅ No XTTS spot requests to cancel")
            return True

        logger.info(f"🔄 Cancelling {len(spot_requests)} XTTS spot requests...")

        try:
            request_ids = [r['SpotInstanceRequestId'] for r in spot_requests]
            self.ec2_client.cancel_spot_instance_requests(SpotInstanceRequestIds=request_ids)
            logger.info(f"✅ Cancelled {len(request_ids)} XTTS spot requests")
            return True

        except Exception as e:
            logger.error(f"❌ Error cancelling spot requests: {e}")
            return False

    def disassociate_elastic_ip(self, elastic_ip_info: Dict) -> bool:
        """Disassociate elastic IP from XTTS instances"""
        if not elastic_ip_info or not elastic_ip_info['Associated']:
            logger.info("✅ Elastic IP not associated or doesn't exist")
            return True

        logger.info(f"🔄 Disassociating elastic IP {elastic_ip_info['PublicIp']}...")

        try:
            if elastic_ip_info.get('AssociationId'):
                self.ec2_client.disassociate_address(
                    AssociationId=elastic_ip_info['AssociationId']
                )
                logger.info(f"✅ Disassociated elastic IP from instance {elastic_ip_info.get('InstanceId')}")
            return True

        except Exception as e:
            logger.error(f"❌ Error disassociating elastic IP: {e}")
            return False

    def delete_security_groups(self, security_groups: List[Dict], force: bool = False) -> bool:
        """Delete XTTS security groups"""
        if not security_groups:
            logger.info("✅ No XTTS security groups to delete")
            return True

        logger.info(f"🔄 Deleting {len(security_groups)} XTTS security groups...")

        try:
            if not force:
                print("\n" + "="*70)
                print("XTTS SECURITY GROUPS TO DELETE:")
                print("="*70)
                for sg in security_groups:
                    print(f"  {sg['GroupId']} - {sg['GroupName']} ({sg['Description']})")

                confirm = input("\nAre you sure you want to delete these XTTS security groups? (yes/no): ")
                if confirm.lower() != 'yes':
                    logger.info("❌ Security group deletion cancelled by user")
                    return False

            # Delete security groups
            for sg in security_groups:
                try:
                    self.ec2_client.delete_security_group(GroupId=sg['GroupId'])
                    logger.info(f"✅ Deleted security group: {sg['GroupName']}")
                except Exception as e:
                    logger.error(f"⚠️  Failed to delete {sg['GroupName']}: {e}")

            return True

        except Exception as e:
            logger.error(f"❌ Error deleting security groups: {e}")
            return False

    def delete_volumes(self, volumes: List[Dict], force: bool = False) -> bool:
        """Delete XTTS EBS volumes"""
        if not volumes:
            logger.info("✅ No XTTS volumes to delete")
            return True

        logger.info(f"🔄 Deleting {len(volumes)} XTTS EBS volumes...")

        try:
            if not force:
                print("\n" + "="*70)
                print("XTTS EBS VOLUMES TO DELETE:")
                print("="*70)
                total_size = sum(v['Size'] for v in volumes)
                for volume in volumes:
                    tags = {tag['Key']: tag['Value'] for tag in volume['Tags']}
                    name = tags.get('Name', 'Unknown')
                    attached_to = 'Unattached'
                    if volume['Attachments']:
                        attached_to = f"Attached to {volume['Attachments'][0]['InstanceId']}"
                    print(f"  {volume['VolumeId']} - {name} ({volume['Size']}GB {volume['VolumeType']}, {volume['State']}, {attached_to})")

                print(f"\nTotal storage: {total_size}GB")
                confirm = input("\nAre you sure you want to delete these XTTS volumes? (yes/no): ")
                if confirm.lower() != 'yes':
                    logger.info("❌ Volume deletion cancelled by user")
                    return False

            # Delete volumes
            for volume in volumes:
                try:
                    volume_id = volume['VolumeId']

                    # If volume is attached, detach it first
                    if volume['Attachments']:
                        logger.info(f"🔌 Detaching volume {volume_id}...")
                        for attachment in volume['Attachments']:
                            self.ec2_client.detach_volume(
                                VolumeId=volume_id,
                                InstanceId=attachment['InstanceId'],
                                Force=True
                            )

                        # Wait for volume to be available
                        logger.info(f"⏳ Waiting for volume {volume_id} to become available...")
                        waiter = self.ec2_client.get_waiter('volume_available')
                        waiter.wait(VolumeIds=[volume_id])

                    # Delete the volume
                    self.ec2_client.delete_volume(VolumeId=volume_id)
                    logger.info(f"✅ Deleted volume: {volume_id}")

                except Exception as e:
                    logger.error(f"⚠️  Failed to delete volume {volume['VolumeId']}: {e}")

            return True

        except Exception as e:
            logger.error(f"❌ Error deleting volumes: {e}")
            return False

    def cleanup_docker_images(self, images: List[Dict], force: bool = False) -> bool:
        """Clean up XTTS Docker images from ECR"""
        if not images:
            logger.info("✅ No XTTS Docker images to clean up")
            return True

        logger.info(f"🔄 Cleaning up {len(images)} XTTS Docker images...")

        # Group images by repository
        repos = {}
        for image in images:
            repo_name = image['repositoryName']
            if repo_name not in repos:
                repos[repo_name] = []
            repos[repo_name].append(image)

        try:
            if not force:
                print("\n" + "="*70)
                print("XTTS DOCKER IMAGES TO DELETE:")
                print("="*70)
                total_size = sum(img.get('imageSizeInBytes', 0) for img in images)
                for repo_name, repo_images in repos.items():
                    print(f"\nRepository: {repo_name}")
                    for img in repo_images:
                        tags = ', '.join(img.get('imageTags', ['<untagged>']))
                        size_mb = img.get('imageSizeInBytes', 0) / (1024 * 1024)
                        print(f"  - {tags} ({size_mb:.1f}MB)")

                print(f"\nTotal size: {total_size / (1024 * 1024):.1f}MB")
                confirm = input("\nAre you sure you want to delete these XTTS Docker images? (yes/no): ")
                if confirm.lower() != 'yes':
                    logger.info("❌ Docker image cleanup cancelled by user")
                    return False

            # Delete images
            for repo_name, repo_images in repos.items():
                try:
                    image_ids = [{'imageDigest': img['imageDigest']} for img in repo_images]
                    self.ecr_client.batch_delete_image(
                        repositoryName=repo_name,
                        imageIds=image_ids
                    )
                    logger.info(f"✅ Deleted {len(image_ids)} images from {repo_name}")
                except Exception as e:
                    logger.error(f"⚠️  Failed to delete images from {repo_name}: {e}")

            return True

        except Exception as e:
            logger.error(f"❌ Error cleaning up Docker images: {e}")
            return False

    def run_full_cleanup(self, force: bool = False) -> Dict[str, bool]:
        """Run complete XTTS cleanup"""
        logger.info("🧹 Starting XTTS emergency cleanup...")

        results = {
            'spot_requests': False,
            'instances': False,
            'elastic_ip': False,
            'volumes': False,
            'security_groups': False,
            'docker_images': False
        }

        try:
            # Find all resources
            instances = self.find_project_instances()
            spot_requests = self.find_spot_requests()
            volumes = self.find_project_volumes()
            security_groups = self.find_project_security_groups()
            elastic_ip_info = self.check_elastic_ip_association()
            docker_images = self.find_docker_images()

            # Show summary
            total_resources = (len(instances) + len(spot_requests) + len(volumes) +
                             len(security_groups) + len(docker_images) +
                             (1 if elastic_ip_info and elastic_ip_info['Associated'] else 0))

            if total_resources == 0:
                logger.info("🎉 No XTTS resources found to clean up!")
                return results

            print(f"\n{'='*70}")
            print("XTTS CLEANUP SUMMARY")
            print(f"{'='*70}")
            print(f"EC2 Instances: {len(instances)}")
            print(f"Spot Requests: {len(spot_requests)}")
            print(f"EBS Volumes: {len(volumes)}")
            print(f"Security Groups: {len(security_groups)}")
            print(f"Docker Images: {len(docker_images)}")
            print(f"Elastic IP Associated: {'Yes' if elastic_ip_info and elastic_ip_info['Associated'] else 'No'}")
            if elastic_ip_info:
                print(f"Elastic IP Address: {elastic_ip_info['PublicIp']}")
            print(f"{'='*70}")

            if not force:
                confirm = input(f"\nProceed with cleanup of {total_resources} XTTS resources? (yes/no): ")
                if confirm.lower() != 'yes':
                    logger.info("❌ XTTS cleanup cancelled by user")
                    return results

            # Perform cleanup in order
            results['spot_requests'] = self.cancel_spot_requests(spot_requests)
            results['elastic_ip'] = self.disassociate_elastic_ip(elastic_ip_info)
            results['instances'] = self.terminate_instances(instances, force=True)

            # Wait for instances to terminate
            if instances:
                logger.info("⏳ Waiting for instances to terminate...")
                import time
                time.sleep(30)

            # Clean up remaining resources
            results['volumes'] = self.delete_volumes(volumes, force=True)
            results['security_groups'] = self.delete_security_groups(security_groups, force=True)
            results['docker_images'] = self.cleanup_docker_images(docker_images, force=True)

            # Summary
            successful_cleanups = sum(results.values())
            logger.info(f"🎯 XTTS cleanup completed: {successful_cleanups}/{len(results)} categories successful")

            return results

        except Exception as e:
            logger.error(f"❌ XTTS cleanup failed: {e}")
            return results

def main():
    """Main cleanup function"""
    import argparse

    parser = argparse.ArgumentParser(description="Emergency cleanup for XTTS API Server AWS resources")
    parser.add_argument("--region", type=str, default="us-west-2", help="AWS region")
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompts")
    parser.add_argument("--list-only", action="store_true", help="Only list resources, don't delete")

    args = parser.parse_args()

    try:
        cleanup = XTTSEmergencyCleanup(args.region)

        if args.list_only:
            logger.info("📋 LISTING XTTS RESOURCES ONLY (no deletion)")
            cleanup.find_project_instances()
            cleanup.find_spot_requests()
            cleanup.find_project_security_groups()
            cleanup.find_project_volumes()
            cleanup.check_elastic_ip_association()
            cleanup.find_docker_images()
        else:
            results = cleanup.run_full_cleanup(force=args.force)

            # Final summary
            print(f"\n{'='*70}")
            print("🎯 FINAL XTTS CLEANUP SUMMARY")
            print(f"{'='*70}")
            for category, success in results.items():
                status = "✅ SUCCESS" if success else "❌ FAILED"
                print(f"{category.replace('_', ' ').title()}: {status}")
            print(f"{'='*70}")

            if all(results.values()):
                print("🎉 ALL XTTS CLEANUP OPERATIONS SUCCESSFUL!")
                print(f"💰 Estimated monthly cost savings: ~$400-800 (depending on usage)")
            else:
                print("⚠️  Some XTTS cleanup operations failed. Check logs for details.")

    except Exception as e:
        logger.error(f"❌ XTTS emergency cleanup failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()