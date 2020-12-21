import Widget from './Widget'
import 'sprintf-js'
export default {
  mixins: [Widget],
  // ValueWidget can either get it's value and limitsState directly through props
  // or it will register itself in the Vuex store and be updated asyncronously
  props: {
    value: {
      default: null,
    },
    limitsState: {
      type: String,
      default: null,
    },
    formatString: null,
  },
  data() {
    return {
      valueId: null,
      colorBlind: false,
      viewDetails: false,
      contextMenuShown: false,
      x: 0,
      y: 0,
      contextMenuOptions: [
        {
          title: 'Details',
          action: () => {
            this.contextMenuShown = false
            this.viewDetails = true
          },
        },
      ],
    }
  },
  computed: {
    _value: function () {
      let value = this.value
      if (value === null) {
        if (this.$store.state.tlmViewerValues[this.valueId]) {
          value = this.$store.state.tlmViewerValues[this.valueId][0]
        } else {
          value = null
        }
      }
      return this.formatValue(value)
    },
    valueClass: function () {
      return 'value shrink pa-1 ' + 'cosmos-' + this.limitsColor
    },
    limitsColor() {
      let limitsState = this.limitsState
      if (limitsState === null) {
        if (this.$store.state.tlmViewerValues[this.valueId]) {
          limitsState = this.$store.state.tlmViewerValues[this.valueId][1]
        } else {
          limitsState = null
        }
      }
      if (limitsState != null) {
        switch (limitsState) {
          case 'GREEN':
          case 'GREEN_HIGH':
          case 'GREEN_LOW':
            return 'green'
          case 'YELLOW':
          case 'YELLOW_HIGH':
          case 'YELLOW_LOW':
            return 'yellow'
          case 'RED':
          case 'RED_HIGH':
          case 'RED_LOW':
            return 'red'
          case 'BLUE':
            return 'blue'
          case 'STALE':
            return 'purple'
          default:
            return 'white'
        }
      }
    },
  },
  created() {
    // If they're not passing us the value and limitsState we have to register
    if (this.value === null || this.limitsState === null) {
      this.valueId =
        this.parameters[0] +
        '__' +
        this.parameters[1] +
        '__' +
        this.parameters[2] +
        '__' +
        this.getType()

      this.$store.commit('tlmViewerAddItem', this.valueId)
    }
  },
  destroyed() {
    this.$store.commit('tlmViewerDeleteItem', this.valueId)
  },
  methods: {
    getType() {
      var type = 'WITH_UNITS'
      if (this.parameters[3]) {
        type = this.parameters[3]
      }
      return type
    },
    formatValue(value) {
      if (Object.prototype.toString.call(value).slice(8, -1) === 'Array') {
        let result = '['
        for (let i = 0; i < value.length; i++) {
          if (
            Object.prototype.toString.call(value[i]).slice(8, -1) === 'String'
          ) {
            result += '"' + value[i] + '"'
          } else {
            result += value[i]
          }
          if (i != value.length - 1) {
            result += ', '
          }
        }
        result += ']'
        return result
      } else if (
        Object.prototype.toString.call(value).slice(8, -1) === 'Object'
      ) {
        return ''
      } else {
        if (this.formatString && value) {
          return sprintf(this.formatString, value)
        } else {
          return '' + value
        }
      }
    },
    showContextMenu(e) {
      e.preventDefault()
      this.contextMenuShown = false
      this.x = e.clientX
      this.y = e.clientY
      this.$nextTick(() => {
        this.contextMenuShown = true
      })
    },
  },
}
