create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports sys_clk]
#create_clock -name rmii_clocks_ref_clk -period 20.0 [get_ports rmii_clocks_ref_clk]

set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property PACKAGE_PIN N15 [get_ports sys_clk]

set_property IOSTANDARD LVCMOS33 [get_ports reset]
set_property PACKAGE_PIN J2 [get_ports reset]

#PHY Signals
set_property IOSTANDARD LVCMOS33 [get_ports rmii_clocks_ref_clk]
set_property PACKAGE_PIN G18 [get_ports rmii_clocks_ref_clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rmii_clocks_ref_clk_IBUF]

set_property IOSTANDARD LVCMOS33 [get_ports rmii_crs_dv]
set_property PACKAGE_PIN J16 [get_ports rmii_crs_dv]
set_property IOSTANDARD LVCMOS33 [get_ports rmii_mdc]
set_property PACKAGE_PIN J15 [get_ports rmii_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports rmii_mdio]
set_property PACKAGE_PIN M14 [get_ports rmii_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii_rx_data[0]}]
set_property PACKAGE_PIN L17 [get_ports {rmii_rx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii_rx_data[1]}]
set_property PACKAGE_PIN K14 [get_ports {rmii_rx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii_tx_data[0]}]
set_property PACKAGE_PIN K16 [get_ports {rmii_tx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rmii_tx_data[1]}]
set_property PACKAGE_PIN N14 [get_ports {rmii_tx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports rmii_tx_en]
set_property PACKAGE_PIN L18 [get_ports rmii_tx_en]

#set_false_path -quiet -to [get_nets -filter {mr_ff == TRUE}]
#set_false_path -quiet -to [get_pins -filter {REF_PIN_NAME == PRE} -of_objects [get_cells -hierarchical -filter {ars_ff1 == TRUE || ars_ff2 == TRUE}]]
#set_max_delay 2 -quiet -from [get_pins -filter {REF_PIN_NAME == Q} -of_objects [get_cells -hierarchical -filter {ars_ff1 == TRUE}]] -to [get_pins -filter {REF_PIN_NAME == D} -of_objects [get_cells -hierarchical -filter {ars_ff2 == TRUE}]]
#set_clock_groups -group [get_clocks -include_generated_clocks -of [get_nets sys_clk]] -group [get_clocks -include_generated_clocks -of [get_ports rmii_clocks_ref_clk]] -asynchronous
#set_clock_groups -group [get_clocks -include_generated_clocks -of [get_ports rmii_clocks_ref_clk]] -group [get_clocks -include_generated_clocks -of [get_nets sys_clk]] -asynchronous
###set_property CLOCK_BUFFER_TYPE BUFG [get_nets rmii_clocks_ref_clk]
