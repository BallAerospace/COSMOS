<template>
  <div>
    <app-nav />
    <v-card>
      <v-card-title>
        <v-btn color="primary" @click="getRunningScripts">Refresh</v-btn>
        <v-spacer></v-spacer>
        <v-text-field
          v-model="search"
          append-icon="mdi-magnify"
          label="Search"
          single-line
          hide-details
        ></v-text-field>
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="data"
        :search="search"
        calculate-widths
        disable-pagination
        hide-default-footer
        multi-sort
      >
        <template v-slot:item.actions="{ item }">
          <v-btn color="primary" @click="connect(item.id)">Connect</v-btn>
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script>
import axios from 'axios'
import AppNav from '@/AppNav'

export default {
  components: {
    AppNav,
  },
  props: {
    tabId: Number,
    curTab: Number,
  },
  data() {
    return {
      search: '',
      data: [],
      headers: [
        { text: 'Id', value: 'id' },
        { text: 'Name', value: 'name' },
        { text: 'Bucket', value: 'bucket' },
        { text: 'Start Time', value: 'start_time' },
        {
          text: 'Actions',
          value: 'actions',
          sortable: false,
          filterable: false,
        },
      ],
    }
  },
  created() {
    this.getRunningScripts()
  },
  methods: {
    getRunningScripts() {
      axios.get('http://localhost:3001/running-script').then((response) => {
        this.data = response.data
      })
    },
    connect(id) {
      this.$router.push({ name: 'ScriptRunner', params: { id: id } })
    },
  },
}
</script>

<style scoped></style>
