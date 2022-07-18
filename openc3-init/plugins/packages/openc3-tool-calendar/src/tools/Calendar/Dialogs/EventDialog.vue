<!--
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
-->

<template>
  <div>
    <v-card width="400">
      <div v-if="type === 'activity'">
        <activity-event-form
          :activity-event="event"
          :utc="utc"
          @close="close"
        />
      </div>
      <div v-if="type === 'note'">
        <note-event-form :note-event="event" :utc="utc" @close="close" />
      </div>
      <div v-if="type === 'metadata'">
        <metadata-event-form
          :metadata-event="event"
          :utc="utc"
          @close="close"
        />
      </div>
    </v-card>
  </div>
</template>

<script>
import ActivityEventForm from '@/tools/Calendar/Forms/ActivityEventForm'
import MetadataEventForm from '@/tools/Calendar/Forms/MetadataEventForm'
import NoteEventForm from '@/tools/Calendar/Forms/NoteEventForm'

export default {
  components: {
    ActivityEventForm,
    MetadataEventForm,
    NoteEventForm,
  },
  props: {
    event: {
      type: Object,
      required: true,
    },
    utc: {
      type: Boolean,
      required: true,
    },
    value: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    type: function () {
      return this.event ? this.event.type : ''
    },
    show: {
      get() {
        return this.value
      },
      set(value) {
        this.$emit('input', value) // input is the default event when using v-model
      },
    },
  },
  methods: {
    close: function (event) {
      this.show = !this.show
      this.$emit('close')
    },
  },
}
</script>
