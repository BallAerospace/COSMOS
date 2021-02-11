# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/win32/win32_main'
require 'cosmos/packets/structure'

module Cosmos
  # Uses the Win32API to implement methods useful on Windows.
  class Win32
    # Create a file
    def self.create_file(filename, desired_access, share_mode, security_attributes, creation_disposition, flags_and_attributes, template_file = NULL)
      api = Win32API.new('Kernel32', 'CreateFile', [LP, DWORD, DWORD, LP, DWORD, DWORD, HANDLE], HANDLE)
      handle = api.call(filename, desired_access, share_mode, security_attributes, creation_disposition, flags_and_attributes, template_file)
      raise "Error during CreateFile: #{get_last_error_message()}" if handle == INVALID_HANDLE_VALUE
      handle
    end

    # Close a file
    def self.close_handle(handle)
      api = Win32API.new('Kernel32', 'CloseHandle', [HANDLE], BOOL)
      result = api.call(handle)
      raise "Error closing handle: #{get_last_error_message()}" if result == 0
      result
    end

    # Get Comm State
    def self.get_comm_state(handle)
      dcb = build_dcb()
      api = Win32API.new('Kernel32', 'GetCommState', [HANDLE, LP], BOOL)
      result = api.call(handle, dcb.buffer)
      raise "GetCommState Error: #{get_last_error_message()}" if result == 0
      dcb
    end

    # Set Comm State
    def self.set_comm_state(handle, dcb)
      api = Win32API.new('Kernel32', 'SetCommState', [HANDLE, LP], BOOL)
      result = api.call(handle, dcb.buffer)
      raise "SetCommState Error: #{get_last_error_message()}" if result == 0
      result
    end

    # Set Comm Timeouts - Values in Ms
    def self.set_comm_timeouts(handle, read_interval_timeout = 4294967295, read_total_timeout_multiplier = 0, read_total_timeout_constant = 0, write_total_timeout_multiplier = 0, write_total_timeout_constant = 0)
      comm_timeouts = build_comm_timeouts(read_interval_timeout, read_total_timeout_multiplier, read_total_timeout_constant, write_total_timeout_multiplier, write_total_timeout_constant)
      api = Win32API.new('Kernel32', 'SetCommTimeouts', [HANDLE, LP], BOOL)
      result = api.call(handle, comm_timeouts.buffer)
      raise "SetCommTimeouts Error: #{get_last_error_message()}" if result == 0
      result
    end

    # Read File
    def self.read_file(handle, bytes_to_read, overlapped = NULL)
      buffer     = ' ' * (bytes_to_read + 1)
      bytes_read = ' ' * 8
      api = Win32API.new('Kernel32', 'ReadFile', [HANDLE, LP, DWORD, LP, LP], BOOL)
      api.call(handle, buffer, bytes_to_read, bytes_read, overlapped)
      bytes_read = bytes_read.unpack(DWORD)[0]
      if bytes_read > 0
        buffer[0..(bytes_read - 1)]
      else
        ''
      end
    end

    # Write File
    def self.write_file(handle, buffer, bytes_to_write, overlapped = NULL)
      bytes_written = ' ' * 8
      api = Win32API.new('Kernel32', 'WriteFile', [HANDLE, LP, DWORD, LP, LP], BOOL)
      api.call(handle, buffer, bytes_to_write, bytes_written, overlapped)
      bytes_written.unpack(DWORD)[0]
    end

    protected

    def self.build_dcb
      dcb = Structure.new(:LITTLE_ENDIAN)
      dcb.define_item('DCBlength', 0, 32, :UINT)
      dcb.define_item('BaudRate',  32, 32, :UINT)
      dcb.define_item('fBinary', 71, 1, :UINT)
      dcb.define_item('fParity', 70, 1, :UINT)
      dcb.define_item('fOutxCtsFlow', 69, 1, :UINT)
      dcb.define_item('fOutxDsrFlow', 68, 1, :UINT)
      dcb.define_item('fDtrControl', 66, 2, :UINT)
      dcb.define_item('fDsrSensitivity', 65, 1, :UINT)
      dcb.define_item('fTXContinueOnXoff', 64, 1, :UINT)
      dcb.define_item('fOutX', 79, 1, :UINT)
      dcb.define_item('fInX', 78, 1, :UINT)
      dcb.define_item('fErrorChar', 77, 1, :UINT)
      dcb.define_item('fNull', 76, 1, :UINT)
      dcb.define_item('fRtsControl', 74, 2, :UINT)
      dcb.define_item('fAbortOnError', 73, 1, :UINT)
      dcb.define_item('fDummy2', 88, 17, :UINT)
      dcb.define_item('wReserved', 96, 16, :UINT)
      dcb.define_item('XonLim', 112, 16, :UINT)
      dcb.define_item('XoffLim', 128, 16, :UINT)
      dcb.define_item('ByteSize', 144, 8, :UINT)
      dcb.define_item('Parity', 152, 8, :UINT)
      dcb.define_item('StopBits', 160, 8, :UINT)
      dcb.define_item('XonChar', 168, 8, :INT)
      dcb.define_item('XoffChar', 176, 8, :INT)
      dcb.define_item('ErrorChar', 184, 8, :INT)
      dcb.define_item('EofChar', 192, 8, :INT)
      dcb.define_item('EvtChar', 200, 8, :INT)
      dcb.define_item('wReserved1',   208, 16, :UINT)
      dcb.write('DCBlength', 28)
      dcb
    end

    def self.build_comm_timeouts(read_interval_timeout = 4294967295, read_total_timeout_multiplier = 0, read_total_timeout_constant = 0, write_total_timeout_multiplier = 0, write_total_timeout_constant = 0)
      comm_timeouts = Structure.new(:LITTLE_ENDIAN)
      comm_timeouts.append_item('ReadIntervalTimeout', 32, :UINT)
      comm_timeouts.append_item('ReadTotalTimeoutMultiplier', 32, :UINT)
      comm_timeouts.append_item('ReadTotalTimeoutConstant', 32, :UINT)
      comm_timeouts.append_item('WriteTotalTimeoutMultiplier', 32, :UINT)
      comm_timeouts.append_item('WriteTotalTimeoutConstant', 32, :UINT)
      comm_timeouts.write('ReadIntervalTimeout', read_interval_timeout)
      comm_timeouts.write('ReadTotalTimeoutMultiplier', read_total_timeout_multiplier)
      comm_timeouts.write('ReadTotalTimeoutConstant', read_total_timeout_constant)
      comm_timeouts.write('WriteTotalTimeoutMultiplier', write_total_timeout_multiplier)
      comm_timeouts.write('WriteTotalTimeoutConstant', write_total_timeout_constant)
      comm_timeouts
    end
  end
