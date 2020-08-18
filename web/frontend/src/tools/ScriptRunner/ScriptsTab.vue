<template>
  <v-card>
    <v-card-title>
      <v-btn color="primary" @click="getScripts">Refresh</v-btn>
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
        <v-btn block color="primary" @click="run(item.name)">Run</v-btn>
      </template>
    </v-data-table>
  </v-card>
</template>

<script>
import axios from 'axios'

export default {
  props: {
    tabId: Number,
    curTab: Number
  },
  data() {
    return {
      search: '',
      data: [],
      headers: [
        { text: 'Name', value: 'name' },
        {
          text: 'Actions',
          value: 'actions',
          sortable: false,
          filterable: false
        }
      ]
    }
  },
  created() {
    this.getScripts()
  },
  methods: {
    getScripts() {
      axios.get('http://localhost:3001/scripts').then(response => {
        this.data = []
        for (let item of response.data) {
          this.data.push({ name: item, actions: '' })
        }
      })
    },
    run(name) {
      axios
        .post('http://localhost:3001/scripts/' + name + '/run', {})
        .then(response => {
          this.$router.push({
            name: 'ScriptRunnerEditor',
            params: { id: response.data }
          })
        })
    }
  }
}
</script>

<style scoped></style>
