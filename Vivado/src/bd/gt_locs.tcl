
# Opsero Electronic Design Inc. Copyright 2024

# GT LOC constraints are required in the configuration of the AXI Ethernet Subsystem IPs.
# The following code constructs a nested dictionary that contains the GT assignments for
# each target board for ports 0,1,2,3 of the Ethernet FMC Max.

# To use the dictionary:
#   * Get the GT coordinate:    dict get $gt_loc_dict <target> <port number>

dict set gt_loc_dict kcu105_hpc 0 X0Y16
dict set gt_loc_dict kcu105_hpc 1 X0Y17
dict set gt_loc_dict kcu105_hpc 2 X0Y18
dict set gt_loc_dict kcu105_hpc 3 X0Y19
dict set gt_loc_dict uzev 0 X0Y8
dict set gt_loc_dict uzev 1 X0Y9
dict set gt_loc_dict uzev 2 X0Y10
dict set gt_loc_dict uzev 3 X0Y11
dict set gt_loc_dict vcu118_fmcp 0 X0Y8
dict set gt_loc_dict vcu118_fmcp 1 X0Y9
dict set gt_loc_dict vcu118_fmcp 2 X0Y10
dict set gt_loc_dict vcu118_fmcp 3 X0Y11
dict set gt_loc_dict zcu102_hpc0 0 X1Y10
dict set gt_loc_dict zcu102_hpc0 1 X1Y9
dict set gt_loc_dict zcu102_hpc0 2 X1Y11
dict set gt_loc_dict zcu102_hpc0 3 X1Y8
dict set gt_loc_dict zcu102_hpc1 0 X0Y12
dict set gt_loc_dict zcu102_hpc1 1 X0Y13
dict set gt_loc_dict zcu102_hpc1 2 X0Y14
dict set gt_loc_dict zcu102_hpc1 3 X0Y15
dict set gt_loc_dict zcu104 0 X0Y15
dict set gt_loc_dict zcu106_hpc0 0 X0Y14
dict set gt_loc_dict zcu106_hpc0 1 X0Y13
dict set gt_loc_dict zcu106_hpc0 2 X0Y15
dict set gt_loc_dict zcu106_hpc0 3 X0Y12
dict set gt_loc_dict zcu111 0 X0Y8
dict set gt_loc_dict zcu111 1 X0Y9
dict set gt_loc_dict zcu111 2 X0Y10
dict set gt_loc_dict zcu111 3 X0Y11
dict set gt_loc_dict zcu208 0 X0Y12
dict set gt_loc_dict zcu208 1 X0Y13
dict set gt_loc_dict zcu208 2 X0Y14
dict set gt_loc_dict zcu208 3 X0Y15
dict set gt_loc_dict zcu216 0 X0Y12
dict set gt_loc_dict zcu216 1 X0Y13
dict set gt_loc_dict zcu216 2 X0Y14
dict set gt_loc_dict zcu216 3 X0Y15
