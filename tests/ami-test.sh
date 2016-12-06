SUCCESS=0
FAIL=0
for i in `seq 1 10`;
do
	echo "======= pass $i. Requesting spot instance"
	id=$(aws ec2 request-spot-instances --spot-price "0.017" --instance-count 1 --type "one-time" --launch-specification file://specification.json | jq -r ".SpotInstanceRequests[0].SpotInstanceRequestId")

	state=$(aws ec2 describe-spot-instance-requests --spot-instance-request-ids $id | jq -r ".SpotInstanceRequests[0].Status.Code")
	while [ "$state" != "fulfilled" ]
	do
	  echo "Current state: $state. Waiting 10s more for spot instance fulfilled"
	  sleep 10
	  let "timeout-=10"
	  state=$(aws ec2 describe-spot-instance-requests --spot-instance-request-ids $id | jq -r ".SpotInstanceRequests[0].Status.Code")
	done

	testvmid=$(aws ec2 describe-spot-instance-requests --spot-instance-request-ids $id | jq -r ".SpotInstanceRequests[0].InstanceId")

	echo "======== pass $i. testvmid: $testvmid"
	state=$(aws ec2 describe-instances --instance-ids $testvmid | jq -r ".Reservations[0].Instances[0].State.Name")
	while [ "$state" != "running" ]
	do
	  echo "Current state: $state. Waiting 10s more for VM becomes available"
	  sleep 10
	  let "timeout-=10"
	  state=$(aws ec2 describe-instances --instance-ids $testvmid | jq -r ".Reservations[0].Instances[0].State.Name")
	done
	echo "======= pass $i. test instance is running"

	state=$(aws ec2 describe-instance-status --instance-id $testvmid | jq -r ".InstanceStatuses[0].SystemStatus.Status")
	while [ "$state" != "ok" ]
	do
	  echo "Current SystemStatus: $state. Waiting 10s more for VM SystemStatus ok"
	  sleep 10
	  let "timeout-=10"
	  state=$(aws ec2 describe-instance-status --instance-id $testvmid | jq -r ".InstanceStatuses[0].SystemStatus.Status")
	done

	state=$(aws ec2 describe-instance-status --instance-id $testvmid | jq -r ".InstanceStatuses[0].InstanceStatus.Status")
	while [ "$state" != "ok" ]
	do
	  echo "Current InstanceStatus : $state. Waiting 10s more for VM InstanceStatus status ok"
	  sleep 10
	  let "timeout-=10"
	  state=$(aws ec2 describe-instance-status --instance-id $testvmid | jq -r ".InstanceStatuses[0].InstanceStatus.Status")
	done

	ip=$(aws ec2 describe-instances --instance-id=$testvmid | jq -r ".Reservations[0].Instances[0].PublicIpAddress")
	echo "======= pass $i. IP is $ip. Starting CF"

	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/prysmakou-cf-training.pem vcap@$ip "sudo /usr/local/bin/start-cf"
[]	# echo "Sleeping for 30s to allow services advertise itself etc"
	# sleep 30
	echo "===== pass $i. Running CF smoke tests"
	cf login -a https://api.$ip.xip.io -u admin -p admin --skip-ssl-validation
	cf create-space test
	cf target -o "cf-training" -s "test"
	cf push test -p testapp -b staticfile_buildpack -m 64M
	curl test.$ip.xip.io
	cf logs test --recent
	if [ "$?" = "0" ]; then
		echo "Ok"
		let SUCCESS=SUCCESS+1 
	else
		echo "Hmm..." 
		let FAIL=FAIL+1
	fi

	echo "===== pass $i. Terminating test instance"
	aws ec2 terminate-instances --instance-id $testvmid 
	state=$(aws ec2 describe-instances --instance-ids $testvmid | jq -r ".Reservations[0].Instances[0].State.Name")
	while [ "$state" != "terminated" ]
	do
	  echo "Current state: $state. Waiting 10s more for VM becomes terminated"
	  sleep 10
	  let "timeout-=10"
	  state=$(aws ec2 describe-instances --instance-ids $testvmid | jq -r ".Reservations[0].Instances[0].State.Name")
	done
	echo "====== pass $i. Test instance is terminated"
	echo "====== Success: $SUCCESS. Fail: $FAIL" ========
done