end

module QDA
  module Filters
    # Used only on windows to enable calling other executables without the
    # annoying command-prompt box that pops up when using Ruby backticks in
    # a script running under rubyw.
    #
    # Usage:
    # output, errors = QDA::Filters::Win32Process::backtick('dir')
    #
    # Note - most of this code written by S Kroeger, see
    # http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/155684
    module Win32Process
      NORMAL_PRIORITY_CLASS = 0x00000020
      STARTUP_INFO_SIZE = 68
      PROCESS_INFO_SIZE = 16
      SECURITY_ATTRIBUTES_SIZE = 12

      ERROR_SUCCESS = 0x00
      FORMAT_MESSAGE_FROM_SYSTEM = 0x1000
      FORMAT_MESSAGE_ARGUMENT_ARRAY = 0x2000

      HANDLE_FLAG_INHERIT = 1
      HANDLE_FLAG_PROTECT_FROM_CLOSE =2

      STARTF_USESHOWWINDOW = 0x00000001
      STARTF_USESTDHANDLES = 0x00000100

      class << self
        def raise_last_win_32_error
          errorCode = Cosmos::Win32API.new("kernel32", "GetLastError", [], 'L').call
          if errorCode != ERROR_SUCCESS
            params = [
              'L', # IN DWORD dwFlags,
              'P', # IN LPCVOID lpSource,
              'L', # IN DWORD dwMessageId,
              'L', # IN DWORD dwLanguageId,
              'P', # OUT LPSTR lpBuffer,
              'L', # IN DWORD nSize,
              'P', # IN va_list *Arguments
            ]

            formatMessage = Cosmos::Win32API.new("kernel32", "FormatMessage", params, 'L')
            msg = ' ' * 255
            formatMessage.call(FORMAT_MESSAGE_FROM_SYSTEM +
                                      FORMAT_MESSAGE_ARGUMENT_ARRAY, '', errorCode, 0, msg, 255, '')

            msg.gsub!(/\000/, '')
            msg.strip!
            raise msg
          else
            raise 'GetLastError returned ERROR_SUCCESS'
          end
        end

        def create_pipe # returns read and write handle
          params = [
            'P', # pointer to read handle
            'P', # pointer to write handle
            'P', # pointer to security attributes
            'L'] # pipe size

          createPipe = Cosmos::Win32API.new("kernel32", "CreatePipe", params, 'I')

          read_handle, write_handle = [0].pack('I'), [0].pack('I')
          sec_attrs = [SECURITY_ATTRIBUTES_SIZE, 0, 1].pack('III')

          raise_last_win_32_error if createPipe.Call(read_handle,
                                                      write_handle, sec_attrs, 0).zero?

          [read_handle.unpack('I')[0], write_handle.unpack('I')[0]]
        end

        def set_handle_information(handle, flags, value)
          params = [
            'L', # handle to an object
            'L', # specifies flags to change
            'L'] # specifies new values for flags

          setHandleInformation = Cosmos::Win32API.new("kernel32",
                                               "SetHandleInformation", params, 'I')
          raise_last_win_32_error if setHandleInformation.Call(handle,
                                                                flags, value).zero?
          nil
        end

        def close_handle(handle)
          closeHandle = Cosmos::Win32API.new("kernel32", "CloseHandle", ['L'], 'I')
          raise_last_win_32_error if closeHandle.call(handle).zero?
        end

        def create_process(command, stdin, stdout, stderror)
          params = [
            'L', # IN LPCSTR lpApplicationName
            'P', # IN LPSTR lpCommandLine
            'L', # IN LPSECURITY_ATTRIBUTES lpProcessAttributes
            'L', # IN LPSECURITY_ATTRIBUTES lpThreadAttributes
            'L', # IN BOOL bInheritHandles
            'L', # IN DWORD dwCreationFlags
            'L', # IN LPVOID lpEnvironment
            'L', # IN LPCSTR lpCurrentDirectory
            'P', # IN LPSTARTUPINFOA lpStartupInfo
            'P']  # OUT LPPROCESS_INFORMATION lpProcessInformation

          startupInfo = [STARTUP_INFO_SIZE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW, 0,
            0, 0, stdin, stdout, stderror].pack('IIIIIIIIIIIISSIIII')

          processInfo = [0, 0, 0, 0].pack('IIII')
          command << 0

          createProcess = Cosmos::Win32API.new("kernel32", "CreateProcess", params, 'I')
          cp_args = [ 0, command, 0, 0, 1, 0, 0, 0, startupInfo, processInfo ]
          raise_last_win_32_error if createProcess.call(*cp_args).zero?

          hProcess, hThread,
          dwProcessId, dwThreadId = processInfo.unpack('LLLL')

          close_handle(hProcess)
          close_handle(hThread)

          [dwProcessId, dwThreadId]
        end

        def write_file(hFile, buffer)
          params = [
            'L', # handle to file to write to
            'P', # pointer to data to write to file
            'L', # number of bytes to write
            'P', # pointer to number of bytes written
            'L'] # pointer to structure for overlapped I/O

          written = [0].pack('I')
          writeFile = Cosmos::Win32API.new("kernel32", "WriteFile", params, 'I')

          raise_last_win_32_error if writeFile.call(hFile, buffer, buffer.size,
                                                     written, 0).zero?

          written.unpack('I')[0]
        end

        def read_file(hFile)
          params = [
            'L', # handle of file to read
            'P', # pointer to buffer that receives data
            'L', # number of bytes to read
            'P', # pointer to number of bytes read
            'L'] #pointer to structure for data

          number = [0].pack('I')
          buffer = ' ' * 255

          readFile = Cosmos::Win32API.new("kernel32", "ReadFile", params, 'I')
          return '' if readFile.call(hFile, buffer, 255, number, 0).zero?

          buffer[0...number.unpack('I')[0]]
        end

        def peek_named_pipe(hFile)
          params = [
            'L', # handle to pipe to copy from
            'L', # pointer to data buffer
            'L', # size, in bytes, of data buffer
            'L', # pointer to number of bytes read
            'P', # pointer to total number of bytes available
            'L'] # pointer to unread bytes in this message

          available = [0].pack('I')
          peekNamedPipe = Cosmos::Win32API.new("kernel32", "PeekNamedPipe", params, 'I')

          return -1 if peekNamedPipe.Call(hFile, 0, 0, 0, available, 0).zero?

          available.unpack('I')[0]
        end
      end

      class Win32popenIO
        def initialize(hRead, hWrite, hError)
          @hRead  = hRead
          @hWrite = hWrite
          @hError = hError
        end

        def write data
          Win32Process::write_file(@hWrite, data.to_s)
        end

        def read
          sleep(0.01) while Win32Process::peek_named_pipe(@hRead).zero?
          Win32Process::read_file(@hRead)
        end

        def read_all
          all = ''
          until (buffer = read).empty?
            all << buffer
          end
          all
        end

        def read_err
          sleep(0.01) while Win32Process::peek_named_pipe(@hError).zero?
          Win32Process::read_file(@hError)
        end

        def read_all_err
          all = ''
          until (buffer = read_err).empty?
            all << buffer
          end
          all
        end
      end

      # The only useful public method in this class - receives a command line,
      # and returns the output content and error content as a pair of strings.
      # No shell expansion is carried out on the command line string.
      #
      # Usage:
      # output, errors = QDA::Filters::Win32Process::backtick('dir')
      def self.backtick(command)
        # create 3 pipes
        child_in_r, child_in_w = create_pipe
        child_out_r, child_out_w = create_pipe
        child_error_r, child_error_w = create_pipe

        # Ensure the write handle to the pipe for STDIN is not inherited.
        set_handle_information(child_in_w, HANDLE_FLAG_INHERIT, 0)
        set_handle_information(child_out_r, HANDLE_FLAG_INHERIT, 0)
        set_handle_information(child_error_r, HANDLE_FLAG_INHERIT, 0)

        create_process(command,
                              child_in_r,
                              child_out_w,
                              child_error_w)
        # we have to close the handles, so the pipes terminate with the process
        close_handle(child_in_r)
        close_handle(child_out_w)
        close_handle(child_error_w)
        close_handle(child_in_w)
        io = Win32popenIO.new(child_out_r, child_in_w, child_error_r)

        out = io.read_all().gsub(/\r/, '')
        err = io.read_all_err().gsub(/\r/, '')
        return out, err
      end
    end # module Win32Process
  end #module Filters
end # module QDA
