# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'irb/ruby-lex'
require 'stringio'

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

  # Monkey patch to fix performance issue caused by call to reverse
  def get_readed
    if idx = @readed.rindex("\n")
      @base_char_no = @readed.size - (idx + 1)
    else
      @base_char_no += @readed.size
    end

    readed = @readed.join("")
    @readed = []
    readed
  end

  # Monkey patch to fix performance issue caused by call to reverse
  def ungetc(c = nil)
    if @here_readed.empty?
      c2 = @readed.pop
    else
      c2 = @here_readed.pop
    end
    c = c2 unless c
    @rests.unshift c #c =
    @seek -= 1
    if c == "\n"
      @line_no -= 1
      if idx = @readed.rindex("\n")
        @char_no = idx + 1
      else
        @char_no = @base_char_no + @readed.size
      end
    else
      @char_no -= 1
    end
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
    comments_removed = text
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
    lex = RubyLex.new
    lex.exception_on_syntax_error = false
    lex_io = StringIO.new(text)
    lex.set_input(lex_io)

    while lexed = lex.lex
      line_no = lex.exp_line_no

      if contains_begin?(lexed)
        inside_begin = lex.indent - 1
      end

      if lex.indent == inside_begin
        inside_begin = nil
      end

      loop do # loop to allow restarting for nested conditions

        # Yield blank lines and lonely else lines before the actual line
        while (index = lexed.index("\n"))
          line = lexed[0..index]
          if line =~ BLANK_LINE_REGEX
            yield line, true, inside_begin, line_no
            line_no += 1
            lexed = lexed[(index + 1)..-1]
          elsif line =~ LONELY_ELSE_REGEX
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
        else
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
