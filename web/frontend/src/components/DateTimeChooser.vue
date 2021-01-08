<template>
  <div>
    <v-row>
      <v-col>
        <v-menu
          :close-on-content-click="true"
          transition="scale-transition"
          offset-y
          max-width="290px"
          min-width="290px"
        >
          <template v-slot:activator="{ on }">
            <!-- We set the :name attribute to be unique to avoid auto-completion -->
            <v-text-field
              :label="dateLabel"
              :name="'date' + Date.now()"
              :rules="dateRules"
              v-model="date"
              v-on="on"
              prepend-icon="mdi-calendar"
              data-test="dateChooser"
            ></v-text-field>
          </template>
          <v-date-picker
            v-model="date"
            @change="onChange"
            :show-current="false"
            no-title
          ></v-date-picker>
        </v-menu>
      </v-col>
      <v-col>
        <!-- We set the :name attribute to be unique to avoid auto-completion -->
        <v-text-field
          :label="timeLabel"
          :name="'time' + Date.now()"
          :rules="timeRules"
          v-model="time"
          @change="onChange"
          prepend-icon="mdi-clock"
          data-test="timeChooser"
        ></v-text-field>
      </v-col>
    </v-row>
  </div>
</template>

<script>
import { isValid, parse, format, getTime } from 'date-fns'

export default {
  props: {
    required: {
      type: Boolean,
      default: true,
    },
    initialDate: {
      type: Date,
      default: null,
    },
    initialTime: {
      type: Date,
      default: null,
    },
    dateLabel: {
      type: String,
      default: 'Date',
    },
    timeLabel: {
      type: String,
      default: 'Time',
    },
  },
  data() {
    return {
      date: null,
      time: null,
      rules: {
        required: (value) => !!value || 'Required',
        date: (value) => {
          if (!value) return true
          try {
            return (
              isValid(parse(value, 'yyyy-MM-dd', new Date())) ||
              'Invalid date (YYYY-MM-DD)'
            )
          } catch (e) {
            return 'Invalid date (YYYY-MM-DD)'
          }
        },
        time: (value) => {
          if (!value) return true
          try {
            return (
              isValid(parse(value, 'HH:mm:ss', new Date())) ||
              'Invalid time (HH:MM:SS)'
            )
          } catch (e) {
            return 'Invalid time (HH:MM:SS)'
          }
        },
      },
    }
  },
  computed: {
    dateRules() {
      let result = [this.rules.date]
      if (this.time || this.required) {
        result.push(this.rules.required)
      }
      return result
    },
    timeRules() {
      let result = [this.rules.time]
      if (this.date || this.required) {
        result.push(this.rules.required)
      }
      return result
    },
  },
  methods: {
    onChange() {
      if (!!this.date && !!this.time) {
        this.$emit('date-time', this.date + ' ' + this.time)
      } else {
        this.$emit('date-time', null)
      }
    },
  },
}
</script>

<style lang="scss" scoped></style>
