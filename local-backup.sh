# Copyright (c) 2019, UK HealthCare (https://ukhealthcare.uky.edu) All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


##########################

echo "ensure the correct environment is selected..."
KUBECONTEXT=$(kubectl config view -o template --template='{{ index . "current-context" }}')
if [ "$KUBECONTEXT" != "docker-desktop" ]; then
	echo "ERROR: Script is running in the wrong Kubernetes Environment: $KUBECONTEXT"
	exit 1
else
	echo "Verified Kubernetes context: $KUBECONTEXT"
fi

##########################

echo "create timestamp folder..."
BACKUP_FOLDER=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p ./backup/$BACKUP_FOLDER
echo "$BACKUP_FOLDER"

echo "find drupal-dev pod..."
POD=$(kubectl get pod -l app=drupal-dev -o jsonpath="{.items[0].metadata.name}")
if [ -z "$POD" ]; then 
	echo "ERROR: Could not find running pod. Exiting script."
	exit 1 
fi

echo "backup composer folder..."
mkdir -p ./backup/$BACKUP_FOLDER/composer
kubectl cp $POD:/var/www/composer ./backup/$BACKUP_FOLDER/composer

echo "backup config folder..."
mkdir -p ./backup/$BACKUP_FOLDER/docroot/config
kubectl cp $POD:/var/www/docroot/config ./backup/$BACKUP_FOLDER/docroot/config

echo "backup modules folder..."
mkdir -p ./backup/$BACKUP_FOLDER/docroot/modules
kubectl cp $POD:/var/www/docroot/modules ./backup/$BACKUP_FOLDER/docroot/modules

echo "backup themes folder..."
mkdir -p ./backup/$BACKUP_FOLDER/docroot/themes
kubectl cp $POD:/var/www/docroot/themes ./backup/$BACKUP_FOLDER/docroot/themes

echo "backup sites folder..."
mkdir -p ./backup/$BACKUP_FOLDER/docroot/sites
kubectl cp $POD:/var/www/docroot/sites ./backup/$BACKUP_FOLDER/docroot/sites

echo "backup database..."
mkdir -p ./backup/$BACKUP_FOLDER/database
POD=$(kubectl get pod -l app=mariadb -o jsonpath="{.items[0].metadata.name}")
if [ -z "$POD" ]; then 
	echo "ERROR: Could not find running pod. Exiting script."
	exit 1 
fi
kubectl exec -it $POD -- /usr/bin/mysqldump -u root -padmin drupal > ./backup/$BACKUP_FOLDER/database/drupal-dump.sql

echo "...done"