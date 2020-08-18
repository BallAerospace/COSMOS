<template>
  <div>
    <AppNav app />
    <LimitsEvents />
  </div>
</template>

<script>
import AppNav from '@/AppNav'
import { CosmosApi } from '@/services/cosmos-api'
import LimitsEvents from '@/components/LimitsEvents'

export default {
  components: {
    AppNav,
    LimitsEvents
  }
}
</script>

<style scoped>
.v-card {
  padding: 10px;
}
</style>
