<template>
  <div>
    <LimitsMonitor />
  </div>
</template>

<script>
// @ is an alias to /src
import LimitsMonitor from '@/tools/LimitsMonitor/LimitsMonitor'
export default {
  name: 'LimitsMonitorView',
  components: {
    LimitsMonitor,
  },
}
</script>
