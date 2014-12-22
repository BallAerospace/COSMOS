# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  module ScriptAudit
    # Script->Generate Cmd/Tlm Audit
    def script_audit
      all_commands = {}
      all_telemetry = {}
      output_filename = nil
      filenames = Qt::FileDialog.getOpenFileNames(self,
                                                  "Select Script Logs",
                                                  System.paths['LOGS'],
                                                  "Logs (*_sr_*.txt);;Text Files (*.txt)")
      # return doing nothing if they hit cancel in the file dialog
      return if filenames.empty?
      ProgressDialog.execute(self, 'Generation Progress', 650, 400) do |progress|
        progress.enable_cancel_button
        begin
          System.commands.target_names.each do |target_name|
            progress.append_text("Processing commands in target #{target_name}")
            progress.set_step_progress(0.0)
            index = 0.0
            packets = System.commands.packets(target_name)
            packets.each do |packet_name, packet|
              all_commands["#{target_name},#{packet_name}"] = 0

              # We aren't checking all the parameters because the combination of
              # values leads to an enormous set of possibilities

              progress.set_step_progress(index / packets.length)
              index += 1.0
            end
          end
          progress.set_overall_progress(0.05)

          System.telemetry.target_names.each do |target_name|
            progress.append_text("Processing telemetry in target #{target_name}")
            progress.set_step_progress(0.0)
            index = 0.0
            packets = System.telemetry.packets(target_name)
            packets.each do |packet_name, packet|
              # Skip hidden and disabled packets
              next if packet.hidden || packet.disabled
              packet.items.keys.each do |item_name|
                # Skip ignored items
                next if System.targets[target_name].ignored_items.include? item_name
                all_telemetry["#{target_name},#{packet_name},#{item_name}"] = 0
              end
              progress.set_step_progress(index / packets.length)
              index += 1.0
            end
          end
          progress.set_overall_progress(0.1)

          filenames.each_with_index do |filename, index|
            progress.append_text("Processing file #{filename}")
            progress.set_step_progress(0.0)
            File.open(filename) do |file|
              file.each do |line|
                # commands always start with cmd( or cmd_raw(
                if line =~ /cmd\(|cmd_raw\(/
                  # Split off the date, time, and procedure name. Then join back
                  # the command and split on the single quotes which delimit it.
                  # Finally split on the white space to get the target and packet.
                  begin
                    target, packet = line.split(' ')[3..-1].join(' ').split('"')[1].split(' ')
                    # Try to get the packet to prove that it exists
                    System.commands.packet(target, packet)
                    all_commands["#{target},#{packet}"] += 1
                  rescue
                    # If the item doesn't exist skip it
                  end
                end

                # telemetry is always checked with CHECK:
                if line =~ /CHECK:/
                  # Split off the date, time, procedure name, and 'CHECK' and
                  # grab the target, packet, and item names
                  target, packet, item = line.split(' ')[4..6]
                  begin
                    # Try to get the value to prove that it exists
                    System.telemetry.value(target, packet, item)
                    all_telemetry["#{target},#{packet},#{item}"] += 1
                  rescue
                    # If the item doesn't exist skip it
                  end
                end
                # Step progress this file using the file position and size
                progress.set_step_progress(file.pos.to_f / file.size)
              end
            end
            # Overall progress is 90% plus the 10% cmd/tlm processing we did above
            progress.set_overall_progress(index.to_f / filenames.length * 0.9 + 0.1)
          end

          output_filename = File.join(System.paths['LOGS'],
                                      File.build_timestamped_filename(['sr','audit'], '.csv'))
          progress.append_text("Writing audit to #{output_filename}")
          progress.set_step_progress(0.0)
          File.open(output_filename, 'w') do |file|
            file.puts "Cmd/Tlm audit generated with the following files:"
            filenames.each {|name| file.puts name }
            file.puts "\n"
            file.puts "COMMANDS,Total Sent,#{all_commands.inject(0){|sum, (_,val)| sum + val }}"
            file.puts "TARGET,PACKET,TOTAL"
            # First sort by the values (negative makes it sort biggest to smallest),
            # then sort by the target/packet name
            all_commands.sort_by{|hash| [-hash[1], hash[0]]}.each do |cmd, total|
              file.puts "#{cmd},#{total}"
            end
            file.puts "\nTELEMETRY,Total Checked,#{all_telemetry.inject(0){|sum, (_,val)| sum + val }}"
            file.puts "TARGET,PACKET,ITEM,TOTAL"
            # First sort by the values (negative makes it sort biggest to smallest),
            # then sort by the target/packet/item name
            all_telemetry.sort_by{|hash| [-hash[1], hash[0]]}.each do |tlm, total|
              file.puts "#{tlm},#{total}"
            end
          end
        rescue => error
          progress.append_text("Error processing:\n#{error.formatted}\n")
        ensure
          progress.set_step_progress(1.0)
          progress.set_overall_progress(1.0)
          progress.complete
        end
      end
      # Open the file as a convenience
      Cosmos.open_in_text_editor(output_filename) if output_filename
    end
  end # module ScriptAudit
end # module Cosmos
