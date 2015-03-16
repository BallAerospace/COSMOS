# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Win32API is deprecated in 1.9.x so recreate it
  require 'fiddle'
  class Win32API
    # Cache to hold already opened dll files
    DLL_CACHE = {}

    VALUE_TYPEMAP = {"0" => Fiddle::TYPE_VOID, "S" => Fiddle::TYPE_VOIDP, "I" => Fiddle::TYPE_LONG}

    def initialize(dll_name, function_name, import, export = "0")
      # Convert all input parameters into either 0, S, or I
      @function_prototype = [import].join.tr("VPpNnLlIiCc", "0SSI")
      params = []
      @function_prototype.split('').each do |param|
        params << VALUE_TYPEMAP[param]
      end

      # Get handle to dll file and add to cache if necessary
      dll_handle = DLL_CACHE[dll_name] ||= Fiddle.dlopen(dll_name)

      # Create Fiddle::Function necessary to call a function with proper return type and name
      @function = Fiddle::Function.new(dll_handle[function_name], params, VALUE_TYPEMAP[export.tr("VPpNnLlIi", "0SSI")])
    end

    def call(*args)
      # Break up prototype into characters
      import = @function_prototype.split('')

      args.each_with_index do |arg, index|
        case import[index]
        when 'S'
          # Handle NULL specified with 0 value
          arg = nil if arg == 0

          # Convert argument into array of longs
          args[index], = [arg].pack("p").unpack("l!*")
        when 'I'
          # Handle intergers larger than 2^31 - 1
          args[index], = [arg].pack("I").unpack("i")
        end
      end

      # Call the function and return its return value
      return_value = @function.call(*args)
      return_value ||= 0
      return_value
    end

    # Make an equivalent capital C call method
    alias Call call
  end

  # Win32 class
  #
  # This class implements the Win32
  #
  class Win32

    # Data Types
    BOOL = 'i'
    BYTE = 'C'
    DWORD = 'L'
    HANDLE = 'L'
    LP = 'P'
    LPSECURITY_ATTRIBUTES = DWORD

    # Misc Constants
    NULL = 0
    INVALID_HANDLE_VALUE = -1

    # Generic Rights (WinNT.h)
    GENERIC_READ = 0x80000000
    GENERIC_WRITE = 0x40000000
    GENERIC_EXECUTE = 0x20000000
    GENERIC_ALL = 0x10000000

    # File Sharing (WinNT.h)
    FILE_UNSHARED = 0x00000000 # not defined in WinNT.h
    FILE_SHARE_READ = 0x00000001
    FILE_SHARE_WRITE = 0x00000002
    FILE_SHARE_DELETE = 0x00000004

    # File Open Options (WinBase.h)
    CREATE_NEW = 1
    CREATE_ALWAYS = 2
    OPEN_EXISTING = 3
    OPEN_ALWAYS = 4
    TRUNCATE_EXISTING = 5

    # File Attributes (WinNT.h)
    FILE_ATTRIBUTE_READONLY = 0x00000001
    FILE_ATTRIBUTE_HIDDEN = 0x00000002
    FILE_ATTRIBUTE_SYSTEM = 0x00000004
    FILE_ATTRIBUTE_DIRECTORY = 0x00000010
    FILE_ATTRIBUTE_ARCHIVE = 0x00000020
    FILE_ATTRIBUTE_DEVICE = 0x00000040
    FILE_ATTRIBUTE_NORMAL = 0x00000080
    FILE_ATTRIBUTE_TEMPORARY = 0x00000100
    FILE_ATTRIBUTE_SPARSE_FILE = 0x00000200
    FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400
    FILE_ATTRIBUTE_COMPRESSED = 0x00000800
    FILE_ATTRIBUTE_OFFLINE = 0x00001000
    FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x00002000
    FILE_ATTRIBUTE_ENCRYPTED = 0x00004000
    FILE_ATTRIBUTE_VIRTUAL = 0x00010000

    # Baud Rates
    CBR_110 = 110
    CBR_300 = 300
    CBR_600 = 600
    CBR_1200 = 1200
    CBR_2400 = 2400
    CBR_4800 = 4800
    CBR_9600 = 9600
    CBR_14400 = 14400
    CBR_19200 = 19200
    CBR_38400 = 38400
    CBR_56000 = 56000
    CBR_57600 = 57600
    CBR_115200 = 115200
    CBR_128000 = 128000
    CBR_256000 = 256000
    BAUD_RATES = [CBR_110, CBR_300, CBR_600, CBR_1200, CBR_2400, CBR_4800, CBR_9600, CBR_14400, CBR_19200, CBR_38400, CBR_56000, CBR_57600, CBR_115200, CBR_128000, CBR_256000]

    # Parity
    NOPARITY = 0
    ODDPARITY = 1
    EVENPARITY = 2
    MARKPARITY = 3
    SPACEPARITY = 4
    PARITY_SETTINGS = [NOPARITY, ODDPARITY, EVENPARITY, MARKPARITY, SPACEPARITY]

    # Stop Bits
    ONESTOPBIT = 0
    ONE5STOPBITS = 1
    TWOSTOPBITS = 2
    STOP_BIT_SETTINGS = [ONESTOPBIT, ONE5STOPBITS, TWOSTOPBITS]

    # Dialog Box Command Ids
    IDOK = 1
    IDCANCEL = 2
    IDABORT = 3
    IDRETRY = 4
    IDIGNORE = 5
    IDYES = 6
    IDNO = 7
    IDCLOSE = 8
    IDHELP = 9

    # Message Box Types
    MB_OK = 0x00000000
    MB_OKCANCEL = 0x00000001
    MB_ABORTRETRYIGNORE = 0x00000002
    MB_YESNOCANCEL = 0x00000003
    MB_YESNO = 0x00000004
    MB_RETRYCANCEL = 0x00000005

    # Message Box Icons
    MB_ICONHAND = 0x00000010
    MB_ICONQUESTION = 0x00000020
    MB_ICONEXCLAMATION = 0x00000030
    MB_ICONASTERISK = 0x00000040

    # Heap Information Types
    HEAP_COMPATIBILITY_INFORMATION = 0
    HEAP_ENABLE_TERMINATION_ON_CORRUPTION = 1

    # Heap Information Values
    HEAP_STANDARD = 0
    HEAP_LOOKASIDE = 1
    HEAP_LOW_FRAGMENTATION = 2

    # Open Filename Constants
    OFN_READONLY = 0x00000001
    OFN_OVERWRITEPROMPT = 0x00000002
    OFN_HIDEREADONLY = 0x00000004
    OFN_NOCHANGEDIR = 0x00000008
    OFN_SHOWHELP = 0x00000010
    OFN_ENABLEHOOK = 0x00000020
    OFN_ENABLETEMPLATE = 0x00000040
    OFN_ENABLETEMPLATEHANDLE = 0x00000080
    OFN_NOVALIDATE = 0x00000100
    OFN_ALLOWMULTISELECT = 0x00000200
    OFN_EXTENSIONDIFFERENT = 0x00000400
    OFN_PATHMUSTEXIST = 0x00000800
    OFN_FILEMUSTEXIST = 0x00001000
    OFN_CREATEPROMPT = 0x00002000
    OFN_SHAREAWARE = 0x00004000
    OFN_NOREADONLYRETURN = 0x00008000
    OFN_NOTESTFILECREATE = 0x00010000
    OFN_NONETWORKBUTTON = 0x00020000
    OFN_NOLONGNAMES = 0x00040000
    OFN_EXPLORER = 0x00080000
    OFN_NODEREFERENCELINKS = 0x00100000
    OFN_LONGNAMES = 0x00200000
    OFN_ENABLEINCLUDENOTIFY = 0x00400000
    OFN_ENABLESIZING = 0x00800000
    OFN_DONTADDTORECENT = 0x02000000
    OFN_FORCESHOWHIDDEN = 0x10000000
    OFN_EX_NOPLACESBAR = 0x00000001

    # Format Message Settings
    FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
    FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
    FORMAT_MESSAGE_FROM_STRING = 0x00000400
    FORMAT_MESSAGE_FROM_HMODULE = 0x00000800
    FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
    FORMAT_MESSAGE_ARGUMENT_ARRAY = 0x00002000
    FORMAT_MESSAGE_MAX_WIDTH_MASK = 0x000000FF

    # Primary Language Ids
    LANG_NEUTRAL = 0x00

    # Sub Language Ids
    SUBLANG_DEFAULT = 0x01
    SUBLANG_SYS_DEFAULT = 0x02

    # Calculate a language id
    def self.make_lang_id(primary_language_id, sub_language_id)
      (sub_language_id << 10) | primary_language_id
    end

    # Creates a Message Box
    def self.message_box(message, title = 'Error', options = 0)
      Win32API.new('user32','MessageBox',['L', 'P', 'P', 'L'],'I').call(0, message, title, options)
    end

    # Gets the window handle for the foreground window or NULL
    def self.get_foreground_window
      Win32API.new('user32','GetForegroundWindow',[],'I').call()
    end

    # Gets the error code of the most recent error
    def self.get_last_error
      Win32API.new("Kernel32", "GetLastError", [], "I").call
    end

    # Formats a message
    def self.format_message(flags, source, message_id, language_id)
      buffer = ' ' * 1024
      api = Win32API.new('Kernel32', 'FormatMessage', [DWORD, LP, DWORD, DWORD, LP, DWORD, LP], DWORD)
      buffer_length = api.call(flags, source, message_id, language_id, buffer, buffer.length, NULL)
      if buffer_length == 0
        ''
      else
        buffer[0..(buffer_length - 1)]
      end
    end

    # Gets the error message from the last error
    def self.get_last_error_message
      last_error = Win32.get_last_error
      language_id = Win32.make_lang_id(LANG_NEUTRAL, SUBLANG_DEFAULT)
      Win32.format_message(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, last_error, language_id)
    end

    # Returns the computer name
    def self.computer_name
      name = ' ' * 128
      size = [name.length].pack('i')
      Win32API.new('kernel32','GetComputerName',['P','P'],'I').call(name, size)
      name.unpack('A*')[0]
    end

    # Returns current logged in Windows user name
    def self.user_name
      name = ' ' * 128
      size = [name.length].pack('i')
      Win32API.new('advapi32','GetUserName',['P','P'],'I').call(name, size)
      name.unpack('A*')[0]
    end

    # Get the Process's Heap Handle
    def self.get_process_heap
      Win32API.new('Kernel32', 'GetProcessHeap', [], 'i').call
    end

    # Set Heap Information
    def self.heap_set_information(heap_handle, heap_information_type, value)
      heap_info = [value].pack('i')
      api = Win32API.new('Kernel32', 'HeapSetInformation', ['i', 'i', 'P', 'i'], 'i')
      return_value = api.call(heap_handle, heap_information_type, heap_info, heap_info.length)
      raise "HeapSetInformation Error: #{get_last_error_message()}" if return_value == 0
    end

    # Get Heap Information
    def self.heap_query_information(heap_handle, heap_information_type)
      heap_info = ' ' * 8
      size      = ' ' * 8
      api = Win32API.new('Kernel32', 'HeapQueryInformation', ['i', 'i', 'P', 'i', 'P'], 'i')
      api.call(heap_handle, heap_information_type, heap_info, heap_info.length, size)
      heap_info.unpack("i")[0]
    end

    # Enable the Low Fragmentation Heap
    def self.enable_low_fragmentation_heap(heap_handle)
      heap_set_information(heap_handle,   HEAP_COMPATIBILITY_INFORMATION, HEAP_LOW_FRAGMENTATION)
      heap_info = heap_query_information(heap_handle, HEAP_COMPATIBILITY_INFORMATION)
      raise "Unable to enable Low Fragmentation Heap" if heap_info != HEAP_LOW_FRAGMENTATION
    end

  end # class Win32

end # module Cosmos
