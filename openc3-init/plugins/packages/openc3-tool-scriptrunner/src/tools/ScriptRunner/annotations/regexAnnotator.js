/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/

export default class RegexAnnotator {
  #id
  #editor
  #pattern
  #text
  #type

  constructor(editor, { pattern, text, type }) {
    this.#id = `regexAnnotator-${Math.floor(Math.random() * 10000000)}`
    this.#editor = editor
    this.#pattern = pattern
    this.#text = text
    this.#type = type
  }

  // Re-annotate the entire document
  refresh = () => {
    const session = this.#editor.session
    this.#removeAllAnnotations(session)
    const event = {
      lines: session.doc.$lines,
      action: 'insert',
      start: { row: 0 },
      end: { row: session.doc.$lines.length },
    }
    this.annotate(event, session)
  }

  // Update annotations for the changed lines
  annotate = ($event, session) => {
    if ($event.lines.length > 1) {
      // They created or deleted a line (or multiple lines), so first need to shift all the existing annotations
      switch ($event.action) {
        case 'insert':
          this.#shiftAnnotations(
            session,
            $event.start.row,
            $event.lines.length - 1
          )
          break
        case 'remove':
          this.#shiftAnnotations(
            session,
            $event.start.row + 1,
            -$event.lines.length + 1
          )
          break
      }
    }
    for (let row = $event.start.row; row <= $event.end.row; row++) {
      let column = session.doc.$lines[row]?.match(this.#pattern)?.index
      if (column !== undefined) {
        column !== 0 && (column += 1) // Account for a leading space that might've been included in the match
        this.#addAnnotation(session, {
          row,
          column, // I don't think our editor theme shows the column for annotations, but others do
          text: this.#text,
          type: this.#type,
          openc3Id: this.#id,
        })
      } else if ($event.action === 'remove') {
        this.#deleteAnnotationsForRow(session, row)
      }
    }
  }

  #addAnnotation = (session, newAnnotation) => {
    this.#deleteAnnotationsForRow(session, newAnnotation.row) // Reset this row first for the new annotation
    session.setAnnotations([...session.getAnnotations(), newAnnotation])
  }

  #deleteAnnotationsForRow = (session, row) => {
    session.setAnnotations(
      session
        .getAnnotations()
        .filter(
          (annotation) =>
            annotation.openc3Id !== this.#id || annotation.row !== row
        )
    )
  }

  #shiftAnnotations = (session, row, count) => {
    session.setAnnotations(
      session.getAnnotations().map((annotation) => {
        if (annotation.row > row) {
          annotation.row += count
        }
        return annotation
      })
    )
  }

  #removeAllAnnotations = (session) => {
    session.setAnnotations(
      session
        .getAnnotations()
        .filter((annotation) => annotation.openc3Id !== this.#id)
    )
  }
}
