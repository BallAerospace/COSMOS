### Table of Contents

<span>[Concepts](#concepts)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Ruby Programming Language](#ruby-programming-language)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Telemetry Types](#telemetry-types)<br/>
<br/>
<span>[Writing Test Procedures](#writing-test-procedures)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Using Subroutines](#using-subroutines)<br/>
<br/>
<span>[Example Test Procedures](#example-test-procedures)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Subroutines](#subroutines)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Ruby Control Structures](#ruby-control-structures)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Iterating over similarly named telemetry points](#iterating-over-similarly-named-telemetry-points)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Prompting for User Input](#prompting-for-user-input)<br/>
<br/>
<span>[Running Test Procedures](#running-test-procedures)</span><br/>
<br/>
<span>[Execution Environment](#execution-environment)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [Using Script Runner](#using-script-runner)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [From the Command Line](#from-the-command-line)<br/>
<br/>
<span>[Test Procedure API](#test-procedure-api)</span><br/>
<br/>
<span>[Retrieving User Input](#retrieving-user-input)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [ask](#ask)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [ask_string](#askstring)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [message_box, vertical_message_box (COSMOS 3.5.0+), combo_box (COSMOS 3.5.0+)](#messagebox,-verticalmessagebox-(cosmos-3.5.0+),-combobox-(cosmos-3.5.0+))<br/>
<br/>
<span>[Providing information to the user](#providing-information-to-the-user)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [prompt](#prompt)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [status_bar](#statusbar)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [play_wav_file](#playwavfile)<br/>
<br/>
<span>[Commands](#commands)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd](#cmd)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_no_range_check](#cmdnorangecheck)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_no_hazardous_check](#cmdnohazardouscheck)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_no_checks](#cmdnochecks)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_raw](#cmdraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_raw_no_range_check](#cmdrawnorangecheck)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_raw_no_hazardous_check](#cmdrawnohazardouscheck)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [cmd_raw_no_checks](#cmdrawnochecks)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [send_raw](#sendraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [send_raw_file](#sendrawfile)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_list](#getcmdlist)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_param_list](#getcmdparamlist)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_hazardous](#getcmdhazardous)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_value (COSMOS 3.5.0+)](#getcmdvalue-(cosmos-3.5.0+))<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_time (COSMOS 3.5.0+)](#getcmdtime-(cosmos-3.5.0+))<br/>
<br/>
<span>[Handling Telemetry](#handling-telemetry)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check](#check)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check_raw](#checkraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check_formatted](#checkformatted)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check_with_units](#checkwithunits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check_tolerance](#checktolerance)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check_tolerance_raw](#checktoleranceraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [check_expression](#checkexpression)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [tlm](#tlm)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [tlm_raw](#tlmraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [tlm_formatted](#tlmformatted)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [tlm_with_units](#tlmwithunits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [tlm_variable](#tlmvariable)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_tlm_packet](#gettlmpacket)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_tlm_values](#gettlmvalues)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_tlm_list](#gettlmlist)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_tlm_item_list](#gettlmitemlist)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_tlm_details](#gettlmdetails)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_tlm](#settlm)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_tlm_raw](#settlmraw)<br/>
<br/>
<span>[Packet Data Subscriptions](#packet-data-subscriptions)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [subscribe_packet_data](#subscribepacketdata)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [unsubscribe_packet_data](#unsubscribepacketdata)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_packet](#getpacket)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_packet_data](#getpacketdata)<br/>
<br/>
<span>[Delays](#delays)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait](#wait)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_raw](#waitraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_tolerance](#waittolerance)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_tolerance_raw](#waittoleranceraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_expression](#waitexpression)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_packet](#waitpacket)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_check](#waitcheck)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_check_raw](#waitcheckraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_check_tolerance](#waitchecktolerance)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_check_tolerance_raw](#waitchecktoleranceraw)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_check_expression](#waitcheckexpression)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [wait_check_packet](#waitcheckpacket)<br/>
<br/>
<span>[Limits](#limits)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [limits_enabled?](#limitsenabled?)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [enable_limits](#enablelimits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [disable_limits](#disablelimits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [enable_limits_group](#enablelimitsgroup)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [disable_limits_group](#disablelimitsgroup)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_limits_groups](#getlimitsgroups)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_limits_set](#setlimitsset)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_limits_set](#getlimitsset)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_limits_sets](#getlimitssets)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_limits](#getlimits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_limits](#setlimits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_out_of_limits](#getoutoflimits)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_overall_limits_state](#getoveralllimitsstate)<br/>
<br/>
<span>[Limits Events](#limits-events)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [subscribe_limits_events](#subscribelimitsevents)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [unsubscribe_limits_events](#unsubscribelimitsevents)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_limits_event](#getlimitsevent)<br/>
<br/>
<span>[Targets](#targets)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_target_list](#gettargetlist)<br/>
<br/>
<span>[Interfaces](#interfaces)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [connect_interface](#connectinterface)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [disconnect_interface](#disconnectinterface)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [interface_state](#interfacestate)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [map_target_to_interface](#maptargettointerface)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_interface_names](#getinterfacenames)<br/>
<br/>
<span>[Routers](#routers)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [connect_router](#connectrouter)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [disconnect_router](#disconnectrouter)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [router_state](#routerstate)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_router_names](#getrouternames)<br/>
<br/>
<span>[Logging](#logging)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_log_filename](#getcmdlogfilename)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_tlm_log_filename](#gettlmlogfilename)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_logging](#startlogging)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_cmd_log](#startcmdlog)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_tlm_log](#starttlmlog)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [stop_logging](#stoplogging)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [stop_cmd_log](#stopcmdlog)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [stop_tlm_log](#stoptlmlog)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_server_message_log_filename](#getservermessagelogfilename)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_new_server_message_log](#startnewservermessagelog)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_raw_logging_interface](#startrawlogginginterface)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [stop_raw_logging_interface](#stoprawlogginginterface)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_raw_logging_router](#startrawloggingrouter)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [stop_raw_logging_router](#stoprawloggingrouter)<br/>
<br/>
<span>[Executing Other Procedures](#executing-other-procedures)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start](#start)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [load_utility](#loadutility)<br/>
<br/>
<span>[Opening and Closing Telemetry Screens](#opening-and-closing-telemetry-screens)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [display](#display)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [clear](#clear)<br/>
<br/>
<span>[Script Runner Specific Functionality](#script-runner-specific-functionality)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_line_delay](#setlinedelay)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_line_delay](#getlinedelay)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_scriptrunner_message_log_filename](#getscriptrunnermessagelogfilename)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [start_new_scriptrunner_message_log](#startnewscriptrunnermessagelog)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [disable_instrumentation](#disableinstrumentation)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_stdout_max_lines](#setstdoutmaxlines)<br/>
<br/>
<span>[Debugging](#debugging)</span><br/>
&nbsp;&nbsp;&nbsp;&nbsp; [insert_return](#insertreturn)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [step_mode](#stepmode)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [run_mode](#runmode)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [show_backtrace](#showbacktrace)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [shutdown_cmd_tlm](#shutdowncmdtlm)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [set_cmd_tlm_disconnect](#setcmdtlmdisconnect)<br/>
&nbsp;&nbsp;&nbsp;&nbsp; [get_cmd_tlm_disconnect](#getcmdtlmdisconnect)<br/>
