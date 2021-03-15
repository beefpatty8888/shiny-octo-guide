# Notes for a private GKE cluster in a VPC
The GKE cluster must have 1 subnet, and 2 secondary IP ranges - one for pods, the other for the services.
Usually recommended to follow the subnet and secondary IP ranges as specified in 
https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#custom_subnet

No secondary range or new subnet is needed for the "master-ip-cidr" parameter.

Also, in the Google Cloud VPC, it may be necessary to create a new Cloud NAT (and a Cloud Router) to allow egress traffic from the "cluster-secondary-range-name" used by the GKE pods.

Below is an example that uses a VPC named `elvis-gke` with the subnet in the VPC named `elvis-gke-vpc-subnet-01 ` 
```
gcloud container clusters create <cluster-name> --network=elvis-gke --subnetwork=elvis-gke-vpc-subnet-01  --cluster-secondary-range-name=gke-pods --services-secondary-range-name=gke-services --enable-private-nodes --enable-ip-alias --enable-master-global-access --no-enable-master-authorized-networks --master-ipv4-cidr 172.16.0.16/28 --num-nodes=2 --machine-type=e2-small --scopes=https://www.googleapis.com/auth/compute.readonly,gke-default --zone us-central1-c
```

## References
* https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#custom_subnet