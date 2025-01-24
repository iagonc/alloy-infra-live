include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/alloy-cluster.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/aws/backend-asg"
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  instance_type = "t2.micro"
  custom_cidr   = "0.0.0.0/0"

  asg_min_size     = 1
  asg_max_size     = 3
  asg_desired_size = 1

  key_pair_name = "newkeypair"
}
