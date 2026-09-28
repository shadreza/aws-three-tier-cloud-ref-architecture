vpc_cidr         = "10.30.0.0/16"
azs              = ["ap-northeast-1a", "ap-northeast-1c"]
nat_gateway_mode = "single" # one NAT for both zones, about $45 a month cheaper per zone saved
