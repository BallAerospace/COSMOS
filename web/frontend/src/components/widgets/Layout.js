import Widget from './Widget'
export default {
  mixins: [Widget],
  props: {
    widgets: {
      type: Array,
      default: () => [],
    },
  },
}
