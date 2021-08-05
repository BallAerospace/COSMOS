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

require 'irb/ruby-lex'
require 'stringio'

if RUBY_VERSION >= "2.7"

  # Clear the $VERBOSE global since we're overriding methods
  old_verbose = $VERBOSE; $VERBOSE = nil
  class RubyLex
    attr_accessor :indent
    attr_accessor :line_no
    attr_accessor :exp_line_no
    attr_accessor :tokens
    attr_accessor :code_block_open
    attr_accessor :ltype
    attr_accessor :line
    attr_accessor :continue

    def reinitialize
      @line_no = 1
      @prompt = nil
      initialize_input()
    end
  end
  $VERBOSE = old_verbose

  class RubyLexUtils
    # Regular expression to detect blank lines
    BLANK_LINE_REGEX  = /^\s*$/
    # Regular expression to detect lines containing only 'else'
    LONELY_ELSE_REGEX = /^\s*else\s*$/

    KEY_KEYWORDS = [
      'class'.freeze,
      'module'.freeze,
      'def'.freeze,
      'undef'.freeze,
      'begin'.freeze,
      'rescue'.freeze,
      'ensure'.freeze,
      'end'.freeze,
      'if'.freeze,
      'unless'.freeze,
      'then'.freeze,
      'elsif'.freeze,
      'else'.freeze,
      'case'.freeze,
      'when'.freeze,
      'while'.freeze,
      'until'.freeze,
      'for'.freeze,
      'break'.freeze,
      'next'.freeze,
      'redo'.freeze,
      'retry'.freeze,
      'in'.freeze,
      'do'.freeze,
      'return'.freeze,
      'alias'.freeze
    ]

    # Create a new RubyLex and StringIO to hold the text to operate on
    def initialize
      @lex    = RubyLex.new
      @lex_io = StringIO.new('')
    end

    if RUBY_VERSION >= "3.0"
      def ripper_lex_without_warning(code)
        RubyLex.ripper_lex_without_warning(code)
      end
    else
      def ripper_lex_without_warning(code)
        @lex.ripper_lex_without_warning(code)
      end
    end

    # @param text [String]
    # @return [Boolean] Whether the text contains the 'begin' keyword
    def contains_begin?(text)
      @lex.reinitialize
      @lex_io.string = text
      @lex.set_input(@lex_io)
      tokens = ripper_lex_without_warning(text)
      tokens.each do |token|
        if token[1] == :on_kw and token[2] == 'begin'
          return true
        end
      end
      return false
    end

    # @param text [String]
    # @return [Boolean] Whether the text contains a Ruby keyword
    def contains_keyword?(text)
      @lex.reinitialize
      @lex_io.string = text
      @lex.set_input(@lex_io)
      tokens = ripper_lex_without_warning(text)
      tokens.each do |token|
        if token[1] == :on_kw
          if KEY_KEYWORDS.include?(token[2])
            return true
          end
        elsif token[1] == :on_lbrace and !token[3].allbits?(Ripper::EXPR_BEG | Ripper::EXPR_LABEL)
          return true
        end
      end
      return false
    end

    # @param text [String]
    # @return [Boolean] Whether the text contains a keyword which starts a block.
    #   i.e. 'do', '{', or 'begin'
    def contains_block_beginning?(text)
      @lex.reinitialize
      @lex_io.string = text
      @lex.set_input(@lex_io)
      tokens = ripper_lex_without_warning(text)
      tokens.each do |token|
        if token[1] == :on_kw
          if token[2] == 'begin' || token[2] == 'do'
            return true
          end
        elsif token[1] == :on_lbrace
          return true
        end
      end
      return false
    end

    # @param text [String]
    # @param progress_dialog [Cosmos::ProgressDialog] If this is set, the overall
    #   progress will be set as the processing progresses
    # @return [String] The text with all comments removed
    def remove_comments(text, progress_dialog = nil)
      @lex.reinitialize
      @lex_io.string = text
      @lex.set_input(@lex_io)
      comments_removed = ""
      token_count = 0
      progress = 0.0
      tokens = ripper_lex_without_warning(text)
      tokens.each do |token|
        token_count += 1
        if token[1] != :on_comment
          comments_removed << token[2]
        else
          newline_count = token[2].count("\n")
          comments_removed << ("\n" * newline_count)
        end
        if progress_dialog and token_count % 10000 == 0
          progress += 0.01
          progress = 0.0 if progress >= 0.99
          progress_dialog.set_overall_progress(progress)
        end
      end

      return comments_removed
    end

    # Yields each lexed segment and if the segment is instrumentable
    #
    # @param text [String]
    # @yieldparam line [String] The entire line
    # @yieldparam instrumentable [Boolean] Whether the line is instrumentable
    # @yieldparam inside_begin [Integer] The level of indentation
    # @yieldparam line_no [Integer] The current line number
    def each_lexed_segment(text)
      inside_begin = false
      indent = 0
      lex = RubyLex.new
      lex_io = StringIO.new(text)
      lex.set_input(lex_io)
      lex.line = ''
      while lexed = lex.lex
        lex.line_no += lexed.count("\n")
        lex.line.concat lexed
        next if lex.ltype or lex.continue

        # Detect the beginning and end of begin blocks so we can not catch exceptions there
        if indent == 0 and contains_begin?(lex.line)
          inside_begin = true
          indent = lex.indent
        else
          indent += lex.indent if indent > 0
        end

        if inside_begin and indent <= 0
          indent = 0
          inside_begin = false
        end

        loop do # loop to allow restarting for nested conditions
          # Yield blank lines and lonely else lines before the actual line
          while (index = lex.line.index("\n"))
            line = lex.line[0..index]
            if BLANK_LINE_REGEX.match?(line)
              yield line, true, inside_begin, lex.exp_line_no
              lex.exp_line_no += 1
              lex.line = lex.line[(index + 1)..-1]
            elsif LONELY_ELSE_REGEX.match?(line)
              yield line, false, inside_begin, lex.exp_line_no
              lex.exp_line_no += 1
              lex.line = lex.line[(index + 1)..-1]
            else
              break
            end
          end

          if contains_keyword?(lex.line)
            if contains_block_beginning?(lex.line)
              section = ''
              lex.line.each_line do |lexed_part|
                section << lexed_part
                if contains_block_beginning?(section)
                  yield section, false, inside_begin, lex.exp_line_no
                  break
                end
                lex.exp_line_no += 1
              end
              lex.exp_line_no += 1
              remainder = lex.line[(section.length)..-1]
              lex.line = remainder
              next unless remainder.empty?
            else
              yield lex.line, false, inside_begin, lex.exp_line_no
            end
          elsif !lex.line.empty?
            num_left_brackets  = lex.line.count('{')
            num_right_brackets = lex.line.count('}')
            if num_left_brackets != num_right_brackets
              # Don't instrument lines with unequal numbers of { and } brackets
              yield lex.line, false, inside_begin, lex.exp_line_no
            else
              yield lex.line, true, inside_begin, lex.exp_line_no
            end
          end
          lex.line = ''
          lex.exp_line_no = lex.line_no
          lex.indent = 0
          break
        end # loop do
      end # while lexed
    end # def each_lexed_segment
  end

