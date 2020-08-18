<template>
  <div class="home">
    <PacketViewer />
  </div>
</template>

<script>
// @ is an alias to /src
import PacketViewer from '@/tools/PacketViewer/PacketViewer'
export default {
  name: 'PacketViewerView',
  components: {
    PacketViewer
  }
}
</script>
