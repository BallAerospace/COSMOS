import { CosmosApi } from '@/services/cosmos-api'

export default {
  props: {
    refreshInterval: {
      default: 1000
    }
  },
  data() {
    return {
      updater: null,
      api: null
    }
  },
  created() {
    this.api = new CosmosApi()
  },
  mounted() {
    this.changeUpdater()
  },
  beforeDestroy() {
    if (this.updater != null) {
      clearInterval(this.updater)
      this.updater = null
    }
  },
  watch: {
    // eslint-disable-next-line no-unused-vars
    refreshInterval: function(newVal, oldVal) {
      this.changeUpdater()
    }
  },
  methods: {
    changeUpdater() {
      if (this.updater != null) {
        clearInterval(this.updater)
        this.updater = null
      }
      this.updater = setInterval(() => {
        this.update()
      }, this.refreshInterval)
    }
  }
}