else

  # Clear the $VERBOSE global since we're overriding methods
  old_verbose = $VERBOSE; $VERBOSE = nil
  class RubyLex
    if self.method_defined?(:indent)
      attr_writer :indent
    else
      attr_accessor :indent
    end
    # @return [Integer] The expression line number. This can differ from the
    #   actual line number due to white space and Ruby control keywords.
    attr_accessor :exp_line_no

    # Resets the RubyLex in preparation of parsing a line
    def reinitialize
      @seek                      = 0
      @exp_line_no               = 1
      @line_no                   = 1
      @base_char_no              = 0
      @char_no                   = 0
      @rests.clear
      @readed.clear
      @here_readed.clear
      @indent                    = 0
      @indent_stack.clear
      @lex_state                 = EXPR_BEG
      @space_seen                = false
      @here_header               = false
      @continue                  = false
      @line                      = ''
      @skip_space                = false
      @readed_auto_clean_up      = false
      @exception_on_syntax_error = true
      @prompt                    = nil
    end

    # Monkey patch to keep this from looping forever if the string never is closed with a right brace
    def identify_string_dvar
      getc

      reserve_continue = @continue
      reserve_ltype = @ltype
      reserve_indent = @indent
      reserve_indent_stack = @indent_stack
      reserve_state = @lex_state
      reserve_quoted = @quoted

      @ltype = nil
      @quoted = nil
      @indent = 0
      @indent_stack = []
      @lex_state = EXPR_BEG

      loop do
        @continue = false
        prompt
        tk = token
        break if tk.nil? # This is the patch
        if @ltype or @continue or @indent >= 0
          next
        end
        break if tk.kind_of?(TkRBRACE)
      end
    ensure
      @continue = reserve_continue
      @ltype = reserve_ltype
      @indent = reserve_indent
      @indent_stack = reserve_indent_stack
      @lex_state = reserve_state
      @quoted = reserve_quoted
    end

  end
  $VERBOSE = old_verbose

  class RubyLexUtils
    # Regular expression to detect blank lines
    BLANK_LINE_REGEX  = /^\s*$/
    # Regular expression to detect lines containing only 'else'
    LONELY_ELSE_REGEX = /^\s*else\s*$/

    # Ruby keywords
    KEYWORD_TOKENS = [RubyToken::TkCLASS,
                      RubyToken::TkMODULE,
                      RubyToken::TkDEF,
                      RubyToken::TkUNDEF,
                      RubyToken::TkBEGIN,
                      RubyToken::TkRESCUE,
                      RubyToken::TkENSURE,
                      RubyToken::TkEND,
                      RubyToken::TkIF,
                      RubyToken::TkUNLESS,
                      RubyToken::TkTHEN,
                      RubyToken::TkELSIF,
                      RubyToken::TkELSE,
                      RubyToken::TkCASE,
                      RubyToken::TkWHEN,
                      RubyToken::TkWHILE,
                      RubyToken::TkUNTIL,
                      RubyToken::TkFOR,
                      RubyToken::TkBREAK,
                      RubyToken::TkNEXT,
                      RubyToken::TkREDO,
                      RubyToken::TkRETRY,
                      RubyToken::TkIN,
                      RubyToken::TkDO,
                      RubyToken::TkRETURN,
                      RubyToken::TkIF_MOD,
                      RubyToken::TkUNLESS_MOD,
                      RubyToken::TkWHILE_MOD,
                      RubyToken::TkUNTIL_MOD,
                      RubyToken::TkALIAS,
                      RubyToken::TklBEGIN,
                      RubyToken::TklEND,
                      RubyToken::TkfLBRACE]

    # Ruby keywords which define the beginning of a block: do, {, begin
    BLOCK_BEGINNING_TOKENS = [RubyToken::TkDO,
                              RubyToken::TkfLBRACE,
                              RubyToken::TkBEGIN]

    # Create a new RubyLex and StringIO to hold the text to operate on
    def initialize
      @lex    = RubyLex.new
      @lex_io = StringIO.new('')
    end

    # @param text [String]
    # @return [Boolean] Whether the text contains the 'begin' keyword
    def contains_begin?(text)
      @lex.reinitialize
      @lex.exception_on_syntax_error = false
      @lex_io.string = text
      @lex.set_input(@lex_io)
      while token = @lex.token
        if token.class == RubyToken::TkBEGIN
          return true
        end
      end
      return false
    end

    # @param text [String]
    # @return [Boolean] Whether the text contains a Ruby keyword
    def contains_keyword?(text)
      @lex.reinitialize
      @lex.exception_on_syntax_error = false
      @lex_io.string = text
      @lex.set_input(@lex_io)
      while token = @lex.token
        if KEYWORD_TOKENS.include?(token.class)
          return true
        end
      end
      return false
    end

    # @param text [String]
    # @return [Boolean] Whether the text contains a keyword which starts a block.
    #   i.e. 'do', '{', or 'begin'
    def contains_block_beginning?(text)
      @lex.reinitialize
      @lex.exception_on_syntax_error = false
      @lex_io.string = text
      @lex.set_input(@lex_io)
      while token = @lex.token
        if BLOCK_BEGINNING_TOKENS.include?(token.class)
          return true
        end
      end
      return false
    end

    # @param text [String]
    # @param progress_dialog [Cosmos::ProgressDialog] If this is set, the overall
    #   progress will be set as the processing progresses
    # @return [String] The text with all comments removed
    def remove_comments(text, progress_dialog = nil)
      comments_removed = text.clone
      @lex.reinitialize
      @lex.exception_on_syntax_error = false
      @lex_io.string = text
      @lex.set_input(@lex_io)
      need_remove = nil
      delete_ranges = []
      token_count = 0
      progress = 0.0
      while token = @lex.token
        token_count += 1
        if need_remove
          delete_ranges << (need_remove..(token.seek - 1))
          need_remove = nil
        end
        if token.class == RubyToken::TkCOMMENT
          need_remove = token.seek
        end
        if progress_dialog and token_count % 10000 == 0
          progress += 0.01
          progress = 0.0 if progress >= 0.99
          progress_dialog.set_overall_progress(progress)
        end
      end

      if need_remove
        delete_ranges << (need_remove..(text.length - 1))
        need_remove = nil
      end

      delete_count = 0
      delete_ranges.reverse_each do |range|
        delete_count += 1
        comments_removed[range] = ''
        if progress_dialog and delete_count % 10000 == 0
          progress += 0.01
          progress = 0.0 if progress >= 0.99
          progress_dialog.set_overall_progress(progress)
        end
      end

      return comments_removed
    end

    # Yields each lexed segment and if the segment is instrumentable
    #
    # @param text [String]
    # @yieldparam line [String] The entire line
    # @yieldparam instrumentable [Boolean] Whether the line is instrumentable
    # @yieldparam inside_begin [Integer] The level of indentation
    # @yieldparam line_no [Integer] The current line number
    def each_lexed_segment(text)
      inside_begin = false
      inside_indent = nil
      lex = RubyLex.new
      lex.exception_on_syntax_error = false
      lex_io = StringIO.new(text)
      lex.set_input(lex_io)

      while lexed = lex.lex
        line_no = lex.exp_line_no

        if inside_indent.nil? and contains_begin?(lexed)
          inside_indent = lex.indent - 1
          inside_begin = true
        end

        if lex.indent == inside_indent
          inside_indent = nil
          inside_begin = false
        end

        loop do # loop to allow restarting for nested conditions
          # Yield blank lines and lonely else lines before the actual line
          while (index = lexed.index("\n"))
            line = lexed[0..index]
            if BLANK_LINE_REGEX.match?(line)
              yield line, true, inside_begin, line_no
              line_no += 1
              lexed = lexed[(index + 1)..-1]
            elsif LONELY_ELSE_REGEX.match?(line)
              yield line, false, inside_begin, line_no
              line_no += 1
              lexed = lexed[(index + 1)..-1]
            else
              break
            end
          end

          if contains_keyword?(lexed)
            if contains_block_beginning?(lexed)
              section = ''
              lexed.each_line do |lexed_part|
                section << lexed_part
                if contains_block_beginning?(section)
                  yield section, false, inside_begin, line_no
                  break
                end
                line_no += 1
              end
              line_no += 1
              remainder = lexed[(section.length)..-1]
              lexed = remainder
              next unless remainder.empty?
            else
              yield lexed, false, inside_begin, line_no
            end
          elsif !lexed.empty?
            num_left_brackets  = lexed.count('{')
            num_right_brackets = lexed.count('}')
            if num_left_brackets != num_right_brackets
              # Don't instrument lines with unequal numbers of { and } brackets
              yield lexed, false, inside_begin, line_no
            else
              yield lexed, true, inside_begin, line_no
            end
          end
          lex.exp_line_no = lex.line_no
          break
        end # loop do
      end # while lexed
    end # def each_lexed_segment
  end

end  # RUBY_VERSION < "2.7"
