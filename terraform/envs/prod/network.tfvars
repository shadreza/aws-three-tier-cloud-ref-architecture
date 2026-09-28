vpc_cidr         = "10.40.0.0/16"
azs              = ["ap-northeast-1a", "ap-northeast-1c"]
nat_gateway_mode = "per_az" # one per zone: a zone outage cannot cut outbound traffic
