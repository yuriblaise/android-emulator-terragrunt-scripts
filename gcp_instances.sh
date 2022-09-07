gcp_region=${1:-us-west2-a}
sed '1s/^/gcp\t/; 2,$s/^/gcp\t/' <(gcloud compute machine-types list --project=cloudemutest --zones=$gcp_region | awk '{print $1,$3,$4}')