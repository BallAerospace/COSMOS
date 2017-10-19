# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'erb'
require 'tempfile'
require 'open3'

module Cosmos

  # Reads an ascii file that defines the configuration settings used to
  # configure the Handbook Creator
  class HandbookCreatorConfig

    attr_reader :pages

    class Page
      attr_reader :filename
      attr_reader :type
      attr_reader :target_names
      attr_reader :sections
      attr_accessor :pdf
      attr_accessor :pdf_cover_filename
      attr_accessor :pdf_cover_title
      attr_accessor :pdf_header_filename
      attr_accessor :pdf_header_title
      attr_accessor :pdf_footer_filename
      attr_accessor :pdf_footer_title
      attr_accessor :pdf_toc
      attr_accessor :pdf_top_margin
      attr_accessor :pdf_bottom_margin
      attr_accessor :pdf_side_margin

      def initialize(filename, type = :NORMAL)
        @filename = filename
        @type = type
        @target_names = []
        @sections = []
        @pdf = true
        @pdf_toc = nil
        @pdf_cover_filename = nil
        @pdf_cover_title = nil
        @pdf_header_filename = nil
        @pdf_header_title = nil
        @pdf_footer_filename = nil
        @pdf_footer_title = nil
        @pdf_top_margin = 20
        @pdf_bottom_margin = 15
        @pdf_side_margin = 10
      end

      def add_target_name(target_name)
        @target_names << target_name.upcase
        @target_names.uniq!
      end

      def add_section(section)
        @sections << section
      end

      def create_html(hide_ignored)
        @hide_ignored = hide_ignored
        Cosmos.set_working_dir do
          if @type == :TARGETS
            target_names = @target_names
            target_names = System.commands.target_names | System.telemetry.target_names if @target_names.empty?
            target_names.each {|target_name| create_file(target_name.downcase + @filename, [target_name], true, :HTML)}
          else # @type == :NORMAL
            create_file(@filename, @target_names, false, :HTML)
          end
        end
      end

      def create_pdf(hide_ignored, progress_dialog = nil)
        @hide_ignored = hide_ignored
        if @pdf
          if progress_dialog
            Qt.execute_in_main_thread(true) do
              progress_dialog.set_text_font(Cosmos.get_default_font)
            end
          end
          Cosmos.set_working_dir do
            if @type == :TARGETS
              target_names = @target_names
              target_names = System.commands.target_names | System.telemetry.target_names if @target_names.empty?
              target_names.each do |target_name|
                create_pdf_file(progress_dialog, target_name)
              end
            else # @type == :NORMAL
              create_pdf_file(progress_dialog)
            end
          end
        end
      end

      protected

      def create_pdf_file(progress_dialog, target_name = nil)
        tmp_html_file = Tempfile.new(['pdf', '.html'], System.paths['HANDBOOKS'])
        if target_name
          filename = File.join(System.paths['HANDBOOKS'], target_name.downcase + @filename)
          create_file(tmp_html_file, [target_name], true, :PDF)
        else
          filename = File.join(System.paths['HANDBOOKS'], @filename)
          create_file(tmp_html_file, @target_names, false, :PDF)
        end
        tmp_html_file.close
        cover, cover_file = make_pdf_detail('cover', @pdf_cover_filename, @pdf_cover_title, target_name)
        header, header_file = make_pdf_detail('--header-spacing 3 --header-html', @pdf_header_filename, @pdf_header_title, target_name)
        footer, footer_file = make_pdf_detail('--footer-spacing 3 --footer-html', @pdf_footer_filename, @pdf_footer_title, target_name)
        system_call = "wkhtmltopdf -L #{@pdf_side_margin} -R #{@pdf_side_margin} -T #{@pdf_top_margin} -B #{@pdf_bottom_margin} -s Letter #{header} #{footer} #{cover} #{@pdf_toc} \"#{tmp_html_file.path}\" \"#{File.dirname(filename)}/#{File.basename(filename, '.*')}.pdf\""
        status = nil
        begin
          Cosmos.set_working_dir(System.paths['HANDBOOKS']) do
            Open3.popen2e(system_call) do |stdin, stdout_and_stderr, wait_thr|
              while wait_thr.alive?
                stdout_and_stderr.each_line do |line|
                  progress_dialog.append_text(line.chomp) if progress_dialog
                end
              end
              status = wait_thr.value
            end
          end
        rescue Errno::ENOENT
          status = nil
        end
        tmp_html_file.unlink
        cover_file.unlink if cover_file
        header_file.unlink if header_file
        footer_file.unlink if footer_file
        raise "Call to wkhtmltopdf failed" if !status or !status.success?
      end

      def make_pdf_detail(tag, filename, title, target_name = nil)
        if filename
          file = Tempfile.new(['pdf', '.html'], System.paths['HANDBOOKS'])
          if target_name
            title = target_name + ' ' + title
          else
            title = title
          end
          file.write(ERB.new(File.read(File.join(USERPATH, 'config', 'tools', 'handbook_creator', 'templates', filename))).result(binding))
          file.close
          result = "#{tag} \"#{file.path}\""
          return result, file
        end
        return nil, nil
      end

      def create_file(filename, target_names, target_pages, output)
        if Tempfile === filename
          create_file_internal(filename, target_names, target_pages, output)
        else
          File.open(File.join(System.paths['HANDBOOKS'], filename), "w") do |file|
            create_file_internal(file, target_names, target_pages, output)
          end
        end
      end

      def create_file_internal(file, target_names, target_pages, output)
        @sections.each do |section|
          if section.output != :ALL
            next unless section.output == output
          end
          packets = build_packets(section.type, target_names)
          ignored = build_ignored(section.type, target_names)
          if target_pages
            section.create(file, target_names[0] + ' ' + section.title.to_s, packets, ignored)
          else
            section.create(file, section.title.to_s, packets, ignored)
          end
        end
      end

      def build_ignored(type, target_names)
        ignored = {}
        target_names = System.targets.keys if target_names.empty?
        target_names.each do |name|
          if @hide_ignored
            if type == :CMD
              ignored[name] = System.targets[name].ignored_parameters
            elsif type == :TLM
              ignored[name] = System.targets[name].ignored_items
            end
          else
            # If we're not ignoring items the hash contains an empty array
            ignored[name] = []
          end
        end
        ignored
      end

      def build_packets(type, target_names)
        packets = []
        case type
        when :CMD
          packet_accessor = System.commands
        when :TLM
          packet_accessor = System.telemetry
        else
          # Return the empty array because there are no packets
          return packets
        end
        if target_names.empty?
          packet_accessor.all.sort.each do |target_name, target_packets|
            target_packets.sort.each do |packet_name, packet|
              next if packet.target_name == "UNKNOWN"
              next if packet.hidden
              packets << packet
            end
          end
        else
          target_names.each do |target_name|
            begin
              packet_accessor.packets(target_name).sort.each do |packet_name, packet|
                next if packet.hidden
                packets << packet
              end
            rescue
              # No commands
            end
          end
        end
        packets
      end

    end # class Page

    class Section
      attr_reader :filename
      attr_reader :type
      attr_reader :title
      attr_reader :output

      def initialize(output, filename, title, type = :NONE)
        raise "Unknown output: #{output.to_s.upcase}" unless ['ALL', 'HTML', 'PDF'].include?(output.to_s.upcase)
        @output = output.to_s.upcase.intern
        @filename = File.join(USERPATH, 'config', 'tools', 'handbook_creator', 'templates', filename)
        @title = title
        @type = type
      end

      def create(file, title, packets = [], ignored = {})
        file.puts ERB.new(File.read(@filename)).result(binding)
      end

    end # class Section

    # Parses the configuration file.
    #
    # @param filename [String] The name of the configuration file to parse
    def initialize(filename)
      @pages = []
      process_file(filename)
    end

    def create_html(hide_ignored)
      @pages.each {|page| page.create_html(hide_ignored)}
    end

    def create_pdf(hide_ignored, progress_dialog = nil)
      begin
        @pages.each_with_index do |page, index|
          progress_dialog.set_overall_progress(index.to_f / @pages.length.to_f) if progress_dialog
          page.create_pdf(hide_ignored, progress_dialog)
        end
        progress_dialog.set_overall_progress(1.0) if progress_dialog
      rescue Exception => err
        if err.message == "Call to wkhtmltopdf failed"
          return false
        else
          raise err
        end
      end
      true
    end

    protected

    # Processes a file and adds in the configuration defined in the file
    #
    # @param filename [String] The name of the configuration file to parse
    def process_file(filename)
      current_page = nil
      current_section = nil
      Logger.info "Processing Handbook Creator configuration in file: #{File.expand_path(filename)}"

      parser = ConfigParser.new
      parser.parse_file(filename) do |keyword, params|
        case keyword
        when 'PAGE'
          parser.verify_num_parameters(1, 1, "#{keyword} <Filename>")
          current_page = Page.new(params[0])
          @pages << current_page

        when 'TARGET_PAGES'
          parser.verify_num_parameters(1, 1, "#{keyword} <Filename Postfix>")
          current_page = Page.new(params[0], :TARGETS)
          @pages << current_page

        when 'NO_PDF'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(0, 0, "#{keyword}")
          current_page.pdf = false

        when 'PDF_COVER'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(2, 2, "#{keyword} <Cover html.erb file> <Title Text>")
          current_page.pdf_cover_filename = params[0].to_s
          current_page.pdf_cover_title = params[1].to_s

        when 'PDF_TOC'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(0, 0, "#{keyword}")
          current_page.pdf_toc = "toc --xsl-style-sheet \"#{File.join(USERPATH, 'config', 'tools', 'handbook_creator', 'default_toc.xsl')}\""

        when 'PDF_HEADER'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(2, 2, "#{keyword} <Header html.erb file> <Title Text>")
          current_page.pdf_header_filename = params[0].to_s
          current_page.pdf_header_title = params[1].to_s

        when 'PDF_FOOTER'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(2, 2, "#{keyword} <Footer html.erb file> <Title Text>")
          current_page.pdf_footer_filename = params[0].to_s
          current_page.pdf_footer_title = params[1].to_s

        when 'PDF_TOP_MARGIN'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(1, 1, "#{keyword} <Margin in mm>")
          current_page.pdf_top_margin = params[0].to_i

        when 'PDF_BOTTOM_MARGIN'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(1, 1, "#{keyword} <Margin in mm>")
          current_page.pdf_bottom_margin = params[0].to_i

        when 'PDF_SIDE_MARGIN'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(1, 1, "#{keyword} <Margin in mm>")
          current_page.pdf_side_margin = params[0].to_i

        when 'TARGET'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(1, 1, "#{keyword} <Target Name>")
          current_page.add_target_name(params[0])

        when 'SECTION'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(2, 3, "#{keyword} <Filename> <output: ALL, HTML, or PDF> <Title (optional)>")
          current_section = Section.new(params[0], params[1], params[2])
          current_page.add_section(current_section)

        when 'CMD_SECTION'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(2, 3, "#{keyword} <Filename> <output: ALL, HTML, or PDF> <Title (optional)>")
          current_section = Section.new(params[0], params[1], params[2], :CMD)
          current_page.add_section(current_section)

        when 'TLM_SECTION'
          raise parser.error("#{keyword} must be preceded by PAGE or TARGET_PAGES") unless current_page
          parser.verify_num_parameters(2, 3, "#{keyword} <Filename> <output: ALL, HTML, or PDF> <Title (optional)>")
          current_section = Section.new(params[0], params[1], params[2], :TLM)
          current_page.add_section(current_section)

        else
          # blank lines will have a nil keyword and should not raise an exception
          raise parser.error("Unknown keyword: #{keyword}") unless keyword.nil?
        end  # case
      end  # loop

    end

  end # class HandbookCreatorConfig

end # module Cosmos
