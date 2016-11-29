The test creates (10 times by default) CF VM from AMI and pushes an app to it.

To run test check values in specification.json.
Also check spot instance price in ami-test.sh and specify amount of times to run in first lines of the script.


prerequisites: aws cli, jq, cf cli. Assume aws env variables set.

to run: ./ami-test.sh