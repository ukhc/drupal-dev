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
# validate positional parameters

if [ "$1" == "" ] || [ "$2" == "" ]
then
	echo "USEAGE: ./local-restore.sh [BACKUP_FOLDER_NAME] [--restore-all --restore-database --restore-files]"
	echo "e.g. ./local-restore.sh local_2019-10-31_20-05-55 --restore-all"
	exit 1
fi

BACKUP_FOLDER="$1"
if [ -d "./backup/$BACKUP_FOLDER" ] 
then
    # ./backup/$BACKUP_FOLDER exists
    echo "Restoring from $BACKUP_FOLDER..."
else
    echo "ERROR: Directory ./backup/$BACKUP_FOLDER does not exist"
	exit 1
fi

if [ "$2" == "--restore-all" ] || [ "$2" == "--restore-database " ] || [ "$2" == "--restore-files" ]
then
	RESTORE_MODE="$2"
else
    echo "ERROR: Restore mode is not valid.  Must be one of the following --restore-all --restore-database --restore-files"
	exit 1
fi

##########################

echo
echo "*** WARNING: This script will restore the the data in the persistent volumes and database ***"
echo "*** WARNING: You will lose any changes you have made in the current deployment ***"
echo
read -n 1 -s -r -p "Press any key to continue or CTRL-C to exit..."

echo

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

if [ "$RESTORE_MODE" == "--restore-files" ] || [ "$RESTORE_MODE" == "--restore-all" ]
then
	echo "find drupal-dev pod..."
	POD=$(kubectl get pod -l app=drupal-dev -o jsonpath="{.items[0].metadata.name}")
	if [ -z "$POD" ]; then 
		echo "ERROR: Could not find running pod. Exiting script."
		exit 1 
	fi

	echo "restore composer..."
	kubectl exec $POD -- bash -c "rm -rf /var/www/composer/*"
	kubectl cp ./backup/$BACKUP_FOLDER/composer $POD:/var/www

	echo "restore config..."
	kubectl exec $POD -- bash -c "rm -rf /var/www/docroot/config/*"
	kubectl cp ./backup/$BACKUP_FOLDER/docroot/config $POD:/var/www/docroot
	echo "set permissions..."
	kubectl exec $POD -- bash -c "chown -R www-data:www-data /var/www/docroot/config/*"

	echo "restore modules..."
	kubectl exec $POD -- bash -c "rm -rf /var/www/docroot/modules/*"
	kubectl cp ./backup/$BACKUP_FOLDER/modules $POD:/var/www/docroot
	echo "set permissions..."
	kubectl exec $POD -- bash -c "chown -R www-data:www-data /var/www/docroot/modules/custom/*"

	echo "restore themes..."
	kubectl exec $POD -- bash -c "rm -rf /var/www/docroot/themes/*"
	kubectl cp ./backup/$BACKUP_FOLDER/themes $POD:/var/www/docroot
	echo "set permissions..."
	kubectl exec $POD -- bash -c "chown -R www-data:www-data /var/www/docroot/themes/custom/*"

	echo "restore sites..."
	kubectl exec $POD -- bash -c "rm -rf /var/www/docroot/sites/*"
	kubectl cp ./backup/$BACKUP_FOLDER/sites $POD:/var/www/docroot
	echo "set permissions..."
	kubectl exec $POD -- bash -c "chown -R www-data:www-data /var/www/docroot/sites/default/*"
	
fi

if [ "$RESTORE_MODE" == "--restore-database" ] || [ "$RESTORE_MODE" == "--restore-all" ]
then
	echo "restore database..."
	POD=$(kubectl get pod -l app=mariadb -o jsonpath="{.items[0].metadata.name}")
	if [ -z "$POD" ]; then 
		echo "ERROR: Could not find running pod. Exiting script."
		exit 1 
	fi
	kubectl exec -it $POD -- /usr/bin/mysql -u root -padmin -e 'drop database if exists drupal'
	kubectl exec -it $POD -- /usr/bin/mysql -u root -padmin -e 'create database drupal'
	kubectl exec -i $POD -- /usr/bin/mysql -u root -padmin drupal < ./backup/$BACKUP_FOLDER/database/drupal-dump.sql
	# validate
	# kubectl exec -it $POD -- /usr/bin/mysql -u root -padmin -e 'use drupal;show tables;'
fi

##########################

echo "restart the drupal-dev deployment..."
kubectl scale --replicas=0 deployment drupal-dev
echo "wait a moment..."
sleep 5
kubectl scale --replicas=1 deployment drupal-dev

##########################

# wait for drupal-dev
isPodReady=""
isPodReadyCount=0
until [ "$isPodReady" == "true" ]
do
	isPodReady=$(kubectl get pod -l app=drupal-dev -o jsonpath="{.items[0].status.containerStatuses[*].ready}")
	if [ "$isPodReady" != "true" ]; then
		((isPodReadyCount++))
		if [ "$isPodReadyCount" -gt "100" ]; then
			echo "ERROR: timeout waiting for drupal-dev pod. Exit script!"
			exit 1
		else
			echo "waiting...drupal-dev pod is not ready...($isPodReadyCount)"
			sleep 2
		fi
	fi
done

##########################

echo "opening the browser..."
open http://127.0.0.1:8080

##########################

echo
echo "...done"